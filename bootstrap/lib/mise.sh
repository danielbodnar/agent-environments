# shellcheck shell=sh
# mise.sh: install mise and the toolchain for one profile.
#
# The profile's mise.toml and mise.lock become the user's global mise
# config, so every shell on the machine gets the tools. That only happens
# on disposable surfaces; on a workstation the tools install into the
# profile directory and nothing global changes.

mise_bin() {
	if have mise; then
		command -v mise
	elif [ -x "$HOME/.local/bin/mise" ]; then
		echo "$HOME/.local/bin/mise"
	else
		return 1
	fi
}

mise_install_self() {
	mise_bin >/dev/null && return 0
	# The official installer verifies the release checksum itself.
	curl -fsSL https://mise.run | MISE_QUIET=1 sh
	path_prepend "$HOME/.local/bin"
	mise_bin >/dev/null
}

# mise_tools <profile-dir>
mise_tools() {
	_dir=$1
	_mise=$(mise_bin) || return 1
	_global="${XDG_CONFIG_HOME:-$HOME/.config}/mise"

	if agent_env_disposable; then
		mkdir -p "$_global"
		cp "$_dir/mise.toml" "$_global/config.toml"
		cp "$_dir/mise.lock" "$_global/mise.lock"
		# The global config is normally trusted implicitly, but not when
		# mise runs under another HOME (sudo, su -). Trust it explicitly.
		"$_mise" trust -q "$_global/config.toml"
		_cfg_dir=$HOME
	else
		log "workstation: installing into $_dir only, global mise config untouched"
		"$_mise" trust -q "$_dir/mise.toml"
		_cfg_dir=$_dir
	fi

	# --locked refuses to resolve anything the lockfile doesn't cover, so a
	# setup run never reaches the GitHub API to look up "latest". That
	# matters in the cloud setup script, where GitHub calls are anonymous
	# and rate limited.
	(cd "$_cfg_dir" && "$_mise" install --locked --yes) || {
		warn "locked install failed, retrying without --locked"
		(cd "$_cfg_dir" && "$_mise" install --yes)
	}

	path_prepend "${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
	"$_mise" reshim
}

# Write a profile.d snippet so login shells find mise's shims. Bash tool
# calls in Claude Code get the same PATH from the SessionStart hook.
mise_profile_d() {
	agent_env_disposable || return 0
	# shellcheck disable=SC2016 # $PATH and $HOME expand when the snippet runs
	_snippet='# Added by agent-environments: put mise shims on PATH.
case ":$PATH:" in *":$HOME/.local/share/mise/shims:"*) ;; *) PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH" ;; esac
export PATH'
	if [ -d /etc/profile.d ] && printf '%s\n' "$_snippet" | as_root tee /etc/profile.d/agent-environments.sh >/dev/null 2>&1; then
		return 0
	fi
	grep -qF 'agent-environments' "$HOME/.profile" 2>/dev/null ||
		printf '\n%s\n' "$_snippet" >>"$HOME/.profile"
}
