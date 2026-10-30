# agent-environments

Bootstrap for the agent toolchain across Claude Code cloud, self-hosted
runners, devcontainers, GitHub Actions, and sandboxes. See README.md.

## Conventions

- Shell is POSIX sh, checked with `shellcheck` and formatted with
  `shfmt` (tabs). No bashisms outside `tests/*.bats`.
- Every setup layer is idempotent and checks before it changes anything.
  A failed layer warns and continues unless `AGENT_ENV_STRICT=1`.
- Tool lists live in `tools/<profile>/mise.toml` with explicit backends.
  Never the `ubi:` backend. Regenerate locks with `just lock <profile>`.
- Score any npm tool before adding or bumping it:
  `socket package shallow npm pkg:npm/<name>@<version> --markdown`. Pin the
  scored version in `tools/core/mise.toml`.
- `claude/settings.json` is generated. Edit `claude/plugins.txt` or
  `claude/marketplaces.txt` and run `just settings`.
- No secrets, vault names, Environment IDs, or Connect server IDs in the
  repo. Use `OP_VAULT`, `OP_ENVIRONMENT_ID`, and `env/.env.tpl`
  placeholders.
- Run `just lint test` before committing. Conventional commits.

## Specs

- in progress 2026-10-29 — [specs/agent-environments.md](specs/agent-environments.md) —
  initial build across all surfaces; cloud session and Docker Sandboxes checks
  still need a real run.
