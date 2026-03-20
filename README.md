# Claude Code Bootstrap

Set up Claude Code for any project in under 60 seconds — powered by the [Superpowers plugin](https://github.com/pcvelz/superpowers).

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/Calibre9-Tech/claude-code-bootstrap/main/claude-bootstrap-installer.sh | bash
```

Then open Claude Code and say:

```
Use the project-bootstrap agent to set up this project
```

Answer 12 questions. Get a complete, structured Claude Code configuration.

## Upgrading an Existing Setup

Already have Claude Code configured? Run the same command:

```
Use the project-bootstrap agent to set up this project
```

The agent detects your existing `CLAUDE.md` and offers four options:

1. **Update** — adds any missing sections (agents, rules files, MCP config) without touching what you already have
2. **Add Superpowers** — only inserts the Superpowers workflow table into your existing `CLAUDE.md`
3. **Regenerate** — full re-interview and replaces all generated files
4. **Cancel** — exits without any changes

Your existing setup is never silently overwritten.

### Common upgrade scenarios

**Manually written `CLAUDE.md` you want to keep** — choose **Update**. The agent appends the Superpowers skill table, subagents table, and Verification Gate without touching your existing content.

**Stack changed** (e.g. added a database or moved to a new framework) — choose **Regenerate**. The agent re-interviews you and produces a fresh config reflecting the new stack, including the right MCP servers and specialized agents.

**Missing an agent** (e.g. never got `browser-tester.md` or `security-auditor.md`) — choose **Update**. The agent creates any missing files and skips ones that already exist.

**Just want Superpowers added** — choose **Add Superpowers**. This is the minimal path: only the skills workflow table is inserted.

## What the Installer Creates

```
.claude/
  settings.json          # EnterPlanMode blocked; PreToolUse file-guard hook
  hooks/
    file-guard.js        # Blocks writes to .env* and credential files
  commands/
    commit.md            # /commit  — lint, stage, conventional commit
    run-ci.md            # /run-ci  — iterate until lint + tests pass
    whats-next.md        # /whats-next — session handoff document
    fix-pr.md            # /fix-pr  — pull and address PR review comments
    summarize.md         # /summarize — session summary
  agents/
    project-bootstrap.md # Bootstrap agent (runs the interview)
    summarize-chat.md    # Session summarizer
```

## What the Bootstrap Agent Generates

After the interview, the bootstrap agent creates:

| File | Contents |
|------|---------|
| `CLAUDE.md` | Project overview, Superpowers workflow, Verification Gate, Token Efficiency, subagents table |
| `.mcp.json` | MCP servers for Supabase, GitHub, filesystem fallback (based on your stack) |
| `.claude/settings.json` | PostToolUse lint hook added for any project with a lint command |
| `.claude/rules/dev-reference.md` | Superpowers skills + slash commands (auto-loaded every session) |
| `.claude/rules/design-system.md` | Design token constraints (frontend projects) |
| `.claude/rules/database.md` | Schema and migration conventions (database projects) |
| `.claude/agents/general-assistant.md` | Always created |
| `.claude/agents/database-specialist.md` | Supabase, Postgres, Firebase, or MongoDB variant |
| `.claude/agents/browser-tester.md` | E2E testing agent using [agent-browser](https://agent-browser.dev) + [Lightpanda](https://lightpanda.io) (preferred engine) |
| `.claude/agents/code-reviewer.md` | Critical/Major/Minor tagging (team projects) |
| `.claude/agents/security-auditor.md` | OWASP Top 10 audit (team/production projects) |

## Superpowers Plugin

The installer auto-installs the [Superpowers plugin](https://github.com/pcvelz/superpowers) (v5.1.0). Every generated `CLAUDE.md` includes the full skills table.

New feature → brainstorming → writing-plans → executing-plans → verification-before-completion → requesting-code-review → finishing-a-development-branch

| Skill | Command |
|-------|---------|
| New feature idea | `/superpowers-extended-cc:brainstorming` |
| Plan work | `/superpowers-extended-cc:writing-plans` |
| Execute plan | `/superpowers-extended-cc:executing-plans` |
| Write tests first | `/superpowers-extended-cc:test-driven-development` |
| Debug | `/superpowers-extended-cc:systematic-debugging` |
| Verify before claiming done | `/superpowers-extended-cc:verification-before-completion` |
| Isolate work | `/superpowers-extended-cc:using-git-worktrees` |
| Run parallel agents | `/superpowers-extended-cc:dispatching-parallel-agents` |
| Review | `/superpowers-extended-cc:requesting-code-review` |
| Ship | `/superpowers-extended-cc:finishing-a-development-branch` |

## MCP Philosophy — CLI First

MCPs load their full tool schema into your context window on every session. The GitHub MCP costs ~55K tokens before you've done any work. A single `gh pr list` via CLI costs ~1.4K and is deterministic.

**Default: use CLI tools. Add MCPs only when no CLI alternative exists.**

| Need | Use | Token cost |
|------|-----|------------|
| GitHub (PRs, issues, reviews) | `gh` CLI | ~1.4K |
| GitHub MCP | ❌ skip | ~55K |
| Supabase migrations/schema | `supabase` CLI | ~800 |
| Supabase RLS (production) | Supabase MCP | ~50K |
| PostgreSQL queries | `psql` CLI | ~200 |
| MongoDB queries | `mongosh` CLI | ~200 |

The bootstrap generates Supabase MCP only for **production projects**. Solo/prototype projects get CLI guidance instead. GitHub MCP and filesystem MCP are never generated — `gh` CLI and database CLIs cover everything they do at a fraction of the cost.

**Note:** [agent-browser](https://agent-browser.dev) is a CLI tool — no MCP needed.

```bash
npm install -g agent-browser
# Install Lightpanda (preferred engine — 10x faster, 10x less memory than Chrome)
curl -L -o lightpanda https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-aarch64-macos \
  && chmod a+x ./lightpanda && mv ./lightpanda /usr/local/bin/lightpanda
```

Use `--engine lightpanda` for speed; fall back to Chrome for screenshots and features Lightpanda doesn't support (extensions, profiles, storage state).

## Security: file-guard.js Hook

Every install wires a `PreToolUse` hook blocking Claude from writing to:

- `.env`, `.env.*`, `.env.local`
- `credentials.json`
- `*.pem`, `*.key`, `*.p12`, `*.pfx`
- `id_rsa`, `*.secret`

These files must always be edited manually.

## Example Outputs

See `examples/` for complete generated `CLAUDE.md` files:

- [`examples/nextjs-supabase/CLAUDE.md`](examples/nextjs-supabase/CLAUDE.md) — Next.js + Supabase SaaS
- [`examples/python-fastapi/CLAUDE.md`](examples/python-fastapi/CLAUDE.md) — Python FastAPI + PostgreSQL
- [`examples/react-firebase/CLAUDE.md`](examples/react-firebase/CLAUDE.md) — React + Firebase

## Repository Layout

```
claude-bootstrap-installer.sh   # The only file you need
README.md
examples/
  nextjs-supabase/CLAUDE.md
  python-fastapi/CLAUDE.md
  react-firebase/CLAUDE.md
```

## Requirements

- `bash` 3.2+ (macOS default works)
- `node` 18+ (for file-guard.js hook)
- `claude` CLI (for Superpowers auto-install)
- `npx` (for MCP servers at runtime)

## License

MIT
