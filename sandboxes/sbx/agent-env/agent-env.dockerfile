# Workload content for the agent-env Docker Sandboxes kit: the
# agent-environments image, which already runs as `agent` (uid 1000)
# with the toolchain and seeded plugins on PATH.
ARG IMAGE=ghcr.io/danielbodnar/agent-environments:latest
FROM ${IMAGE}
ENV IS_SANDBOX=1
WORKDIR /home/agent/workspace
ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
