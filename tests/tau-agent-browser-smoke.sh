set -euxo pipefail

test "$(id -u)" = 1001
command -v agent-browser
work=$(mktemp -d /tmp/browser-smoke-XXXXXX)
export AGENT_BROWSER_SESSION=smoke
trap 'agent-browser close || true; rm -rf "$work"' EXIT

cat >"$work/index.html" <<'EOF'
<!doctype html>
<title>Bot browser fixture</title>
<body style="background: #123456">
<h1>Local browser fixture</h1>
<button onclick="document.querySelector('h1').textContent='Clicked successfully'">Click me</button>
</body>
EOF
agent-browser open "file://$work/index.html"
test "$(agent-browser get title)" = "Bot browser fixture"
agent-browser snapshot -i | grep -F 'Click me'
agent-browser find role button click --name "Click me"
test "$(agent-browser get text h1)" = "Clicked successfully"
agent-browser screenshot "$work/page.png"
python - "$work/page.png" <<'PY'
import sys
from PIL import Image

with Image.open(sys.argv[1]) as image:
    image.load()
    assert image.format == "PNG"
    assert image.width >= 800 and image.height >= 600
    assert image.convert("RGB").getpixel((image.width - 1, image.height - 1)) == (18, 52, 86)
PY

# Check the browser's own sandbox status, not just the launch flags.
agent-browser open chrome://sandbox
agent-browser get text body | tee "$work/sandbox"
grep -E 'Layer 1 Sandbox[[:space:]]+Namespace' "$work/sandbox"
grep -E 'PID namespaces[[:space:]]+Yes' "$work/sandbox"
grep -E 'Network namespaces[[:space:]]+Yes' "$work/sandbox"
grep -E 'Seccomp-BPF sandbox[[:space:]]+Yes' "$work/sandbox"
agent-browser close

# Both an explicit opt-out and upstream's automatic CI fallback fail closed.
if agent-browser --args --no-sandbox open about:blank >"$work/refusal" 2>&1; then
    echo "unexpected sandbox opt-out" >&2
    exit 1
fi
cat "$work/refusal"
grep -F "refusing to disable Chromium's sandbox" "$work/refusal"
agent-browser close
if CI=1 agent-browser open about:blank >"$work/refusal" 2>&1; then
    echo "unexpected automatic sandbox opt-out" >&2
    exit 1
fi
cat "$work/refusal"
grep -F "refusing to disable Chromium's sandbox" "$work/refusal"
agent-browser close
