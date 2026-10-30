#!/usr/bin/env bats
# Surface detection: each surface from its environment variables or marker
# files, with a clean environment so the host running the tests can't leak in.

setup() {
	ROOT="$BATS_TEST_TMPDIR/root"
	mkdir -p "$ROOT/run/systemd"
}

surface() {
	env -i PATH="$PATH" AGENT_ENV_ROOT="$ROOT" "$@" \
		sh -c '. "$1"; agent_env_surface' sh "$BATS_TEST_DIRNAME/../bootstrap/lib/detect.sh"
}

@test "nothing set is local" {
	run surface
	[ "$output" = local ]
}

@test "AGENT_ENV_SURFACE overrides everything" {
	run surface AGENT_ENV_SURFACE=claude-cloud GITHUB_ACTIONS=true
	[ "$output" = claude-cloud ]
}

@test "self-hosted runner beats CLAUDE_CODE_REMOTE" {
	run surface CLAUDE_RUNNER_CLAUDE_BIN=/usr/bin/claude CLAUDE_CODE_REMOTE=true
	[ "$output" = claude-self-hosted ]
}

@test "CLAUDE_CODE_REMOTE is claude-cloud" {
	run surface CLAUDE_CODE_REMOTE=true
	[ "$output" = claude-cloud ]
}

@test "GitHub Actions" {
	run surface GITHUB_ACTIONS=true
	[ "$output" = gha ]
}

@test "Codespaces beats devcontainer and container" {
	touch "$ROOT/.dockerenv"
	run surface CODESPACES=true REMOTE_CONTAINERS=true
	[ "$output" = codespaces ]
}

@test "devcontainer via REMOTE_CONTAINERS or DEVCONTAINER" {
	run surface REMOTE_CONTAINERS=true
	[ "$output" = devcontainer ]
	run surface DEVCONTAINER=true
	[ "$output" = devcontainer ]
}

@test "Docker Sandboxes via IS_SANDBOX" {
	run surface IS_SANDBOX=1
	[ "$output" = sbx ]
}

@test "nono via NONO_CAP_FILE" {
	run surface NONO_CAP_FILE=/run/nono.json
	[ "$output" = nono ]
}

@test "nspawn from env or marker file" {
	run surface container=systemd-nspawn
	[ "$output" = nspawn ]
	echo systemd-nspawn >"$ROOT/run/systemd/container"
	run surface
	[ "$output" = nspawn ]
}

@test "container from /.dockerenv, /run/.containerenv, or container=" {
	touch "$ROOT/.dockerenv"
	run surface
	[ "$output" = container ]
	rm "$ROOT/.dockerenv"
	touch "$ROOT/run/.containerenv"
	run surface
	[ "$output" = container ]
	rm "$ROOT/run/.containerenv"
	run surface container=podman
	[ "$output" = container ]
}

@test "local and nono aren't disposable, containers are" {
	disposable() {
		env -i PATH="$PATH" AGENT_ENV_ROOT="$ROOT" "$@" \
			sh -c '. "$1"; agent_env_disposable' sh "$BATS_TEST_DIRNAME/../bootstrap/lib/detect.sh"
	}
	run disposable
	[ "$status" -eq 1 ]
	run disposable NONO_CAP_FILE=x
	[ "$status" -eq 1 ]
	run disposable container=podman
	[ "$status" -eq 0 ]
}
