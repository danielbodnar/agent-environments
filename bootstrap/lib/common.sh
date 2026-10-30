# shellcheck shell=sh
# common.sh: logging, privilege, and step helpers shared by setup.sh.

log() { printf '[agent-env] %s\n' "$*" >&2; }
warn() { printf '[agent-env] warning: %s\n' "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command as root: directly when we already are, through sudo when
# it's available without a password, and not at all otherwise.
as_root() {
	if [ "$(id -u)" -eq 0 ]; then
		"$@"
	elif have sudo && sudo -n true 2>/dev/null; then
		sudo -n "$@"
	else
		warn "needs root, skipped: $*"
		return 1
	fi
}

# Run one setup step. In dry-run mode, print it instead. A failing step
# logs a warning and returns 0 unless AGENT_ENV_STRICT=1, because the
# Claude cloud setup script must exit 0 or the session never starts.
step() {
	_name=$1
	shift
	if [ "${AGENT_ENV_DRY_RUN:-0}" = 1 ]; then
		log "would run: $_name"
		return 0
	fi
	log "step: $_name"
	if "$@"; then
		return 0
	fi
	if [ "${AGENT_ENV_STRICT:-0}" = 1 ]; then
		warn "step failed: $_name"
		exit 1
	fi
	warn "step failed, continuing: $_name"
	return 0
}

# Prepend a directory to PATH once.
path_prepend() {
	case ":$PATH:" in
	*":$1:"*) ;;
	*) PATH="$1:$PATH" ;;
	esac
	export PATH
}
