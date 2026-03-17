# Bootstrap Reference Docs

Reference documentation for the Claude Code Bootstrap system v2.0.0.

## Files in This Directory

| File | Purpose |
|------|---------|
| `TEMPLATE-CLAUDE.md` | Master template showing every section a generated `CLAUDE.md` can contain |

## How the Bootstrap System Works

### 1. Installer (`claude-bootstrap-installer.sh`)

Run once per project. Creates the `.claude/` skeleton and installs the Superpowers plugin.

```bash
bash claude-bootstrap-installer.sh
```

Creates:
- `.claude/settings.json` -- PreToolUse hook blocks writes to credential files
- `.claude/hooks/file-guard.js` -- Node.js hook that enforces the credential block
- `.claude/commands/` -- 5 slash commands (commit, run-ci, whats-next, fix-pr, summarize)
- `.claude/agents/project-bootstrap.md` -- the bootstrap agent
- `.claude/agents/summarize-chat.md` -- session summarizer

### 2. Bootstrap Agent (`project-bootstrap`)

Run once per project after the installer. Interviews you and generates all project-specific config.

Invoke it in Claude Code:

```
Use the project-bootstrap agent to set up this project
```

The agent generates:
- `CLAUDE.md` (project root)
- `.mcp.json` (project root)
- `.claude/settings.json` updates (PostToolUse lint hook for Node.js projects)
- `.claude/rules/dev-reference.md` (always -- auto-loaded every session)
- `.claude/rules/design-system.md` (frontend projects)
- `.claude/rules/database.md` (database projects)
- `.claude/agents/general-assistant.md` (always)
- `.claude/agents/database-specialist.md` (if database selected)
- `.claude/agents/playwright-tester.md` (if Playwright selected)
- `.claude/agents/code-reviewer.md` (team/production projects)
- `.claude/agents/security-auditor.md` (team/production projects)

### 3. Slash Commands

| Command | What it does |
|---------|-------------|
| `/commit` | Runs lint, stages files (not credentials), creates a conventional commit |
| `/run-ci` | Iterates lint + tests until everything passes |
| `/whats-next` | Generates a session handoff document in `.claude/handoff-[date].md` |
| `/fix-pr` | Pulls latest and addresses all PR review comments in order |
| `/summarize` | Summarizes the current session via the summarize-chat agent |

## MCP Servers Reference

The bootstrap agent configures `.mcp.json` based on your stack:

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
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem@latest", "."]
    }
  }
}
```

Required environment variables:
- `SUPABASE_ACCESS_TOKEN` -- Supabase personal access token (Settings > Access Tokens)
- `GITHUB_TOKEN` -- GitHub personal access token with `repo` scope

## Re-bootstrap Safety

Safe to re-run at any time. The bootstrap agent will detect an existing `CLAUDE.md` and offer:

1. **Update** -- add missing sections (Verification Gate, Token Efficiency, new agents)
2. **Add Superpowers** -- only insert the Superpowers workflow section
3. **Regenerate** -- full re-interview and replace all generated files
4. **Cancel** -- exit without any changes

Your existing setup is never silently overwritten.

## Committing Generated Files

After the bootstrap agent runs, commit everything:

```bash
git add CLAUDE.md .mcp.json .claude/
git commit -m "chore: add Claude Code configuration"
```

Teammates who clone the repo will get the same configuration automatically when they open Claude Code.

## File Structure After Full Bootstrap

```
your-project/
  CLAUDE.md
  .mcp.json
  .claude/
    settings.json
    hooks/
      file-guard.js
    commands/
      commit.md
      run-ci.md
      whats-next.md
      fix-pr.md
      summarize.md
    rules/
      dev-reference.md       (always)
      design-system.md       (frontend projects)
      database.md            (database projects)
    agents/
      project-bootstrap.md
      summarize-chat.md
      general-assistant.md
      database-specialist.md (if database)
      playwright-tester.md   (if Playwright)
      code-reviewer.md       (team projects)
      security-auditor.md    (team/production)
```

## Customizing Generated Files

The bootstrap agent produces a starting point -- customize freely:

- Edit `CLAUDE.md` to add project-specific conventions, architecture notes, and workflows
- Edit agent files in `.claude/agents/` to tune specialist instructions
- Edit rules files in `.claude/rules/` to fill in design tokens and DB conventions
- Add new slash commands in `.claude/commands/` as markdown files

## Version History

| Version | Installer | Notes |
|---------|-----------|-------|
| 2.0.0 | `claude-bootstrap-installer.sh` | Superpowers v5.1.0, hooks, commands, rules, MCP auto-config |
| 1.0.0 | `archive/claude-bootstrap-v1.sh` | Initial release |
