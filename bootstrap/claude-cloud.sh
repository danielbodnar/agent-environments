#!/bin/bash
# Paste this into the Setup script field of a Claude Code cloud
# environment (claude.ai/code > environment > Setup script).
#
# It runs as root on Ubuntu 24.04 before Claude Code starts, and its
# result is cached when it finishes in about five minutes. Environment
# variables aren't set yet, so nothing here needs a secret.
#
# Needs the network to reach GitHub, mise.run, and the package hosts in
# env/cloud-network-allowlist.txt.

repo=https://github.com/danielbodnar/agent-environments.git
dest=/opt/agent-environments

if [ -d "$dest/.git" ]; then
	git -C "$dest" pull --ff-only --quiet || true
else
	git clone --depth 1 --quiet "$repo" "$dest" || exit 0
fi

AGENT_ENV_SURFACE=claude-cloud sh "$dest/bootstrap/setup.sh" --profile core || true
exit 0
