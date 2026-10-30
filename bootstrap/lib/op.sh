# shellcheck shell=sh
# op.sh: install the 1Password CLI.
#
# `op run --environment` needs 2.41 or later. On Debian and Ubuntu with
# root, the signed apt repo is used. Elsewhere the release zip goes to
# ~/.local/bin after its gpg signature checks out.

OP_MIN_VERSION=2.41.0
# 1Password's CLI release signing key.
OP_GPG_KEY=3FEF9748469ADBE15DA7CA80AC2D62742012EA22 # gitleaks:allow (public key fingerprint)

# version_ge A B: true when version A >= B. Pre-release suffixes are
# dropped, so 2.42.0-beta.01 compares as 2.42.0.
version_ge() {
	_a=${1%%-*}
	_b=${2%%-*}
	[ "$(printf '%s\n%s\n' "$_b" "$_a" | sort -V | head -n1)" = "$_b" ]
}

op_ok() {
	have op && version_ge "$(op --version 2>/dev/null)" "$OP_MIN_VERSION"
}

op_install_apt() {
	have apt-get && have dpkg || return 1
	[ "$(id -u)" -eq 0 ] || { have sudo && sudo -n true 2>/dev/null; } || return 1
	_arch=$(dpkg --print-architecture)
	_key=https://downloads.1password.com/linux/keys/1password.asc
	curl -fsSL "$_key" | as_root gpg --dearmor --yes --output /usr/share/keyrings/1password-archive-keyring.gpg &&
		echo "deb [arch=$_arch signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$_arch stable main" |
		as_root tee /etc/apt/sources.list.d/1password.list >/dev/null &&
		as_root mkdir -p /etc/debsig/policies/AC2D62742012EA22 /usr/share/debsig/keyrings/AC2D62742012EA22 &&
		curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol |
		as_root tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null &&
		curl -fsSL "$_key" | as_root gpg --dearmor --yes --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg &&
		as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq &&
		as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq 1password-cli
}

op_install_zip() {
	case $(uname -m) in
	x86_64) _arch=amd64 ;;
	aarch64 | arm64) _arch=arm64 ;;
	*)
		warn "no 1Password CLI build for $(uname -m)"
		return 1
		;;
	esac
	_ver=$(curl -fsSL https://app-updates.agilebits.com/check/1/0/CLI2/en/2.0.0/N |
		grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1) || return 1
	_work=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/op-install.XXXXXX") || return 1
	curl -fsSL -o "$_work/op.zip" \
		"https://cache.agilebits.com/dist/1P/op2/pkg/v$_ver/op_linux_${_arch}_v$_ver.zip" &&
		unzip -q -d "$_work" "$_work/op.zip" &&
		GNUPGHOME="$_work/gnupg" sh -c 'mkdir -m 700 "$GNUPGHOME" &&
			gpg -q --keyserver hkps://keyserver.ubuntu.com --receive-keys '"$OP_GPG_KEY"' &&
			gpg -q --verify "$1/op.sig" "$1/op"' sh "$_work" &&
		mkdir -p "$HOME/.local/bin" &&
		install -m 0755 "$_work/op" "$HOME/.local/bin/op"
	_rc=$?
	rm -rf "$_work"
	path_prepend "$HOME/.local/bin"
	return $_rc
}

op_install() {
	op_ok && return 0
	if agent_env_disposable && op_install_apt; then
		return 0
	fi
	op_install_zip
}
