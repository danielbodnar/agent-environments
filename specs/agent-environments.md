# Spec: agent-environments

Status: in progress, 2026-10-29.

## Context

The goal is one public repo that sets up the same agent toolchain (mise, bun, vlt, op, rumdl,
osv-scanner, socket/sfw, wrangler, `cf`, nushell, just, the lint/format set) on every surface
where Claude Code runs. The surfaces are Claude Code cloud environments, self-hosted runners,
Docker sandboxes, GitHub Actions, Codespaces/devcontainers, and generic sandboxes
(systemd-nspawn, `nono`). Secrets come from 1Password.

Decisions already made:

- **Secrets:** service account first. `OP_SERVICE_ACCOUNT_TOKEN` is the default. Connect is
  optional: the repo ships a compose file and the scripts accept `OP_CONNECT_HOST`/`OP_CONNECT_TOKEN`,
  but nothing gets deployed now.
- **Plugins:** a curated core set.
- **Git:** an initial commit on `main`, all the work on a feature branch, then a PR with Copilot
  requested as reviewer.
- **Public repo hygiene:** no vault names, Environment IDs, or Connect server ID in it. Use
  placeholders like `OP_ENVIRONMENT_ID` and `OP_VAULT`.

Facts from the research that shape the design:

- **Cloud setup script** (from the docs):
  - Runs as root on Ubuntu 24.04.
  - Must exit 0, finish in about 5 minutes to be cached, and stay at or under 64 KB.
  - Environment variables aren't set yet when it runs, and network secrets aren't attached to its
    requests. So `op` can't authenticate during setup. Secrets load at session time instead
    (SessionStart hook via `CLAUDE_ENV_FILE`, or a `with-secrets` wrapper).
  - The cloud sets `CLAUDE_CODE_REMOTE=true` and `CLAUDE_CODE_REMOTE_SESSION_ID`.
  - The cloud GitHub proxy rejects GraphQL, so `gh pr` and `gh issue` fail there.
  - Bun has known problems with the cloud security proxy.
- **Plugins:**
  - Repo `enabledPlugins` don't install external plugins, and cloud sessions install neither.
  - Cloud route: the setup script runs `claude plugin install` into `/root/.claude`. This is
    inferred from the docs, not documented, so it must be tested.
  - Containers and CI use the documented seed: `CLAUDE_CODE_PLUGIN_CACHE_DIR` at build time,
    `CLAUDE_CODE_PLUGIN_SEED_DIR` at runtime.
  - GitHub Actions uses the `plugin_marketplaces` and `plugins` inputs of `claude-code-action@v1`.
- **1Password:**
  - The 1Password Claude plugin needs the desktop app, so it's enabled only for `flynn`/local.
    Other surfaces document why it's absent.
  - Connect supports only `op read`, `op inject`, `op run` and `op item get`. It can't read
    Environments.
  - `op run --environment` needs CLI 2.41 or later and a service account with read access to the
    Environment.
- **Other surfaces:**
  - `--dangerously-skip-permissions` is rejected as root, so the devcontainer and Docker sandbox
    use a non-root user.
  - The bubblewrap sandbox inside unprivileged Docker needs `sandbox.enableWeakerNestedSandbox`.
- **Existing tool lists:** `~/.config/agents/mise/presets/{bun-web,cloudflare,lint-format,supply-chain}.toml`
  already define most of the toolchain. They are the source to copy from; don't retype them.

## Layout

See README.md for the surfaces and layers. Changes from the original
layout are in the Log.

## Verification

- `bats tests/`: surface detection, setup flags and dry runs, profile
  and lock invariants, with-secrets and session hook behaviour.
- Cloud path: `setup.sh --profile core` as root in a fresh `ubuntu:24.04`
  container with `AGENT_ENV_SURFACE=claude-cloud`. CI repeats it
  (`cloud-like` job) and fails over 300 s.
- Image: `images/Dockerfile` builds, `agent-env-doctor --strict` passes as
  `agent`, and `claude -p --debug` shows plugins loading from the seed.
- nono: the profile validates, and runs `claude` and `rg` with the repo
  writable and `~/.ssh` denied.
- Still needs a real run: a Claude cloud session (plugins surviving the
  setup snapshot), Docker Sandboxes (`sbx run`), the self-hosted runner
  (needs a Team/Enterprise org), nspawn import, and secret loading with a
  real service account token.

## Log

- 2026-10-29 [done] Repo created; `main` has LICENSE, .gitignore, README
  stub. Work on `feat/initial-environments`.
- 2026-10-29 [done] Socket gate: vlt 1.6.1, cf 1.0.0-beta.26, wrangler
  4.156.0, socket 1.12.1 all >= 90. sfw 2.0.6 (maintenance 84, quality 77)
  and @socketsecurity/bun-security-scanner 1.1.3 (maintenance 84) accepted
  and pinned; supply chain and vulnerability scores are 99-100.
- 2026-10-29 [changed] Tool lists moved from one conf.d file to
  `tools/<profile>/mise.toml` + `mise.lock`, because mise locks per config
  root. Disposable surfaces copy both into the global mise config.
- 2026-10-29 [changed] Every mise backend is explicit. The first lock
  picked asdf plugins (cloned from GitHub and GitLab at install time)
  because the locking machine had them.
- 2026-10-29 [dropped] duckdb from the full profile: the aqua lock had no
  download URL, so `--locked` installs failed.
- 2026-10-29 [changed] `AGENT_ENV_SURFACE` override added. The cloud
  setup script may run before `CLAUDE_CODE_REMOTE` is set, so
  `claude-cloud.sh` sets the surface explicitly.
- 2026-10-29 [done] Cold core setup in ubuntu:24.04: 60 s, second run 0 s,
  0 missing tools. Full image build: 2 min 11 s.
- 2026-10-29 [changed] `claude plugin list` doesn't show seeded plugins.
  The doctor reads the seed manifest instead. `claude -p --debug` confirms
  the seed loads ("Synced 2 marketplace(s) from seed dir(s)").
- 2026-10-29 [changed] Devcontainer adds the Claude Code VS Code extension
  directly instead of the devcontainer feature. The image already ships
  the native CLI, and the feature would add a second npm install.
- 2026-10-29 [dropped] Self-hosted lifecycle hooks. The built-in checkout
  is enough; only the `--exec-path` wrapper and a quadlet unit ship.
- 2026-10-29 [changed] Docker Sandboxes ship as a v3 workload kit
  (`sandboxes/sbx/agent-env/`); `docker sandbox` was removed in favour of
  `sbx` and kits. Not run yet.
- 2026-10-29 [changed] nono: security review flagged that writable `~/.claude`
  state (hooks, settings, shell snapshots, plugin data, `.claude.json`) lets a
  sandboxed agent affect later unsandboxed sessions. `claude-nono` now gives the
  sandbox its own `CLAUDE_CONFIG_DIR` and `TMPDIR`, and host plugins load as a
  read-only seed. Checked with a real `claude -p` turn: 32 plugins loaded, host
  `~/.claude` and `~/.claude.json` unwritable.
- 2026-10-29 [changed] `claude.yml` no longer passes `OP_SERVICE_ACCOUNT_TOKEN`
  to the comment-driven agent.
- 2026-10-29 [todo] Run a real Claude cloud session and record whether
  plugins installed by the setup script survive the snapshot.
- 2026-10-29 [todo] Deploy 1Password Connect only if service account rate
  limits become a problem.
