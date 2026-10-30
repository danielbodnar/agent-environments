# shellcheck shell=sh
# apt.sh: base system packages on Debian and Ubuntu images.
#
# bubblewrap and socat back Claude Code's Bash sandbox on Linux. unzip and
# gnupg are needed for the 1Password CLI fallback install.

AGENT_ENV_APT_PACKAGES="bubblewrap build-essential ca-certificates curl git gnupg jq socat unzip xz-utils"

apt_base() {
	have apt-get || {
		log "no apt-get, skipping system packages"
		return 0
	}
	# Every package already present means nothing to do, and no network.
	_missing=
	for _p in $AGENT_ENV_APT_PACKAGES; do
		dpkg -s "$_p" >/dev/null 2>&1 || _missing="$_missing $_p"
	done
	[ -z "$_missing" ] && return 0
	# shellcheck disable=SC2086 # word splitting is the package list
	as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq &&
		as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends $_missing
}
