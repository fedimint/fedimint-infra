"""Capture and validate exact-value, paginated GitHub list evidence."""

import argparse
from decimal import Decimal, InvalidOperation
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import time


MAX_LINE = 8 * 1024 * 1024
MAX_CAPTURE = 256 * 1024 * 1024
MAX_STDERR = 1024 * 1024
DEADLINE = 600
ENDPOINT = re.compile(
    r"repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/"
    r"(?:issues\?(?:state=all&per_page=100|per_page=100&state=all)"
    r"|issues/[1-9][0-9]*/(?:timeline|comments)\?per_page=100"
    r"|pulls/[1-9][0-9]*/(?:reviews|comments|commits)\?per_page=100)"
)
LINK = re.compile(r'<[^<>\s]+>; rel="(first|prev|next|last)"')
HEADER = re.compile(rb"([!#$%&'*+.^_`|~0-9A-Za-z-]+):[ \t]*([^\x00-\x08\x0a-\x1f\x7f]*)\r\n")


class Incomplete(ValueError):
    pass


def reject_constant(_):
    raise Incomplete("non-JSON numeric constant")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise Incomplete("duplicate JSON object key")
        result[key] = value
    return result


def validate(stream):
    """Validate the complete framing; never rewrite or project the raw evidence."""
    pages = items = 0

    def line():
        value = stream.readline(MAX_LINE + 1)
        if len(value) > MAX_LINE:
            raise Incomplete("page or metadata line exceeds 8 MiB")
        return value

    status = line()
    while True:
        if status not in (b"HTTP/1.1 200 OK\n", b"HTTP/2.0 200 OK\n"):
            raise Incomplete("missing or unexpected HTTP 200 status")
        headers = {}
        header_bytes = 0
        for _ in range(256):
            raw = line()
            header_bytes += len(raw)
            if header_bytes > 64 * 1024:
                raise Incomplete("response headers exceed 64 KiB")
            if raw == b"\r\n":
                break
            match = HEADER.fullmatch(raw)
            if not match:
                raise Incomplete("malformed or missing response header")
            name, value = match.groups()
            name = name.lower()
            if name in (b"content-type", b"link"):
                if name in headers:
                    raise Incomplete("duplicate required response header")
                headers[name] = value
        else:
            raise Incomplete("too many response headers")
        content_type = headers.get(b"content-type", b"").split(b";", 1)[0].strip().lower()
        if content_type != b"application/json":
            raise Incomplete("missing JSON Content-Type")
        relations = set()
        if b"link" in headers:
            try:
                clauses = headers[b"link"].decode("ascii").split(", ")
            except UnicodeDecodeError as error:
                raise Incomplete("non-ASCII Link metadata") from error
            for clause in clauses:
                match = LINK.fullmatch(clause)
                if not match or match[1] in relations:
                    raise Incomplete("malformed or repeated Link relation")
                relations.add(match[1])
        if ("prev" in relations) != (pages > 0):
            raise Incomplete("missing or unexpected previous-page metadata")
        raw = line()
        try:
            # Integers remain Python integers; decimals never pass through float.
            body = json.loads(
                raw.decode("utf-8"), parse_float=Decimal, parse_constant=reject_constant,
                object_pairs_hook=unique_object,
            )
        except (ValueError, RecursionError, InvalidOperation) as error:
            raise Incomplete("missing, malformed, redacted, or multiline page body") from error
        if not isinstance(body, list) or not all(isinstance(item, dict) for item in body):
            raise Incomplete("page body must be an array of objects")
        pages += 1
        items += len(body)
        del body
        status = line()
        while status in (b"\n", b"\r\n"):
            status = line()
        if "next" not in relations:
            if status:
                raise Incomplete("unexpected response after terminal page")
            return {"pages": pages, "items": items}
        if not status:
            raise Incomplete("missing next response")


def capture(command, output, *, max_capture=MAX_CAPTURE, max_stderr=MAX_STDERR, deadline=DEADLINE):
    """Drain both streams with finite resources; preserve the actual command exit."""
    process = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,
    )
    expires = time.monotonic() + deadline
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ, "stdout")
            selector.register(process.stderr, selectors.EVENT_READ, "stderr")
            sizes = {"stdout": 0, "stderr": 0}
            while selector.get_map():
                remaining = expires - time.monotonic()
                if remaining <= 0:
                    raise Incomplete("collection deadline exceeded")
                for key, _ in selector.select(remaining):
                    chunk = os.read(key.fd, 64 * 1024)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    name = key.data
                    sizes[name] += len(chunk)
                    limit = max_capture if name == "stdout" else max_stderr
                    if sizes[name] > limit:
                        raise Incomplete(f"{name} capture resource limit exceeded")
                    if name == "stdout":
                        output.write(chunk)
                    # Never publish possibly sensitive stderr or a partial body.
            remaining = expires - time.monotonic()
            if remaining <= 0:
                raise Incomplete("collection deadline exceeded")
            result = process.wait(timeout=remaining)
            if result != 0:
                raise Incomplete(f"GitHub collection exited {result}")
            return sizes["stdout"]
    except BaseException:
        # Also stop descendants retaining inherited pipes on timeout/failure.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        raise
    finally:
        process.stdout.close()
        process.stderr.close()


def collect(endpoint, destination):
    if not ENDPOINT.fullmatch(endpoint):
        raise Incomplete("unsupported collection endpoint")
    # Exclusive creation prevents clobbering another capture or following a symlink.
    fd = os.open(destination, os.O_CREAT | os.O_EXCL | os.O_RDWR, 0o600)
    try:
        with os.fdopen(fd, "w+b") as output:
            size = capture(["gh", "api", "--paginate", "--include", endpoint], output)
            output.flush()
            output.seek(0)
            summary = validate(output)
            os.fsync(output.fileno())
        return {**summary, "bytes": size, "capture": str(destination), "exit": 0}
    except BaseException:
        Path(destination).unlink()
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("endpoint", help="one exact supported repository list endpoint")
    parser.add_argument("destination", help="new private raw capture filename (must not exist)")
    args = parser.parse_args()
    try:
        summary = collect(args.endpoint, args.destination)
    except (OSError, Incomplete, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"Incomplete evidence: {error}\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
