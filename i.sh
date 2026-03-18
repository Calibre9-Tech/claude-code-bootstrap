#!/usr/bin/env bash
# =============================================================================
# Claude Code Bootstrap Installer v3.0.0
# Installs Superpowers plugin and sets up .claude/ skeleton for any project.
# Usage: bash claude-bootstrap-installer.sh
# =============================================================================

set -euo pipefail

SUPERPOWERS_VERSION="5.1.0"
CLAUDE_DIR=".claude"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { printf "${CYAN}[info]${RESET}  %s\n" "$*"; }
success() { printf "${GREEN}[ok]${RESET}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[warn]${RESET}  %s\n" "$*"; }
header()  { printf "\n${BOLD}%s${RESET}\n" "$*"; }

printf "${BOLD}${CYAN}"
printf " Claude Code Bootstrap Installer v3.0.0\n"
printf " Set up Claude Code for any project in under 60 seconds.\n"
printf "${RESET}\n"

info "Superpowers version: ${SUPERPOWERS_VERSION}"
info "Target: $(pwd)"
echo ""

# ── Preflight ─────────────────────────────────────────────────────────────────
header "Preflight checks"

if ! command -v claude &>/dev/null; then
  warn "claude CLI not found — install from https://claude.ai/code before running bootstrap agent"
fi
if ! command -v node &>/dev/null; then
  warn "node not found — required for file-guard.js hook (https://nodejs.org)"
fi

# ── Step 1: Superpowers plugin ────────────────────────────────────────────────
header "Step 1 — Installing Superpowers plugin v${SUPERPOWERS_VERSION}"

if command -v claude &>/dev/null; then
  if claude plugin list 2>/dev/null | grep -q "superpowers-extended-cc"; then
    success "Superpowers already installed"
  else
    info "Adding marketplace..."
    claude plugin marketplace add pcvelz/superpowers 2>&1 | grep -E "Successfully|Error" || true
    info "Installing plugin..."
    if claude plugin install "superpowers-extended-cc@superpowers-extended-cc-marketplace" --scope user 2>&1 | grep -q "Successfully"; then
      success "Superpowers installed (restart Claude Code to activate)"
    else
      warn "Could not auto-install. Run manually:"
      warn "  claude plugin marketplace add pcvelz/superpowers"
      warn "  claude plugin install superpowers-extended-cc@superpowers-extended-cc-marketplace --scope user"
    fi
  fi
else
  warn "Skipping (claude CLI not available). After installing Claude Code, run:"
  warn "  claude plugin marketplace add pcvelz/superpowers"
  warn "  claude plugin install superpowers-extended-cc@superpowers-extended-cc-marketplace --scope user"
fi

# ── Step 2: Directory skeleton ────────────────────────────────────────────────
header "Step 2 — Creating .claude/ skeleton"
mkdir -p "${CLAUDE_DIR}/agents"
mkdir -p "${CLAUDE_DIR}/commands"
mkdir -p "${CLAUDE_DIR}/hooks"
mkdir -p "${CLAUDE_DIR}/rules"
success "Directories created"

# ── Step 3: settings.json ─────────────────────────────────────────────────────
header "Step 3 — Writing .claude/settings.json"

if [[ -f "${CLAUDE_DIR}/settings.json" ]]; then
  warn "settings.json already exists — skipping (bootstrap agent will update it)"
else
  cat > "${CLAUDE_DIR}/settings.json" << 'SETTINGS_EOF'
{
  "permissions": {
    "deny": ["EnterPlanMode"]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/hooks/file-guard.js"
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
  success "settings.json written"
fi

# ── Step 4: file-guard.js ─────────────────────────────────────────────────────
header "Step 4 — Writing .claude/hooks/file-guard.js"

cat > "${CLAUDE_DIR}/hooks/file-guard.js" << 'FILEGUARD_EOF'
#!/usr/bin/env node
// file-guard.js — Blocks writes to .env* and credential files.
// Runs as a PreToolUse hook on every Write/Edit tool call.

const fs = require('fs');

let input = {};
try {
  input = JSON.parse(fs.readFileSync('/dev/stdin', 'utf8'));
} catch (e) {
  process.exit(0);
}

const filePath = input.file_path || input.path || '';
const filename = filePath.split('/').pop();

const blocked = [
  /^\.env$/,
  /^\.env\./,
  /^credentials\.json$/,
  /^service-account\.json$/,
  /\.pem$/,
  /\.key$/,
  /\.p12$/,
  /\.pfx$/,
  /^id_rsa$/,
  /^id_ed25519$/,
  /^id_dsa$/,
  /^id_ecdsa$/,
  /^\.netrc$/,
  /\.secret$/,
];

if (blocked.some(pattern => pattern.test(filename))) {
  process.stderr.write(
    `[file-guard] BLOCKED: Writing to '${filePath}' is not allowed.\n` +
    `Edit credential files manually in your terminal.\n`
  );
  process.exit(1);
}
FILEGUARD_EOF

success "file-guard.js written"

# ── Step 5: Slash commands ────────────────────────────────────────────────────
header "Step 5 — Writing slash commands"

cat > "${CLAUDE_DIR}/commands/commit.md" << 'COMMIT_EOF'
Run lint, stage changes, and create a conventional commit.

Steps:
1. Run the project lint command (npm run lint, ruff check ., etc.) — fix any errors before continuing
2. Stage changed files. Never stage: .env*, credentials.json, *.pem, *.key, id_rsa
3. Summarize what changed in 1-2 sentences
4. Create commit with format: `type(scope): description`
   Common types: feat, fix, refactor, test, chore, docs
5. Show the commit hash
COMMIT_EOF

cat > "${CLAUDE_DIR}/commands/run-ci.md" << 'RUNCI_EOF'
Run the full lint and test suite, iterating until everything passes.

Steps:
1. Run lint — fix all errors, re-run until output is clean
2. Run tests — fix all failures, re-run until all pass
3. Show final passing output
RUNCI_EOF

cat > "${CLAUDE_DIR}/commands/whats-next.md" << 'WHATSNEXT_EOF'
Generate a session handoff document.

Steps:
1. Review what was accomplished in this session
2. Identify all files changed and what changed in each
3. Draft a handoff doc with these sections:
   - **Session Summary** — what was built or fixed (2-4 sentences)
   - **Files Changed** — list with one-line description per file
   - **Current State** — what is working, broken, or partial
   - **What's Next** — prioritized remaining work
   - **Blockers / Decisions Needed** — anything requiring human judgment
4. Save to `.claude/handoff-[YYYY-MM-DD].md`
5. Confirm the file was saved
WHATSNEXT_EOF

cat > "${CLAUDE_DIR}/commands/fix-pr.md" << 'FIXPR_EOF'
Pull latest changes and address all PR review comments.

Steps:
1. `git fetch && git pull` — get latest
2. Read PR review comments via `gh pr view --comments` (if gh CLI available) or ask user to paste them
3. Group by severity: Critical → Major → Minor
4. Address every comment in order — show before/after for each change
5. Run lint and tests — fix any regressions
6. Commit: `fix: address PR review comments`
7. Show summary of all changes made
FIXPR_EOF

cat > "${CLAUDE_DIR}/commands/summarize.md" << 'SUMMARIZE_EOF'
Summarize this conversation using the summarize-chat agent.

Invoke the summarize-chat agent to produce a structured summary:
1. **Problem tackled** — the goal or issue at the start
2. **Approaches tried** — strategies attempted, including what didn't work
3. **Current state** — what is working and what is not
4. **What's next** — the single most important next action

Keep under 300 words. Format with clear headers.
SUMMARIZE_EOF

success "5 slash commands written"

# ── Step 6: project-bootstrap agent ──────────────────────────────────────────
header "Step 6 — Writing project-bootstrap agent"

cat > "${CLAUDE_DIR}/agents/project-bootstrap.md" << 'BOOTSTRAP_AGENT_EOF'
---
name: project-bootstrap
description: First-time project setup agent. Interviews you and generates CLAUDE.md, subagents, .mcp.json, rules files, and settings hooks. Safe to re-run — detects existing CLAUDE.md and offers update options.
tools: Read, Write, Edit, Grep, Glob, Bash
model: sonnet
permissionMode: acceptEdits
---

You are a project bootstrap specialist. Your job: interview the user, then generate a complete Claude Code configuration tailored to their project and powered by Superpowers.

## Re-bootstrap Safety

First, check if CLAUDE.md exists in the project root.

If it exists:
1. **Update** — add missing sections (Verification Gate, Token Efficiency, Superpowers workflow)
2. **Add Superpowers** — only insert the Superpowers workflow section
3. **Regenerate** — full re-interview, replace all generated files
4. **Cancel** — exit without changes

Never silently overwrite an existing CLAUDE.md.

## Interview

Ask all questions at once in a numbered list:

1. Project name?
2. What does it do and who uses it? (1-2 sentences)
3. Framework / language? (Next.js, React, Vue, Python/FastAPI, Python/Django, Node/Express, Ruby/Rails, Go, other)
4. Database? (Supabase, PostgreSQL, MySQL, MongoDB, Firebase/Firestore, SQLite, none, other)
5. UI library? (shadcn/ui, Tailwind CSS, Material UI, Bootstrap, Chakra UI, custom, none)
6. Testing? (agent-browser E2E, Jest/Vitest unit, pytest, Cypress, none)
7. Deployment? (Vercel, Netlify, AWS, Heroku, Docker, Railway, other, none)
8. AI integration? (OpenAI, Anthropic Claude, other, none)
9. Team size? (solo/prototype, small team, team/production)
10. GitHub repo URL? (or "none")
11. Lint command? (e.g. `npm run lint`, `ruff check .` — blank if unsure)
12. Test command? (e.g. `npm test`, `pytest` — blank if unsure)

## Stack Flags

After collecting answers, set these flags internally:

- IS_FRONTEND: Next.js, React, Vue, or Nuxt
- IS_NODEJS: Next.js, React, Vue, Nuxt, or Node/Express
- HAS_SUPABASE: Supabase selected
- HAS_POSTGRES: PostgreSQL (not Supabase)
- HAS_FIREBASE: Firebase/Firestore
- HAS_MONGO: MongoDB
- HAS_DATABASE: any database
- HAS_AGENT_BROWSER: agent-browser E2E selected
- HAS_GITHUB: GitHub URL provided
- IS_TEAM: small team or team/production
- IS_PRODUCTION: team/production

## Generation Steps

Run all steps after the interview. Show a progress line for each.

---

### Step A — .mcp.json

Create `.mcp.json` in the project root (merge if exists).

Build mcpServers based on flags:
- HAS_SUPABASE → `"supabase"`: command `npx`, args `["-y", "@supabase/mcp-server-supabase@latest", "--access-token", "${SUPABASE_ACCESS_TOKEN}"]`
- HAS_GITHUB → `"github"`: command `npx`, args `["-y", "@modelcontextprotocol/server-github@latest"]`, env `{"GITHUB_TOKEN": "${GITHUB_TOKEN}"}`
- HAS_DATABASE and NOT HAS_SUPABASE → `"filesystem"`: command `npx`, args `["-y", "@modelcontextprotocol/server-filesystem@latest", "."]`

Note: HAS_AGENT_BROWSER does NOT add an MCP server. agent-browser is a CLI tool used via Bash commands. If HAS_AGENT_BROWSER, add a note to the generated CLAUDE.md:
- Install agent-browser: `npm install -g agent-browser`
- Install Lightpanda (preferred engine): `curl -L -o lightpanda https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-aarch64-macos && chmod a+x ./lightpanda && mv ./lightpanda /usr/local/bin/lightpanda`
- Set default engine: add `{ "engine": "lightpanda" }` to `agent-browser.json`

If none apply: write `{ "mcpServers": {} }`.

---

### Step B — Lint hook

If lint command was provided (any framework — Node, Python, Go, etc.):

Read `.claude/settings.json`, add PostToolUse hook:

```json
"PostToolUse": [
  {
    "matcher": "Write|Edit|NotebookEdit",
    "hooks": [{ "type": "command", "command": "LINT_CMD 2>/dev/null || true" }]
  }
]
```

Replace LINT_CMD with the actual lint command. Use Edit to make a targeted update.

---

### Step C — Rules files

**Always generate** `.claude/rules/dev-reference.md`:

```markdown
---
description: Auto-loaded every session — Superpowers skills and slash commands quick reference
---
# Dev Reference

## Superpowers Workflow
New feature → brainstorming → writing-plans → executing-plans → verification-before-completion → requesting-code-review → finishing-a-development-branch

Specs: `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
Plans: `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`

## Skills
| Need | Skill |
|------|-------|
| New feature idea | /superpowers-extended-cc:brainstorming |
| Plan work | /superpowers-extended-cc:writing-plans |
| Execute plan | /superpowers-extended-cc:executing-plans |
| Write tests first | /superpowers-extended-cc:test-driven-development |
| Debug systematically | /superpowers-extended-cc:systematic-debugging |
| Verify before claiming done | /superpowers-extended-cc:verification-before-completion |
| Isolate work on a branch | /superpowers-extended-cc:using-git-worktrees |
| Run parallel agents | /superpowers-extended-cc:dispatching-parallel-agents |
| Request code review | /superpowers-extended-cc:requesting-code-review |
| Ship / clean up branch | /superpowers-extended-cc:finishing-a-development-branch |

## Commands
- /commit — lint, stage, conventional commit
- /run-ci — iterate lint + tests until clean
- /whats-next — session handoff doc
- /fix-pr — pull and fix PR review comments
- /summarize — summarize current session

## Note: EnterPlanMode is disabled
`EnterPlanMode` is blocked in `.claude/settings.json`. Use Superpowers skills instead:
- Planning → `/superpowers-extended-cc:writing-plans` (saves to `docs/superpowers/plans/`)
- Execution → `/superpowers-extended-cc:executing-plans`
These provide the same structure with file-backed plans and review checkpoints.
```

**If IS_FRONTEND**, generate `.claude/rules/design-system.md`:

```markdown
---
description: Design system constraints — loaded when editing UI components
globs: components/**,app/**,src/**,pages/**
---
# Design System

## UI Library
[PROJECT_UI_LIBRARY]

## Color Tokens
<!-- Fill in: primary, secondary, accent, background, foreground -->

## Typography
<!-- Fill in: font families, size scale, heading weights -->

## Spacing
<!-- Fill in: spacing scale, padding conventions -->

## Component Conventions
- All new components go in `components/`
- Use existing primitives before creating new ones
- PascalCase components, kebab-case filenames
- All interactive elements must have accessible labels
```

**If HAS_DATABASE**, generate `.claude/rules/database.md`:

```markdown
---
description: Database schema conventions — loaded when editing DB files
globs: **/migrations/**,**/schema*,**/models/**,prisma/**,supabase/**,**/seeds/**
---
# Database Rules

## Database
[PROJECT_DATABASE]

## Schema Conventions
- Table names: snake_case, plural
- Column names: snake_case
- Primary keys: `id` (uuid preferred)
- Timestamps: `created_at`, `updated_at` on every table

## Migration Rules
- Never drop columns in one step — deprecate, migrate data, remove in follow-up PR
- All migrations must be reversible

## Query Conventions
- Always use parameterized queries — never string interpolation
- Prefer indexed columns in WHERE clauses
- Use EXPLAIN ANALYZE for queries touching more than 10k rows

## Row-Level Security
- Every user-facing table must have RLS enabled
- Default deny — grant explicitly
- Test RLS policies before marking a feature complete
```

---

### Step D — Subagents

Create in `.claude/agents/`. Do not overwrite existing files unless user chose Regenerate.

**Always create: `general-assistant.md`**

```markdown
---
name: general-assistant
description: General-purpose development assistant for [PROJECT_NAME]. Code editing, refactoring, debugging, and tasks not covered by specialists.
tools: Read, Write, Edit, Grep, Glob, Bash
model: sonnet
---

You are a general-purpose development assistant for [PROJECT_NAME].

## Project
[DESCRIPTION]

## Stack
[STACK_FROM_INTERVIEW]

## Responsibilities
- Code editing, refactoring, implementation
- Debugging and root-cause analysis
- File operations and project navigation

## Delegate To
[Only include lines for agents that were actually created in this project]
- Database operations → database-specialist  [include if HAS_DATABASE]
- E2E browser testing → browser-tester  [include if HAS_AGENT_BROWSER]
- Code review → code-reviewer  [include if IS_TEAM]
- Security audit → security-auditor  [include if IS_TEAM]
```

**If HAS_SUPABASE, create `database-specialist.md`**

```markdown
---
name: database-specialist
description: Supabase expert for [PROJECT_NAME]. Schema changes, migrations, RLS policies, Edge Functions.
tools: Read, Write, Edit, Grep, Glob, Bash, mcp__supabase__*
model: sonnet
---

You are a Supabase database specialist for [PROJECT_NAME].

## Critical Rules
- Use `information_schema.columns` for schema queries — never `list_tables` (14k tokens)
- Always check existing RLS policies before adding a new table
- Run `supabase db diff` before applying migrations

## Migration Workflow
1. `supabase db diff -f migration_name`
2. Review the SQL carefully
3. `supabase db push` — apply locally
4. Test end-to-end
5. Commit the migration file
```

**If HAS_POSTGRES, create `database-specialist.md`**

```markdown
---
name: database-specialist
description: PostgreSQL expert for [PROJECT_NAME]. Schema, migrations, query optimization.
tools: Read, Write, Edit, Grep, Glob, Bash
model: sonnet
---

You are a PostgreSQL specialist for [PROJECT_NAME].

## Critical Rules
- Always use parameterized queries
- Check `pg_stat_user_tables` for bloat before heavy migrations
- Use `EXPLAIN ANALYZE` on queries touching more than 10k rows
```

**If HAS_FIREBASE, create `database-specialist.md`**

```markdown
---
name: database-specialist
description: Firebase/Firestore expert for [PROJECT_NAME]. Data modeling, security rules, Authentication.
tools: Read, Write, Edit, Grep, Glob, Bash
model: sonnet
---

You are a Firebase/Firestore specialist for [PROJECT_NAME].

## Critical Rules
- Always test security rules with Firebase Emulator before deploying
- Denormalize intentionally — document the reason in a comment
- Never expose service account keys in client-side code
```

**If HAS_MONGO, create `database-specialist.md`**

```markdown
---
name: database-specialist
description: MongoDB expert for [PROJECT_NAME]. Schema design, aggregation pipelines, indexing.
tools: Read, Write, Edit, Grep, Glob, Bash
model: sonnet
---

You are a MongoDB specialist for [PROJECT_NAME].

## Critical Rules
- Always validate with a schema (Mongoose, Zod, or JSON Schema)
- Add indexes before queries go to production
- Never store sensitive data in plaintext
```

**If HAS_AGENT_BROWSER, create `browser-tester.md`**

```markdown
---
name: browser-tester
description: E2E browser testing specialist for [PROJECT_NAME] using agent-browser + Lightpanda (https://agent-browser.dev). Automates browsers via CLI — no MCP required. Prefers Lightpanda for speed; falls back to Chrome.
tools: Read, Write, Edit, Grep, Glob, Bash
model: sonnet
---

You are a browser testing specialist for [PROJECT_NAME], using agent-browser (https://agent-browser.dev) with Lightpanda as the preferred engine.

## Engine: Lightpanda (preferred)

[Lightpanda](https://lightpanda.io) is a headless browser built in Zig — starts instantly, 10x less memory than Chrome, 10x faster. Use it by default for all agent-browser commands.

```bash
# Preferred — Lightpanda engine
agent-browser --engine lightpanda open <url>
agent-browser --engine lightpanda snapshot -i
agent-browser --engine lightpanda click @e2

# Or set once in agent-browser.json (project root):
# { "engine": "lightpanda" }
```

Install Lightpanda (macOS Apple Silicon):
```bash
curl -L -o lightpanda https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-aarch64-macos && chmod a+x ./lightpanda && mv ./lightpanda /usr/local/bin/lightpanda
```

Linux (x86_64):
```bash
curl -L -o lightpanda https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-x86_64-linux && chmod a+x ./lightpanda && mv ./lightpanda /usr/local/bin/lightpanda
```

## Lightpanda Limitations — Fall Back to Chrome

Lightpanda does NOT support: extensions, persistent profiles (`--profile`), storage state (`--state`), file access, headed mode, screenshots (CDP support varies).

When these are needed, drop `--engine lightpanda`:
```bash
agent-browser open <url>          # Chrome (default without flag)
agent-browser screenshot page.png # Use Chrome for screenshots
```

## Core Commands

```bash
agent-browser --engine lightpanda open <url>   # Navigate
agent-browser --engine lightpanda snapshot -i  # Accessibility tree with @ref IDs
agent-browser --engine lightpanda click @e2    # Click by ref
agent-browser --engine lightpanda type @e3 "text"  # Type into element
agent-browser close                            # Close session
agent-browser screenshot page.png             # Screenshot (Chrome only)
```

## Token Optimization (Critical)
- `snapshot -i` outputs ~200-400 tokens — never dump raw DOM (~3k-5k tokens)
- Use ref IDs (`@e1`, `@e2`) — deterministic, no re-querying
- For visual checks, fall back to Chrome + `screenshot` (~400 tokens)

## Test Authoring
- Write tests as Bash scripts using agent-browser CLI commands
- Use `data-testid` attributes in source for reliable ref matching
- Name test scripts: `tests/e2e/feature-name.sh`
- Default to Lightpanda; add Chrome fallback only for screenshot steps

## Debugging Failures
1. `agent-browser screenshot fail.png` (Chrome) — capture state at failure
2. `agent-browser --engine lightpanda snapshot -i` — inspect page elements
3. Re-check the ref ID — snapshots are fresh per page load
4. If a command errors with Lightpanda, retry without `--engine lightpanda` to isolate
```

**If IS_TEAM, create `code-reviewer.md`**

```markdown
---
name: code-reviewer
description: Reviews code against the plan and coding standards. Tags issues as Critical/Major/Minor with file:line references. Use before merging any PR.
tools: Read, Grep, Glob
model: sonnet
---

You are a code reviewer. Review changes systematically.

## Process
1. Read the plan, PR description, or ask what the change is supposed to do
2. Identify all changed files
3. Review each file against the stated goal

## Severity Tags
- **Critical**: bugs, security issues, broken functionality — block merge
- **Major**: performance issues, missing tests, poor design — request changes
- **Minor**: style, naming, minor improvements — suggestions only

## Output Format
`[SEVERITY] path/to/file.ts:42 — Description and why it matters`

End with: Critical: N, Major: N, Minor: N, Verdict: APPROVE / REQUEST CHANGES / BLOCK

## Checklist
- [ ] Logic matches stated goal
- [ ] Edge cases handled
- [ ] Tests cover the change
- [ ] No obvious security issues
- [ ] No unintended side effects
```

**If IS_TEAM, create `security-auditor.md`**

```markdown
---
name: security-auditor
description: Audits code for OWASP Top 10, RLS bypass, JWT validation, injection. Use before shipping auth, payment, or data-handling features.
tools: Read, Grep, Glob
model: sonnet
---

You are a security auditor. Check for vulnerabilities methodically.

## OWASP Top 10
1. Injection — SQL, command, LDAP via unsanitized input
2. Broken Authentication — weak sessions, missing MFA
3. Sensitive Data Exposure — secrets in logs, plaintext storage
4. XML External Entities — if XML parsing involved
5. Broken Access Control — RLS bypass, missing auth checks, IDOR
6. Security Misconfiguration — default credentials, verbose errors in production
7. XSS — unsanitized output, dangerouslySetInnerHTML
8. Insecure Deserialization
9. Known Vulnerable Components — check npm audit / pip-audit
10. Insufficient Logging — missing audit trail for sensitive operations

## Output Format
`[CRITICAL|HIGH|MEDIUM|LOW] path/to/file.ts:42 — Vulnerability + remediation`

## Always Check
- Every API route has auth and authorization
- User input validated and sanitized
- RLS on every user-facing table
- No secrets in source code
- JWT validation includes signature verification (not just decode)
```

---

### Step E — CLAUDE.md

Generate a complete `CLAUDE.md` in the project root. Use real data from the interview — no placeholders.

Required sections in this order:

1. `# PROJECT_NAME — Claude Configuration`
2. Byline: `> Auto-generated by project-bootstrap on DATE. Edit this file to keep it current.`
3. **Repository** — repo URL, main branch, lint command, test command
4. **Project Overview** — description and full stack list
5. **Superpowers Workflow** — copy the table below exactly
6. **Subagents** — table of every agent generated (use `browser-tester` not `playwright-tester`)
7. **Slash Commands** — table of all 5 commands
8. **Verification Gate** — copy the section below exactly
9. **Tool Priority (Token Efficiency)** — copy the section below exactly
10. **Development Workflow** — numbered steps customized for their project

Superpowers Workflow section (copy verbatim, fill in project-specific path examples):

```
## Superpowers Workflow

New feature → brainstorming → writing-plans → executing-plans → verification-before-completion → requesting-code-review → finishing-a-development-branch

Specs: `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
Plans: `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`

| Need | Skill |
|------|-------|
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
```

Verification Gate section (copy verbatim):

```
## Verification Gate

**Iron Law: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE**

Before claiming any task is done, fixed, or passing:
1. IDENTIFY what command proves the claim
2. RUN it (fresh and complete — not a previous run)
3. READ the full output and check exit code
4. VERIFY output actually confirms the claim
5. ONLY THEN make the claim, and include the output

| Claim | Required evidence |
|-------|-----------------|
| Tests pass | Test command output: 0 failures |
| Linter clean | Linter output: 0 errors |
| Build succeeds | Build command: exit 0 |
| Bug fixed | Test reproducing original bug: passes |
| Feature complete | Each requirement verified line by line |
| Deployment live | Git hash + CI status confirmed |

Banned phrases without fresh evidence: "should work", "try it now", "looks correct", "should be fixed".
```

Tool Priority section (copy verbatim):

```
## Tool Priority (Token Efficiency)

| Task | Preferred | Avoid |
|------|-----------|-------|
| Read file | `Read` tool | `Bash cat` |
| Search content | `Grep` tool | `Bash grep/rg` |
| Find files | `Glob` tool | `Bash find/ls` |
| DB schema | Targeted `information_schema` query | `list_tables` (14k tokens) |
| Browser state | `agent-browser --engine lightpanda snapshot -i` (~200-400 tokens) | Raw DOM dumps (~3k-5k tokens) |

agent-browser: prefer `--engine lightpanda` (10x faster, 10x less memory). Use Chrome fallback for screenshots and when Lightpanda limitations apply (no extensions/profiles/storage state).
```

---

### Step F — Summary

Print a clear summary listing every file created and the commit command:

```
git add CLAUDE.md .mcp.json .claude/
git commit -m "chore: add Claude Code + Superpowers configuration"
```

BOOTSTRAP_AGENT_EOF
success "project-bootstrap agent written"

# ── Step 7: summarize-chat agent ──────────────────────────────────────────────
header "Step 7 — Writing summarize-chat agent"

cat > "${CLAUDE_DIR}/agents/summarize-chat.md" << 'SUMMARIZE_AGENT_EOF'
---
name: summarize-chat
description: Summarizes the current Claude Code session. Use via /summarize command.
tools: Read, Glob
model: haiku
---

You are a session summarizer. Produce a concise, structured summary of the current conversation.

## Output Format

### Problem Tackled
What was the user trying to accomplish? 1-3 sentences.

### Approaches Tried
Bullet list of strategies attempted, including what didn't work and why.

### Current State
What is working? What is broken or incomplete?

### What's Next
The single most important next action, then any secondary items.

## Rules
- Under 300 words
- Specific: mention actual file names, function names, error messages
- Past tense for what was done, present tense for current state
SUMMARIZE_AGENT_EOF
success "summarize-chat agent written"

# ── Step 8: Done ──────────────────────────────────────────────────────────────
header "Installation complete"
echo ""
printf "${BOLD}Files created:${RESET}\n"
printf "  ${GREEN}+${RESET} .claude/settings.json\n"
printf "  ${GREEN}+${RESET} .claude/hooks/file-guard.js\n"
printf "  ${GREEN}+${RESET} .claude/commands/commit.md\n"
printf "  ${GREEN}+${RESET} .claude/commands/run-ci.md\n"
printf "  ${GREEN}+${RESET} .claude/commands/whats-next.md\n"
printf "  ${GREEN}+${RESET} .claude/commands/fix-pr.md\n"
printf "  ${GREEN}+${RESET} .claude/commands/summarize.md\n"
printf "  ${GREEN}+${RESET} .claude/agents/project-bootstrap.md\n"
printf "  ${GREEN}+${RESET} .claude/agents/summarize-chat.md\n"
echo ""
printf "${BOLD}Superpowers plugin:${RESET} v${SUPERPOWERS_VERSION}\n"
echo ""
printf "${BOLD}Next steps:${RESET}\n"
echo ""
printf "  ${BOLD}1. Make sure you're in your project directory${RESET}\n"
printf "     Run: ${CYAN}pwd${RESET} to confirm you're in the right place\n"
printf "     If not, ${CYAN}cd /path/to/your/project${RESET} then re-run this installer\n"
echo ""
printf "  ${BOLD}2. Make sure Claude Code is installed${RESET}\n"
printf "     Run: ${CYAN}claude --version${RESET}\n"
printf "     If not installed: ${CYAN}https://claude.ai/code${RESET}\n"
echo ""
printf "  ${BOLD}3. Open Claude Code in this project${RESET}\n"
printf "     Run: ${CYAN}claude${RESET}\n"
echo ""
printf "  ${BOLD}4. Say this to the agent:${RESET}\n"
printf "     ${CYAN}Use the project-bootstrap agent to set up this project${RESET}\n"
echo ""
printf "  ${BOLD}5. Answer 12 questions, then commit:${RESET}\n"
printf "     ${CYAN}git add CLAUDE.md .mcp.json .claude/ && git commit -m \"chore: add Claude Code configuration\"${RESET}\n"
echo ""
