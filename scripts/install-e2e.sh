#!/bin/sh
# The story's install transcript: a clean Claude Code adds this checkout as a marketplace, installs
# motir@motir-skills, and the installed plugin carries the eight skills and the `motir` MCP server, no
# script (MOTIR-11095), and the CLI version its README pins runs through npx. Every command, its output and its exit code go to the
# transcript; the first assertion that misses fails the run.
#
#   scripts/install-e2e.sh [checkout]   (default: the repository this script sits in)
#
# Needs sh, node >= 22 (npx) and python3. HOME and CLAUDE_CONFIG_DIR are pointed at fresh temp
# directories, so no user configuration leaks in.

set -u

CLAUDE_CODE="@anthropic-ai/claude-code@2.1.283"
CHECKOUT=$(cd "${1:-$(dirname "$0")/..}" && pwd)
TRANSCRIPT=${TRANSCRIPT:-$(pwd)/install-transcript.txt}
SKILLS="motir-continue motir-fix motir-fix-bugs motir-guide motir-log-bug motir-mark motir-review motir-run"
MCP_URL="https://app.motir.co/api/mcp"
PLUGIN="$CHECKOUT/plugins/motir"
CLI_VERSION=$(grep -o '@motir/cli@[0-9][0-9A-Za-z.+-]*[0-9A-Za-z]' "$PLUGIN/README.md" | head -n 1 | sed 's/^@motir\/cli@//')
VERSION=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$PLUGIN/.claude-plugin/plugin.json")

# npx's cache stays where it was, so the pinned packages are fetched once per machine, not per HOME.
NPM_CONFIG_CACHE=${NPM_CONFIG_CACHE:-$(npm config get cache)}
export NPM_CONFIG_CACHE
WORK=$(mktemp -d)
HOME="$WORK/home"
CLAUDE_CONFIG_DIR="$WORK/claude"
mkdir -p "$HOME" "$CLAUDE_CONFIG_DIR"
export HOME CLAUDE_CONFIG_DIR
trap 'rm -rf "$WORK"' EXIT

OUT="$WORK/out"
: >"$TRANSCRIPT"

log() { printf '%s\n' "$*" >>"$TRANSCRIPT"; }

# step <title> <command...> — run it, record command, output and exit code; the output stays in $OUT.
step() {
  title=$1
  shift
  log "== $title"
  log "\$ $*"
  "$@" >"$OUT" 2>&1
  code=$?
  cat "$OUT" >>"$TRANSCRIPT"
  log "[exit $code]"
  log ""
  return 0
}

pass() { log "PASS: $1"; log ""; echo "✔ $1"; }
miss() {
  log "FAIL: $1"
  echo "✘ $1" >&2
  echo "  transcript: $TRANSCRIPT" >&2
  exit 1
}

claude() { npx --yes "$CLAUDE_CODE" "$@"; }

log "Install transcript — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "checkout: $CHECKOUT"
log "claude code: $CLAUDE_CODE · plugin version: $VERSION · CLI pin: $CLI_VERSION · node: $(node --version)"
log ""

step "Add the checkout as a marketplace" claude plugin marketplace add "$CHECKOUT"
[ "$code" -eq 0 ] || miss "marketplace add exited $code"
step "List marketplaces" claude plugin marketplace list --json
python3 - "$OUT" <<'EOF' || miss "marketplace list does not show motir-skills"
import json, sys
names = [m.get("name") for m in json.load(open(sys.argv[1]))]
sys.exit(0 if "motir-skills" in names else 1)
EOF
pass "marketplace motir-skills is listed"

step "Install the plugin" claude plugin install motir@motir-skills --scope user --json
[ "$code" -eq 0 ] || miss "plugin install exited $code"
python3 - "$OUT" <<'EOF' || miss "plugin install did not report success"
import json, sys
last = [l for l in open(sys.argv[1]).read().splitlines() if l.strip()][-1]
result = json.loads(last)
sys.exit(0 if result.get("outcome") == "ok" and result.get("pluginId") == "motir@motir-skills" else 1)
EOF
pass "motir@motir-skills installed"

step "List installed plugins" claude plugin list --json
INSTALL_PATH=$(python3 - "$OUT" "$VERSION" "$MCP_URL" <<'EOF'
import json, sys
plugins = [p for p in json.load(open(sys.argv[1])) if p.get("id") == "motir@motir-skills"]
if len(plugins) != 1:
    sys.exit("expected one motir@motir-skills entry, found %d" % len(plugins))
p = plugins[0]
if p.get("version") != sys.argv[2] or p.get("enabled") is not True or not p.get("installPath"):
    sys.exit("version / enabled / installPath wrong: %r" % p)
server = (p.get("mcpServers") or {}).get("motir") or {}
if server.get("type") != "http" or server.get("url") != sys.argv[3]:
    sys.exit("mcpServers.motir wrong: %r" % server)
print(p["installPath"])
EOF
) || miss "plugin list: motir@motir-skills is not installed as $VERSION, enabled, with the motir MCP server at $MCP_URL"
log "installPath: $INSTALL_PATH"
pass "installed $VERSION, enabled, motir MCP server at $MCP_URL"

step "Component inventory" claude plugin details motir@motir-skills
[ "$code" -eq 0 ] || miss "plugin details exited $code"
for skill in $SKILLS; do
  grep -E "^ *Skills \(8\)" "$OUT" | grep -qw -- "$skill" || miss "plugin details does not list skill $skill among eight"
done
grep -qE "^ *MCP servers \(1\) +motir( |$)" "$OUT" || miss "plugin details does not list the one MCP server motir"
pass "inventory: the eight skills and the motir MCP server"

log "== No executable directory in the installed copy"
log "\$ test ! -e $INSTALL_PATH/bin"
[ ! -e "$INSTALL_PATH/bin" ] || miss "the installed copy has a bin/"
log ""
pass "no bin/ under installPath"

log "== No script in the installed copy"
log "\$ grep -rl '^#!' $INSTALL_PATH"
SCRIPTS=$(grep -rl --exclude-dir=.git '^#!' "$INSTALL_PATH" 2>/dev/null)
log "$SCRIPTS"
log ""
[ -z "$SCRIPTS" ] || miss "the installed copy carries a script: $SCRIPTS"
pass "no file under installPath starts with #!"

step "The CLI the README pins, through npx" npx --yes "@motir/cli@$CLI_VERSION" --version
[ "$code" -eq 0 ] || miss "npx @motir/cli@$CLI_VERSION --version exited $code"
[ "$(tail -n 1 "$OUT")" = "$CLI_VERSION" ] || miss "@motir/cli@$CLI_VERSION --version printed '$(tail -n 1 "$OUT")'"
pass "npx @motir/cli@$CLI_VERSION prints $CLI_VERSION"

log "ALL PASSED"
echo "transcript: $TRANSCRIPT"
