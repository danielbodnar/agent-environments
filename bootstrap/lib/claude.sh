# shellcheck shell=sh
# claude.sh: Claude Code itself, user-level instructions and settings, and
# the curated plugins.
#
# Repo settings can't install plugins from another marketplace, and
# Claude cloud sessions install none at all, so plugins go in through
# `claude plugin install` at setup time. When CLAUDE_CODE_PLUGIN_CACHE_DIR
# is set (an image build), the same commands fill that directory as a
# seed, and the runtime reads it through CLAUDE_CODE_PLUGIN_SEED_DIR.

claude_install() {
	have claude && return 0
	# Native installer: puts the binary in ~/.local/bin and verifies it.
	curl -fsSL https://claude.ai/install.sh | bash
	path_prepend "$HOME/.local/bin"
	have claude
}

# claude_user_files <repo-root>
# Install the portable CLAUDE.md and merge settings.json into the user's
# settings. Workstations keep their own files.
claude_user_files() {
	_repo=$1
	agent_env_disposable || {
		log "workstation: leaving ~/.claude/CLAUDE.md and settings.json alone"
		return 0
	}
	_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
	mkdir -p "$_dir"
	cp "$_repo/claude/CLAUDE.md" "$_dir/CLAUDE.md"
	# Hooks call scripts from this checkout. Pin the path in the merged copy.
	_new=$(sed "s|\${AGENT_ENV_HOME}|$_repo|g" "$_repo/claude/settings.json")
	if [ -s "$_dir/settings.json" ]; then
		printf '%s' "$_new" | jq -s '.[0] * .[1]' "$_dir/settings.json" - >"$_dir/settings.json.new"
	else
		printf '%s\n' "$_new" >"$_dir/settings.json.new"
	fi
	mv "$_dir/settings.json.new" "$_dir/settings.json"
}

# Strip comments and blank lines from a list file.
list_entries() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }

# claude_plugins <repo-root>
claude_plugins() {
	_repo=$1
	have claude || {
		warn "claude not installed, skipping plugins"
		return 1
	}
	_mk="$_repo/claude/marketplaces.txt"
	_pl="$_repo/claude/plugins.txt"
	if [ "$(agent_env_surface)" = local ]; then
		_mk="$_mk $_repo/claude/marketplaces.local.txt"
		_pl="$_pl $_repo/claude/plugins.local.txt"
	fi
	export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1

	_known=$(claude plugin marketplace list 2>/dev/null || true)
	# shellcheck disable=SC2086 # two file names at most
	list_entries_all $_mk | while read -r _name _src; do
		case $_known in *"$_name"*) continue ;; esac
		claude plugin marketplace add "$_src" || warn "marketplace add failed: $_src"
	done

	_installed=$(claude plugin list 2>/dev/null || true)
	# shellcheck disable=SC2086
	list_entries_all $_pl | while read -r _plugin; do
		case $_installed in *"$_plugin"*) continue ;; esac
		claude plugin install --scope user "$_plugin" || warn "plugin install failed: $_plugin"
	done
}

list_entries_all() {
	for _f in "$@"; do
		[ -r "$_f" ] && list_entries "$_f"
	done
}
