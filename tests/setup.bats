#!/usr/bin/env bats
# setup.sh argument handling and dry runs. Nothing here installs anything.

SETUP="$BATS_TEST_DIRNAME/../bootstrap/setup.sh"

@test "--help prints usage" {
	run sh "$SETUP" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"--profile core|full"* ]]
}

@test "unknown flag exits 2" {
	run sh "$SETUP" --bogus
	[ "$status" -eq 2 ]
}

@test "unknown profile exits 2" {
	run sh "$SETUP" --profile nope --dry-run
	[ "$status" -eq 2 ]
	[[ "$output" == *"unknown profile"* ]]
}

@test "--surface honors AGENT_ENV_SURFACE" {
	AGENT_ENV_SURFACE=gha run sh "$SETUP" --surface
	[ "$output" = gha ]
}

@test "dry run on a container lists every layer" {
	AGENT_ENV_SURFACE=container run sh "$SETUP" --dry-run
	[ "$status" -eq 0 ]
	for layer in "system packages" mise "tools (core)" "1Password CLI" "Claude Code" "Claude user files" "Claude plugins"; do
		[[ "$output" == *"would run: $layer"* ]]
	done
}

@test "dry run on a workstation skips system packages" {
	AGENT_ENV_SURFACE=local run sh "$SETUP" --dry-run
	[ "$status" -eq 0 ]
	[[ "$output" == *"workstation: skipping system packages"* ]]
	[[ "$output" != *"would run: system packages"* ]]
}

@test "--only limits layers" {
	AGENT_ENV_SURFACE=container run sh "$SETUP" --dry-run --only op
	[[ "$output" == *"would run: 1Password CLI"* ]]
	[[ "$output" != *"would run: mise"* ]]
}
