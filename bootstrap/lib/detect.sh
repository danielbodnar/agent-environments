# shellcheck shell=sh
# detect.sh: name the surface this shell is running on.
#
# Source it, then call `agent_env_surface`. Prints one of:
#   claude-self-hosted  Claude Code self-hosted runner session
#   claude-cloud        Claude Code on the web (Anthropic-hosted VM)
#   gha                 GitHub Actions job
#   codespaces          GitHub Codespaces
#   devcontainer        any other devcontainer (VS Code, devcontainer CLI)
#   sbx                 Docker Sandboxes microVM
#   nono                inside a nono sandbox
#   nspawn              systemd-nspawn container
#   container           Docker, Podman, or another OCI container
#   local               none of the above
#
# The first match wins, so the more specific surfaces come first: a
# Codespace is also a container, and a self-hosted runner session also
# sets CLAUDE_CODE_REMOTE.
#
# AGENT_ENV_SURFACE, when set, wins outright. Entry points that know where
# they run set it (the cloud setup script may run before CLAUDE_CODE_REMOTE
# exists).
#
# AGENT_ENV_ROOT prefixes the marker files it reads (/.dockerenv,
# /run/systemd/container, ...) so tests can point it at a fixture tree.

agent_env_surface() {
	_root=${AGENT_ENV_ROOT:-}

	if [ -n "${AGENT_ENV_SURFACE:-}" ]; then
		echo "$AGENT_ENV_SURFACE"
	elif [ -n "${CLAUDE_RUNNER_CLIENT_PLATFORM:-}" ] || [ -n "${CLAUDE_RUNNER_CLAUDE_BIN:-}" ]; then
		echo claude-self-hosted
	elif [ "${CLAUDE_CODE_REMOTE:-}" = true ]; then
		echo claude-cloud
	elif [ "${GITHUB_ACTIONS:-}" = true ]; then
		echo gha
	elif [ "${CODESPACES:-}" = true ]; then
		echo codespaces
	elif [ "${REMOTE_CONTAINERS:-}" = true ] || [ -n "${DEVCONTAINER:-}" ]; then
		echo devcontainer
	elif [ "${IS_SANDBOX:-}" = 1 ]; then
		echo sbx
	elif [ -n "${NONO_CAP_FILE:-}" ]; then
		echo nono
	elif [ "${container:-}" = systemd-nspawn ] ||
		{ [ -r "$_root/run/systemd/container" ] && [ "$(cat "$_root/run/systemd/container")" = systemd-nspawn ]; }; then
		echo nspawn
	elif [ -e "$_root/.dockerenv" ] || [ -e "$_root/run/.containerenv" ] || [ -n "${container:-}" ]; then
		echo container
	else
		echo local
	fi
}

# True when this surface is a disposable machine we're allowed to install
# system packages on (apt, /usr/local). `local` and `nono` are someone's
# workstation, so setup stays in user space there.
agent_env_disposable() {
	case $(agent_env_surface) in
	local | nono) return 1 ;;
	*) return 0 ;;
	esac
}
