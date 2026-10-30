#!/bin/sh
# import.sh: turn the agent-environments image into a systemd-nspawn machine.
#
# Usage: sandboxes/nspawn/import.sh [IMAGE] [NAME]
#   IMAGE  container image to export (default localhost/agent-environments:dev)
#   NAME   machine name (default agent-env)
#
# The root filesystem lands in /var/lib/machines/NAME. When the dataset
# mounted at /var/lib/machines is ZFS, the machine gets its own child
# dataset with canmount=noauto, so it can be snapshotted and cloned.
# Otherwise it's a plain directory.
#
# Refuses to touch an existing machine: rename or retire it first.
# Needs sudo for the dataset, the mount, and the extraction.
set -eu

image=${1:-localhost/agent-environments:dev}
name=${2:-agent-env}
dest=/var/lib/machines/$name
engine=$(command -v podman || command -v docker) || {
	echo "needs podman or docker" >&2
	exit 1
}

case $name in
*[!a-z0-9-]* | -* | *-) {
	echo "machine name must be lowercase letters, digits, and inner hyphens" >&2
	exit 2
} ;;
esac

if [ -e "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
	echo "$dest already exists and isn't empty; not overwriting it" >&2
	exit 1
fi

parent=$(zfs list -H -o name,mountpoint 2>/dev/null | awk '$2 == "/var/lib/machines" { print $1 }')
if [ -n "$parent" ]; then
	sudo zfs create -o canmount=noauto "$parent/$name"
	sudo zfs mount "$parent/$name"
	echo "dataset: $parent/$name"
else
	sudo mkdir -p "$dest"
fi

cid=$("$engine" create "$image")
trap '"$engine" rm -f "$cid" >/dev/null' EXIT
"$engine" export "$cid" | sudo tar -x -C "$dest" --numeric-owner

sudo install -D -m 0644 "$(dirname "$0")/agent-env.nspawn" "/etc/systemd/nspawn/$name.nspawn"
echo "machine ready: sudo systemd-nspawn -M $name"
