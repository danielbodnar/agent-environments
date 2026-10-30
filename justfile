# Recipes for working on agent-environments. `just --list` shows them all.

image := "localhost/agent-environments:dev"
engine := `command -v podman || command -v docker`

default:
    @just --list

# Install the agent toolchain on this machine (profile: core or full)
setup profile="core":
    sh bootstrap/setup.sh --profile {{profile}}

# Show what setup would do here, without changing anything
plan profile="core":
    sh bootstrap/setup.sh --profile {{profile}} --dry-run

# Report the surface, tools, 1Password auth, and plugins
doctor:
    bin/agent-env-doctor

# Lint shell, Markdown, and workflows
lint:
    shellcheck bootstrap/*.sh bootstrap/lib/*.sh bin/* claude/hooks/* scripts/*.sh self-hosted/*.sh
    shfmt -d bootstrap bin claude/hooks scripts self-hosted
    rumdl check .
    actionlint
    zizmor --min-severity medium .github

# Run the bats suite
test:
    bats tests/

# Rebuild claude/settings.json from claude/plugins.txt and marketplaces.txt
settings:
    scripts/gen-claude-settings.sh

# Re-resolve "latest" for one profile and rewrite its lockfile
lock profile="core":
    cd tools/{{profile}} && mise lock --platform linux-x64,linux-arm64

# Build the container image
image profile="full":
    {{engine}} build -f images/Dockerfile --build-arg PROFILE={{profile}} -t {{image}} .

# Run the cloud setup path in a fresh Ubuntu container and time it
cloud-test:
    {{engine}} run --rm -v "$PWD:/opt/agent-environments:ro,z" -e AGENT_ENV_SURFACE=claude-cloud \
        docker.io/library/ubuntu:24.04 bash -c 'apt-get update -qq && apt-get install -y -qq curl ca-certificates git >/dev/null \
        && time sh /opt/agent-environments/bootstrap/setup.sh --profile core \
        && /opt/agent-environments/bin/agent-env-doctor --strict'

# Export the image into a systemd-nspawn machine under /var/lib/machines
nspawn-import name="agent-env":
    sh sandboxes/nspawn/import.sh {{image}} {{name}}

# Start the 1Password Connect server (needs connect/1password-credentials.json)
connect-up:
    {{engine}} compose -f connect/compose.yaml up -d
