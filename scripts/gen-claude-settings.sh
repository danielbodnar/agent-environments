#!/bin/sh
# gen-claude-settings.sh: rebuild claude/settings.json from
# claude/marketplaces.txt and claude/plugins.txt.
#
# Usage: scripts/gen-claude-settings.sh [--check]
#   --check  exit 1 if claude/settings.json is out of date, change nothing
#
# Needs jq. The hook and attribution blocks are fixed; the marketplace and
# plugin blocks come from the two list files, so the lists stay the one
# place to edit.
set -eu
cd "$(dirname "$0")/.."

entries() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }

markets=$(entries claude/marketplaces.txt |
	jq -Rn '[inputs | split(" ") | {(.[0]): {source: {source: "github", repo: .[1]}}}] | add')
plugins=$(entries claude/plugins.txt | jq -Rn '[inputs | {(.): true}] | add')

new=$(jq -n --argjson m "$markets" --argjson p "$plugins" '{
  attribution: {commit: "", pr: ""},
  env: {CLAUDE_CODE_PLUGIN_PREFER_HTTPS: "1"},
  hooks: {SessionStart: [{hooks: [{
    type: "command",
    command: "${AGENT_ENV_HOME}/claude/hooks/session-secrets",
    timeout: 60
  }]}]},
  extraKnownMarketplaces: $m,
  enabledPlugins: $p
}')

if [ "${1:-}" = --check ]; then
	printf '%s\n' "$new" | diff -u claude/settings.json - >&2 || {
		echo "claude/settings.json is stale: run scripts/gen-claude-settings.sh" >&2
		exit 1
	}
	exit 0
fi
printf '%s\n' "$new" >claude/settings.json
