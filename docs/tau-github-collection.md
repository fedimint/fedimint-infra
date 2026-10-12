# Exact-value GitHub list collection

The bot's `tau-github-collect ENDPOINT NEW_CAPTURE.http` helper uses the existing
broker's `gh api --paginate --include ENDPOINT` form. Run inside the configured
bot sandbox from `/home/tau-fedimint/fedimint`, where `gh` resolves to the managed
interception shim. It does not load credentials itself, change broker permissions,
or send writes. It supports the six exact list endpoints; singleton PR details
remain a separate ordinary JSON-object read. The inventory endpoint remains
compatible for other callers, but **weekly reports must not use it**.

## Weekly scope and budgets

The installed weekly skill now authorizes bounded recent-updated reporting,
not whole-history completeness. Use its two `gh issue/pr list --state all`
searches with `updated:>=START`, no upper updated cutoff, and a 150-result limit
each. These named commands are supported by the pinned broker. A REST `since`
query is not supported; do not replace the command with an unapproved shape.
Reaching a discovery cap is a disclosed possible omission, not a reason to
split searches or enumerate historical items. Fetch only evidence needed for
claims; do not mechanically collect six sources per PR.

Use one network reader, at most 300 candidates, a 1,000-estimated-request budget
(100 reserved for status checks), a 1,000-core-request reserve, 30 minutes of
collection across resumes, and at most one transient retry per read / five
retry requests total. Record reservations and actual returned page counts in
one durable ledger. These are agent planning limits, not hard broker admission
limits: pagination can consume requests before returning. The helper's
deadline is a backstop, not a guarantee of a particular request count.
Do not wait automatically across quota resets or restart budgets on resume.
Synthesis delegates read saved evidence without issuing network requests.

Keep private evidence, ledger, and draft below the persistent bot checkout;
record paths and delivered/collecting/blocked/published state in the durable
task. The launcher clears the live session on restart; it does not clear these
checkout files or durable task records. Preserve them during deployment and
verify them read-only before/after restart. Restart loses live conversations;
it is not a request to publish or resume a report.

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
and captures all stdout bytes before interpreting them. It retains bounded stderr
in memory only, emitting fixed allowlisted cause labels, never raw prose, URLs,
or credential values. The labels distinguish reported execution-admission busy,
primary/secondary GitHub rate limits, authentication, HTTP 403/404, policy denial,
and timeout. Unknown errors preserve the exit code without guessing their cause;
in particular exit 125 alone does not establish quota exhaustion or congestion.
A deadline, I/O error, nonzero
exit, or output limit deletes the incomplete capture and fails explicitly.
Limits are 120 seconds, 256 MiB stdout, and 1 MiB stderr per invocation.

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
edit/push history separately. Expected discovery/candidate/budget limitations
are authorized for a clearly bounded weekly report without separate permission.
Actual failed requests are not expected coverage limitations: record endpoint,
sanitized cause, and retry count, and block publication if unresolved failures
could omit selected activity or misrepresent claims. Never claim exhaustive
coverage or silently omit failures.
