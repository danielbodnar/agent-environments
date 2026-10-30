#!/bin/sh
# runner-wrapper.sh: --exec-path wrapper for `claude self-hosted-runner`.
#
# The runner starts this once per session in place of Claude Code. It puts
# the agent toolchain on PATH, marks the surface, and execs the runner's
# own Claude Code binary. exec keeps stdin and file descriptor 3 attached,
# which the runner needs for token refreshes, and passes the full managed
# environment through.
#
# Secrets aren't resolved here: the SessionStart hook and bin/with-secrets
# do that inside the session, from OP_SERVICE_ACCOUNT_TOKEN in the
# runner's environment.
set -eu

AGENT_ENV_HOME=${AGENT_ENV_HOME:-/opt/agent-environments}
export AGENT_ENV_HOME AGENT_ENV_SURFACE=claude-self-hosted
PATH="$AGENT_ENV_HOME/bin:$HOME/.local/bin:${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH"
export PATH

exec "$CLAUDE_RUNNER_CLAUDE_BIN" "$@"
