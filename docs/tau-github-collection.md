# Exact-value GitHub list collection

The bot's `tau-github-collect ENDPOINT NEW_CAPTURE.http` helper uses the existing
broker's `gh api --paginate --include ENDPOINT` form. Run inside the configured
bot sandbox from `/home/tau-fedimint/fedimint`, where `gh` resolves to the managed
interception shim. It does not load credentials itself, change broker permissions,
or send writes. It supports the six exact list endpoints used by the weekly
summary skill; singleton PR details remain a separate ordinary JSON-object read.

Create an owner-private directory with `mktemp -d`, then provide a new filename
inside it. The helper refuses to overwrite any existing file, creates the capture
with mode 0600, and retains it only after complete successful collection and
validation. Its stdout is a small JSON summary containing page/item counts, byte
count, filename, and successful command exit. These counts precede report-level
deduplication. Read the saved response bodies for evidence, not the stdout summary
or a tool's truncated rendering. Remove the private evidence when no longer needed.

## Why include response headers

Pinned gh combines unframed paginated JSON arrays on one physical output line.
An inventory can exceed the broker's existing 8 MiB line bound even if each page
is small. `--include` preserves each raw JSON body and adds response metadata and
page separators. This keeps values exact without removing fields or dropping
items. Do not use `--jq`, `--template`, `--slurp`, or `--silent` as substitutes:
the pinned gh jq path can round integers above 2^53. The helper never
decode/re-encodes the capture; its validation uses exact integers and decimals.

This implements gh-isolate's reviewed `docs/inventory-output.md` contract,
published in docs/tests-only revision
`eb6d18572426c7b55e7cc8d0c6805f9abefe2802`; the bot runtime broker remains
`87fb282f493bcf32b0ffc28b5738fefda9188618`. No broker runtime update is needed
for this existing output mode.

## Validation and limits

The helper waits for the actual command to exit zero, with no pipeline masking,
and captures all stdout bytes before interpreting them. It drains stderr without
publishing it or partially collected evidence. A deadline, I/O error, nonzero
exit, or output limit deletes the incomplete capture and fails explicitly.
Limits are 600 seconds, 256 MiB stdout, and 1 MiB stderr per invocation.

Each response requires `HTTP/1.1 200 OK` or `HTTP/2.0 200 OK`, CRLF-terminated
well-formed headers and an empty header terminator, exactly one JSON Content-Type,
and one physical JSON-array-of-objects body line. The status line ends in LF.
Each physical line remains bounded at 8 MiB, including its newline when present;
headers additionally have a 64 KiB / 256-line bound per response. Empty arrays
and an unterminated final body line are valid. Only empty inter-response lines
may be skipped. Multiline/pretty-printed bodies, non-array/error bodies,
duplicate JSON keys, non-JSON constants, malformed or missing pages, and
duplicate required headers fail closed.

Link clauses must have GitHub's `<URL>; rel="REL"` form, separated by comma-space,
with known first/prev/next/last relations and no duplicates. The first page must
have no prev; every later page, including the last, must have prev. Next requires
another complete response, and a terminal page requires end of stream. URLs are
metadata only: the helper never follows them or changes request authority.
Content-Length is not used; it can be absent or describe compressed content.

The broker drops whole physical lines containing its exact credential bytes.
The strict single-line body/framing contract rejects a missing body or required
metadata instead of accepting a silently redacted inventory. This is not a
cryptographic integrity proof or protection against post-capture file changes.
Loss of unrelated optional headers need not fail validation. An individual
page above 8 MiB still fails safely. Unknown server formats require separately
reviewed changes, not looser parsing or higher limits.

Pagination is not an atomic repository snapshot and does not prove every
real-world event is visible. Report deleted/inaccessible activity and unavailable
edit/push history separately. Do not publish a complete report after a collection
gap unless the user explicitly requests a partial report.
