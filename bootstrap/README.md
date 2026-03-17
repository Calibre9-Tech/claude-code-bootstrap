# Bootstrap Reference

Reference documentation for the Claude Code Bootstrap system v3.0.0.

## How It Works

### 1. Installer (`claude-bootstrap-installer.sh`)

Run once per project. Creates the `.claude/` skeleton and installs the Superpowers plugin.

```bash
bash claude-bootstrap-installer.sh
```

Creates:
- `.claude/settings.json` — EnterPlanMode blocked; PreToolUse file-guard hook
- `.claude/hooks/file-guard.js` — blocks writes to .env* and credentials
- `.claude/commands/` — 5 slash commands (commit, run-ci, whats-next, fix-pr, summarize)
- `.claude/agents/project-bootstrap.md` — the bootstrap agent
- `.claude/agents/summarize-chat.md` — session summarizer

### 2. Bootstrap Agent (`project-bootstrap`)

Run once per project after the installer. Interviews you and generates all project-specific config.

```
Use the project-bootstrap agent to set up this project
```

Generates:
- `CLAUDE.md`
- `.mcp.json`
- `.claude/settings.json` updates (PostToolUse lint hook for Node.js)
- `.claude/rules/dev-reference.md` (always — auto-loaded every session)
- `.claude/rules/design-system.md` (frontend projects)
- `.claude/rules/database.md` (database projects)
- `.claude/agents/general-assistant.md`
- `.claude/agents/database-specialist.md` (if database selected)
- `.claude/agents/playwright-tester.md` (if Playwright selected)
- `.claude/agents/code-reviewer.md` (team/production projects)
- `.claude/agents/security-auditor.md` (team/production projects)

### 3. Slash Commands

| Command | What it does |
|---------|-------------|
| `/commit` | Lint, stage (no credentials), conventional commit |
| `/run-ci` | Iterate lint + tests until passing |
| `/whats-next` | Session handoff doc in `.claude/handoff-[date].md` |
| `/fix-pr` | Pull latest, address all PR review comments |
| `/summarize` | Session summary via summarize-chat agent |

## MCP Reference

```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase@latest", "--access-token", "${SUPABASE_ACCESS_TOKEN}"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github@latest"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    }
  }
}
```

Required env vars:
- `SUPABASE_ACCESS_TOKEN` — Supabase Settings > Access Tokens
- `GITHUB_TOKEN` — GitHub personal access token with `repo` scope

## Re-bootstrap Safety

Safe to re-run. The bootstrap agent detects existing `CLAUDE.md` and offers Update / Add Superpowers / Regenerate / Cancel. Never silently overwrites.

## Commit After Bootstrap

```bash
git add CLAUDE.md .mcp.json .claude/
git commit -m "chore: add Claude Code configuration"
```

## File Structure After Full Bootstrap

```
project/
  CLAUDE.md
  .mcp.json
  .claude/
    settings.json
    hooks/file-guard.js
    commands/commit.md
    commands/run-ci.md
    commands/whats-next.md
    commands/fix-pr.md
    commands/summarize.md
    rules/dev-reference.md
    rules/design-system.md     (frontend)
    rules/database.md          (database)
    agents/project-bootstrap.md
    agents/summarize-chat.md
    agents/general-assistant.md
    agents/database-specialist.md
    agents/playwright-tester.md
    agents/code-reviewer.md    (team)
    agents/security-auditor.md (team)
```

## Version History

| Version | Notes |
|---------|-------|
| 3.0.0 | Superpowers v5.1.0, hooks, commands, rules, MCP auto-config, examples |
| 1.0.0 | Initial release (archived at `archive/claude-bootstrap-v1.sh`) |
