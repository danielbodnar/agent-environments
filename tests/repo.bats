#!/usr/bin/env bats
# Repo invariants: the full profile is a superset of core, generated files
# are current, and nothing secret-shaped is committed.

REPO="$BATS_TEST_DIRNAME/.."

tools_of() { sed -n '/^\[tools\]/,/^\[/p' "$1" | grep -E '^"?[a-z]' | cut -d= -f1 | tr -d ' "'; }

@test "full profile contains every core tool at the same version" {
	core=$(sed -n '/^\[tools\]/,/^\[settings\]/p' "$REPO/tools/core/mise.toml" | grep -E '^"?[a-z]')
	while IFS= read -r line; do
		grep -qxF "$line" "$REPO/tools/full/mise.toml" || {
			echo "missing from full: $line"
			return 1
		}
	done <<<"$core"
}

@test "every profile tool is in its lockfile" {
	for p in core full; do
		for t in $(tools_of "$REPO/tools/$p/mise.toml"); do
			grep -qF "[[tools.\"$t\"]]" "$REPO/tools/$p/mise.lock" ||
				grep -qF "[[tools.$t]]" "$REPO/tools/$p/mise.lock" || {
				echo "$p: $t not locked"
				return 1
			}
		done
	done
}

@test "no ubi backend" {
	run grep -rn 'ubi:' "$REPO/tools"
	[ "$status" -eq 1 ]
}

@test "claude/settings.json matches the plugin lists" {
	run "$REPO/scripts/gen-claude-settings.sh" --check
	[ "$status" -eq 0 ]
}

@test "with-secrets runs the command without auth" {
	run env -u OP_SERVICE_ACCOUNT_TOKEN -u OP_CONNECT_HOST -u OP_CONNECT_TOKEN \
		"$REPO/bin/with-secrets" -- echo ran
	[ "$status" -eq 0 ]
	[[ "$output" == *ran* ]]
	[[ "$output" == *"no 1Password auth"* ]]
}

@test "with-secrets --check reports no auth" {
	run env -u OP_SERVICE_ACCOUNT_TOKEN -u OP_CONNECT_HOST -u OP_CONNECT_TOKEN \
		"$REPO/bin/with-secrets" --check
	[ "$status" -eq 0 ]
	[[ "$output" == *"auth=none"* ]]
}

@test "with-secrets ignores OP_ENVIRONMENT_ID under Connect" {
	run env -u OP_SERVICE_ACCOUNT_TOKEN OP_CONNECT_HOST=https://connect.invalid OP_CONNECT_TOKEN=x \
		OP_ENVIRONMENT_ID=abc "$REPO/bin/with-secrets" --check
	[[ "$output" == *"ignored: Connect"* ]]
	[[ "$output" == *"auth=connect"* ]]
}

@test "session hook writes PATH and nothing secret by default" {
	envf="$BATS_TEST_TMPDIR/claude.env"
	run env -u OP_SERVICE_ACCOUNT_TOKEN CLAUDE_ENV_FILE="$envf" "$REPO/claude/hooks/session-secrets"
	[ "$status" -eq 0 ]
	grep -q '^export PATH=' "$envf"
	grep -q '^export AGENT_ENV_HOME=' "$envf"
	[ "$(wc -l <"$envf")" -eq 2 ]
}

@test "cloud setup script fits the 64 KB limit" {
	[ "$(wc -c <"$REPO/bootstrap/claude-cloud.sh")" -lt 65536 ]
}
