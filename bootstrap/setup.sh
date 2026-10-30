#!/bin/sh
# setup.sh: install the agent toolchain on whatever surface this is.
#
# Usage:
#   bootstrap/setup.sh [--profile core|full] [--only LAYER[,LAYER...]] [--dry-run] [--strict]
#   bootstrap/setup.sh --surface      print the detected surface and exit
#   bootstrap/setup.sh --help
#
# Layers, in order:
#   system   apt packages (disposable surfaces only)
#   tools    mise plus tools/<profile>/mise.toml at the locked versions
#   op       1Password CLI, 2.41 or later
#   claude   Claude Code, ~/.claude/CLAUDE.md, merged settings.json
#   plugins  curated plugins from claude/plugins.txt
#
# Profiles: core (default) is sized for the Claude cloud setup script's
# five-minute cache window. full adds the heavier tools for images.
#
# Environment:
#   AGENT_ENV_PROFILE   same as --profile
#   AGENT_ENV_STRICT=1  fail on the first failed layer (CI and image builds)
#   AGENT_ENV_DRY_RUN=1 same as --dry-run
#
# Safe to rerun: every layer checks before it changes anything. Exits 0
# when a layer fails unless --strict, because the Claude cloud setup
# script must exit 0 for the session to start at all.
#
# Secrets are not loaded here. The cloud setup script runs before the
# environment's variables are set, so bin/with-secrets and the
# SessionStart hook resolve them at session time.
set -eu

AGENT_ENV_HOME=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
export AGENT_ENV_HOME

. "$AGENT_ENV_HOME/bootstrap/lib/common.sh"
. "$AGENT_ENV_HOME/bootstrap/lib/detect.sh"
. "$AGENT_ENV_HOME/bootstrap/lib/apt.sh"
. "$AGENT_ENV_HOME/bootstrap/lib/mise.sh"
. "$AGENT_ENV_HOME/bootstrap/lib/op.sh"
. "$AGENT_ENV_HOME/bootstrap/lib/claude.sh"

usage() { sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; }

profile=${AGENT_ENV_PROFILE:-core}
only=system,tools,op,claude,plugins
while [ $# -gt 0 ]; do
	case $1 in
	--profile)
		profile=${2:?--profile needs a value}
		shift
		;;
	--profile=*) profile=${1#*=} ;;
	--only)
		only=${2:?--only needs a value}
		shift
		;;
	--only=*) only=${1#*=} ;;
	--dry-run) AGENT_ENV_DRY_RUN=1 ;;
	--strict) AGENT_ENV_STRICT=1 ;;
	--surface)
		agent_env_surface
		exit 0
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
	esac
	shift
done
export AGENT_ENV_DRY_RUN="${AGENT_ENV_DRY_RUN:-0}" AGENT_ENV_STRICT="${AGENT_ENV_STRICT:-0}"

profile_dir="$AGENT_ENV_HOME/tools/$profile"
[ -r "$profile_dir/mise.toml" ] || {
	echo "unknown profile: $profile (have: core, full)" >&2
	exit 2
}

surface=$(agent_env_surface)
log "surface=$surface profile=$profile layers=$only"
path_prepend "$HOME/.local/bin"

# Bun has known problems with the Claude cloud security proxy.
[ "$surface" = claude-cloud ] && export MISE_NPM_PACKAGE_MANAGER=npm

wants() { case ",$only," in *",$1,"*) return 0 ;; *) return 1 ;; esac }

if wants system; then
	if agent_env_disposable; then
		step "system packages" apt_base
	else
		log "workstation: skipping system packages"
	fi
fi
if wants tools; then
	step "mise" mise_install_self
	step "tools ($profile)" mise_tools "$profile_dir"
	step "shell PATH" mise_profile_d
fi
wants op && step "1Password CLI" op_install
if wants claude; then
	step "Claude Code" claude_install
	step "Claude user files" claude_user_files "$AGENT_ENV_HOME"
fi
wants plugins && step "Claude plugins" claude_plugins "$AGENT_ENV_HOME"

log "done. Check with: $AGENT_ENV_HOME/bin/agent-env-doctor"
