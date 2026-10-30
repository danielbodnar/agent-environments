# syntax=docker/dockerfile:1
# One image for the container surfaces: devcontainers and Codespaces,
# self-hosted Claude Code runners, Docker Sandboxes, and systemd-nspawn
# (exported as a root filesystem).
#
#   docker build -f images/Dockerfile -t agent-environments .
#   docker build -f images/Dockerfile --build-arg PROFILE=core .
#
# Runs as the non-root user `agent` (uid 1000), because Claude Code
# rejects --dangerously-skip-permissions as root. `agent` has
# passwordless sudo so setup.sh can add apt packages later.
FROM docker.io/library/ubuntu:24.04

ARG PROFILE=full
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git sudo \
 && rm -rf /var/lib/apt/lists/*

# The Ubuntu image ships a uid-1000 `ubuntu` user. Rename it so the uid
# matches a typical host user and bind mounts stay writable.
RUN usermod -l agent -d /home/agent -m ubuntu \
 && groupmod -n agent ubuntu \
 && printf 'agent ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/agent \
 && chmod 0440 /etc/sudoers.d/agent \
 && install -d -o agent -g agent /opt/agent-environments /opt/claude-seed

COPY --chown=agent:agent . /opt/agent-environments
COPY images/managed-settings.json /etc/claude-code/managed-settings.json

USER agent
WORKDIR /home/agent
ENV PATH=/opt/agent-environments/bin:/home/agent/.local/bin:/home/agent/.local/share/mise/shims:$PATH

# AGENT_ENV_SURFACE=container makes the build install system-wide even
# though Docker build has no /.dockerenv. --strict fails the build on any
# broken layer instead of shipping a half-built image.
RUN AGENT_ENV_SURFACE=container sh /opt/agent-environments/bootstrap/setup.sh \
      --profile "$PROFILE" --only system,tools,op,claude --strict \
 && rm -rf /home/agent/.cache/mise /home/agent/.npm /home/agent/.bun/install/cache

# Plugins go into a seed directory rather than ~/.claude, so a volume
# mounted over ~/.claude (devcontainers do this to keep the login) still
# sees them. Claude Code reads the seed through CLAUDE_CODE_PLUGIN_SEED_DIR.
RUN AGENT_ENV_SURFACE=container CLAUDE_CODE_PLUGIN_CACHE_DIR=/opt/claude-seed \
      sh /opt/agent-environments/bootstrap/setup.sh --only plugins --strict
ENV CLAUDE_CODE_PLUGIN_SEED_DIR=/opt/claude-seed

CMD ["bash", "-l"]
