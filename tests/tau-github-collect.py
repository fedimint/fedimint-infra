"""Offline collector tests: no credentials, GitHub requests, or reports."""

from decimal import Decimal
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("collector", sys.argv.pop(1))
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


def page(body=b"[]", link=None, status=b"HTTP/2.0 200 OK\n"):
    result = status + b"Content-Type: application/json; charset=utf-8\r\n"
    if link is not None:
        result += b"Link: " + link + b"\r\n"
    return result + b"\r\n" + body


NEXT = b'<https://api.github.com/repositories/1/issues?page=2>; rel="next"'
PREV = b'<https://api.github.com/repositories/1/issues?page=1>; rel="prev"'
ENDPOINT = "repos/fedimint/fedimint/issues?state=all&per_page=100"


class Validation(unittest.TestCase):
    def check(self, raw, pages=1, items=0):
        self.assertEqual(
            collector.validate(io.BytesIO(raw)), {"pages": pages, "items": items},
        )

    def bad(self, raw):
        with self.assertRaises(collector.Incomplete):
            collector.validate(io.BytesIO(raw))

    def test_empty_and_statuses(self):
        self.check(page())
        self.check(page(status=b"HTTP/1.1 200 OK\n") + b"\n")
        self.bad(b"")
        self.bad(page(status=b"HTTP/2.0 500 Error\n"))

    def test_multipage_and_exact_values(self):
        body = b'[{"id":9007199254740993,"decimal":0.123456789012345678901,"x":1e-200,"body":"first\\nsecond"}]'
        raw = page(body, NEXT) + b"\n\n" + page(link=PREV)
        self.check(raw, pages=2, items=1)
        value = json.loads(body, parse_float=Decimal)[0]
        self.assertEqual(value["id"], 9007199254740993)
        self.assertEqual(value["decimal"], Decimal("0.123456789012345678901"))
        self.assertEqual(value["x"], Decimal("1e-200"))

    def test_missing_redacted_and_truncated_pages(self):
        self.bad(page(link=NEXT))
        self.bad(page(link=NEXT) + b"\n" + page(link=PREV)[:-1])
        self.bad(page(link=NEXT) + b"\n" + page())
        self.bad(page() + b"\n" + page(link=PREV))
        self.bad(page(body=b"", link=NEXT) + b"\n" + page(link=PREV))
        self.bad(page().replace(b"Content-Type: application/json; charset=utf-8\r\n", b""))

    def test_bad_bodies(self):
        for body in (b"{}", b"[1]", b"[\n{}]", b"[{}]oops", b"[NaN]", b'[{"x":1,"x":2}]'):
            self.bad(page(body))

    def test_headers_and_links(self):
        self.bad(page().replace(b"\r\n\r\n", b"\r\nBad\r\n\r\n"))
        self.bad(page().replace(b"\r\n\r\n", b"\r\nContent-Type: application/json\r\n\r\n"))
        self.bad(page(link=PREV))
        for link in (b"garbage", NEXT + b", " + NEXT, b'<https://a>; rel="unknown"'):
            self.bad(page(link=link))
        self.bad(page().replace(b"application/json", b"text/plain"))
        self.bad(page().replace(b"\r\n", b"\n"))
        self.bad(page().replace(b"\r\n\r\n", b"\r\nX: \x00\r\n\r\n"))

    def test_aggregate_large_and_page_limit(self):
        body = b'[{"body":"' + b"x" * (3 * 1024 * 1024) + b'"}]'
        raw = page(body, NEXT) + b"\n" + page(body, PREV + b", " + NEXT) + b"\n" + page(body, PREV)
        self.assertGreater(len(raw), collector.MAX_LINE)
        self.check(raw, pages=3, items=3)
        self.bad(page(b'[{"body":"' + b"x" * collector.MAX_LINE + b'"}]'))

    def test_metadata_limits(self):
        self.bad(b"HTTP/2.0 200 OK\n" + b"X: x\r\n" * 256 + b"\r\n[]")
        self.bad(b"HTTP/2.0 200 OK\nX: " + b"x" * 65536 + b"\r\n\r\n[]")


class Capture(unittest.TestCase):
    def run_child(self, script, **kwargs):
        result = io.BytesIO()
        size = collector.capture([sys.executable, "-c", script], result, **kwargs)
        self.assertEqual(size, len(result.getvalue()))
        return result.getvalue()

    def test_stdout_stderr_and_exit(self):
        self.assertEqual(self.run_child('import sys; sys.stdout.buffer.write(b"exact"); sys.stderr.write("hidden")'), b"exact")
        with self.assertRaisesRegex(collector.Incomplete, "exited 7"):
            self.run_child('import sys; print("partial"); sys.exit(7)')

    def test_bounds_and_deadline(self):
        for stream in ("stdout", "stderr"):
            with self.assertRaises(collector.Incomplete):
                self.run_child(
                    f'import sys; sys.{stream}.write("x"*100)',
                    max_capture=10, max_stderr=10,
                )
        with self.assertRaisesRegex(collector.Incomplete, "deadline"):
            self.run_child("import time; time.sleep(5)", deadline=0.05)

    def test_retained_bytes_permissions_and_cleanup(self):
        raw = page(b'[{"id":9007199254740993,"n":1.2300e-100}]')
        def fake_capture(command, output):
            self.assertEqual(command, ["gh", "api", "--paginate", "--include", ENDPOINT])
            output.write(raw)
            return len(raw)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "evidence.http"
            with patch.object(collector, "capture", fake_capture):
                result = collector.collect(ENDPOINT, path)
                self.assertEqual(result["items"], 1)
                self.assertEqual(path.read_bytes(), raw)
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                with self.assertRaises(FileExistsError):
                    collector.collect(ENDPOINT, path)
            path.unlink()
            with patch.object(collector, "capture", side_effect=collector.Incomplete("nonzero")):
                with self.assertRaises(collector.Incomplete):
                    collector.collect(ENDPOINT, path)
                self.assertFalse(path.exists())
            def broken(command, output):
                output.write(b"partial")
                return 7
            with patch.object(collector, "capture", broken):
                with self.assertRaises(collector.Incomplete):
                    collector.collect(ENDPOINT, path)
                self.assertFalse(path.exists())

    def test_endpoint_contract(self):
        for endpoint in (
            ENDPOINT, "repos/O/R/issues?per_page=100&state=all",
            "repos/O/R/issues/1/timeline?per_page=100",
            "repos/O/R/issues/1/comments?per_page=100",
            "repos/O/R/pulls/1/reviews?per_page=100",
            "repos/O/R/pulls/1/comments?per_page=100",
            "repos/O/R/pulls/1/commits?per_page=100",
        ):
            self.assertIsNotNone(collector.ENDPOINT.fullmatch(endpoint))
        for endpoint in ("repos/O/R/issues", "repos/O/R/issues/01/comments?per_page=100", ENDPOINT + "&page=1"):
            self.assertIsNone(collector.ENDPOINT.fullmatch(endpoint))


if __name__ == "__main__":
    unittest.main()
