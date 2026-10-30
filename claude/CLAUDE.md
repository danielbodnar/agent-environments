# Agent defaults

User-level instructions for agent sessions on any machine set up by
agent-environments. A repo's own conventions, `AGENTS.md`, and `CLAUDE.md`
take precedence over everything here.

## Writing

- Write plainly. Lead with what happened, then the evidence, in separate
  sentences. Plain words, contractions, one idea per sentence.
- Be terse in replies, commit messages, and PR descriptions.
- No AI attribution: no `Co-Authored-By: Claude`, no "Generated with"
  footers, no session trailers.
- Keep instructions about the work and session status out of the files
  you write. Status goes in the reply.
- Never put a personal email address in a public artifact.

## Stack

- TypeScript (strict, ESM) on Bun. Bun is the installer: `bun install`,
  `bun add`, `bun.lock` as the only lockfile.
- No Python unless the repo already uses it. No `python3 - <<EOF` to edit
  files.
- No React in new work. Prefer Astro with Vue, Svelte, Solid, or Lit, and
  Hono for servers.
- Lint and format with oxlint/oxfmt and Biome, Markdown with rumdl. No
  Prettier or ESLint in anything new.
- Cloudflare Workers is the default platform. Every `wrangler.jsonc`
  enables observability (logs, invocation logs, traces) and Logpush.
- Layouts are fluid: grid with `auto-fit`/`minmax(min(100%, 30rem), 1fr)`,
  `clamp()`, container queries. No px breakpoints, no max-width page shell.

## Supply chain

- Before adding or upgrading a dependency, score it:
  `socket package shallow npm pkg:npm/<name>@<version> --markdown`. Stop and
  ask when any score is under 90.
- After an install, run `bun audit`, then `npm audit`.
- Never install `atomic-lockfile`, `js-digest`, `lockfile-js`,
  `nextfile-js`, or anything published by `herbsobering`.

## Tools

- Search with `rg` and `fd`, not `grep` and `find`. Bulk edits with `sd`
  and `ast-grep`.
- Tasks go in a `justfile`. Tool versions come from mise.
- Don't leave scratch files. Something needed twice becomes a documented
  script or `just` recipe.

## Secrets

- Run commands that need secrets through `with-secrets -- <command>`. It
  uses `OP_SERVICE_ACCOUNT_TOKEN` (or a 1Password Connect server) and reads
  `OP_ENVIRONMENT_ID` or an env file of `op://` references.
- Don't print secret values, write them to files, or paste them into
  commits.

## Environment notes

- `agent-env-doctor` reports the surface, tools, 1Password auth, and
  plugins.
- In Claude Code cloud sessions the GitHub proxy rejects GraphQL, so
  `gh pr` and `gh issue` fail. Use `gh api repos/<owner>/<repo>/...`.
- Don't commit or push unless asked.
