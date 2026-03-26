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
if command -v codex &>/dev/null; then
  success "Codex CLI detected — cross-model review will be available during setup"
else
  info "Codex CLI not found — cross-model review option will be skipped (install: npm i -g @openai/codex)"
fi
if command -v gemini &>/dev/null; then
  success "Gemini CLI detected — full review mode (Codex + Gemini) will be available"
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

## Auto-Detection

Before asking anything, scan the project to pre-fill as many answers as possible.

Check these files (read them if they exist):
- `package.json` → project name, framework, dependencies, scripts (lint, test)
- `requirements.txt`, `pyproject.toml`, `setup.py` → Python framework, test runner
- `go.mod` → Go project
- `Gemfile` → Ruby/Rails
- `.env`, `.env.example`, `.env.local` → database URLs, API keys (Supabase, OpenAI, etc.)
- `docker-compose.yml`, `docker-compose.yaml` → database, deployment
- `vercel.json`, `netlify.toml`, `.railway.json` → deployment platform
- `Dockerfile` → deployment
- `supabase/` directory → Supabase
- `prisma/schema.prisma` → database type
- `jest.config.js`, `vitest.config.ts` → test runner
- `playwright.config.ts` → note: use agent-browser instead
- `pytest.ini`, `pyproject.toml [tool.pytest]` → pytest
- `.github/` directory → GitHub repo (check remote URL via `git remote get-url origin`)
- `README.md` → project description
- `codex --version` (via Bash) → Codex CLI installed (enables cross-model review option)
- `gemini --version` (via Bash) → Gemini CLI installed (enables full review mode)

After scanning, show the user what you detected in a clear summary:

```
I found the following about your project:
✅ Project name: my-app
✅ Framework: Next.js (TypeScript)
✅ Database: Supabase (found SUPABASE_URL in .env)
✅ UI: shadcn/ui + Tailwind CSS
✅ Testing: Vitest (found vitest.config.ts)
✅ Deployment: Vercel (found vercel.json)
✅ Lint command: npm run lint
✅ Test command: npm test
✅ GitHub: https://github.com/org/repo
❓ What does this project do and who uses it?
❓ AI integration? (OpenAI, Anthropic Claude, other, none)
❓ Cross-model review? (Codex reviews your plans and code — codex CLI detected)
❓ Team size? (solo/prototype, small team, team/production)
```

Then ask ONLY the questions you couldn't answer. If you detected everything, just confirm with the user before proceeding.

## Interview

Only ask questions that auto-detection could not answer:

1. Project name? *(skip if detected)*
2. What does it do and who uses it? (1-2 sentences) *(always ask — can't be detected)*
3. Framework / language? *(skip if detected)*
4. Database? *(skip if detected)*
5. UI library? *(skip if detected)*
6. Testing? *(skip if detected)*
7. Deployment? *(skip if detected)*
8. AI integration? *(skip if detected)*
9. Team size? — default to `solo/prototype` unless user specifies otherwise *(skip — default used)*
10. GitHub repo URL? *(skip if detected from git remote)*
11. Lint command? *(skip if detected from package.json scripts)*
12. Test command? *(skip if detected from package.json scripts)*
13. Cross-model review? *(skip if codex CLI not installed)* — Codex (and optionally Gemini) review your plans and implementation. Options: yes (Codex only), yes (Codex + Gemini), no. Default: no. Authentication uses OAuth only — no API keys are stored or generated.

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
- HAS_CROSS_MODEL_REVIEW: user opted in and codex CLI is installed
- HAS_GEMINI_REVIEW: user opted in to Gemini as second reviewer

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
[If HAS_CROSS_MODEL_REVIEW, also include:]
- /build — plan → Codex review → implement → verify → Codex review (cross-model workflow)

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
- Cross-model build workflow → use /build command  [include if HAS_CROSS_MODEL_REVIEW]
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

### Step D.5 — Cross-Model Review (if HAS_CROSS_MODEL_REVIEW)

Create the `/build` workflow files. **Security: no API keys are written. Authentication relies on OAuth only.**

**Create `scripts/review.sh`** (make executable with `chmod +x`):

```bash
#!/usr/bin/env bash
# review.sh — Cross-model review abstraction
# Calls Codex/Gemini headless, parses fenced JSON verdicts, returns exit codes.
# Authentication: OAuth only (codex auth / gemini login). No API keys.
set -euo pipefail

CODEX_MODEL="\${CODEX_MODEL:-o4-mini}"
GEMINI_MODEL="\${GEMINI_MODEL:-gemini-2.5-flash}"
REVIEW_EFFORT="\${REVIEW_EFFORT:-high}"
REVIEW_TIMEOUT="\${REVIEW_TIMEOUT:-600}"
REVIEWER="\${1:-codex}"
REVIEW_TYPE="\${2:-plan}"
REVIEW_FILE="\${3:-}"
BRANCH="\${4:-\$(git branch --show-current)}"

REVIEWS_DIR="reviews/\${BRANCH}"
mkdir -p "\${REVIEWS_DIR}"

# ── Auth check ───────────────────────────────────────────────────────────────
check_auth() {
  local tool="\$1"
  if [[ "\$tool" == "codex" ]]; then
    if ! codex exec --ephemeral --sandbox read-only "echo ok" &>/dev/null; then
      echo "ERROR: Codex not authenticated. Run: codex auth" >&2
      exit 1
    fi
  elif [[ "\$tool" == "gemini" ]]; then
    if ! command -v gemini &>/dev/null; then
      echo "ERROR: Gemini CLI not installed. Run: npm i -g @google/gemini-cli" >&2
      exit 1
    fi
  fi
}

# ── Build diff/context ──────────────────────────────────────────────────────
get_review_context() {
  local base_ref
  base_ref=\$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo "HEAD~1")

  if [[ -n "\$REVIEW_FILE" && -f "\$REVIEW_FILE" ]]; then
    cat "\$REVIEW_FILE"
  else
    echo "## Git Diff"
    git diff "\${base_ref}...HEAD" 2>/dev/null || git diff HEAD~1
  fi
}

# ── Review prompt ────────────────────────────────────────────────────────────
build_prompt() {
  local review_type="\$1"
  local context
  context="\$(get_review_context)"

  cat <<PROMPT
You are a code reviewer. Review the following \${review_type}.

\${context}

Respond with your review, then end with a fenced JSON verdict block:

\\\`\\\`\\\`json
{
  "verdict": "APPROVE" or "REQUEST_CHANGES",
  "blocking": ["list of blocking issues"] or [],
  "suggestions": ["list of non-blocking suggestions"] or []
}
\\\`\\\`\\\`

Be thorough but concise. Focus on correctness, security, and maintainability.
PROMPT
}

# ── Run single reviewer ─────────────────────────────────────────────────────
run_codex_review() {
  local prompt="\$1"
  local output_file="\$2"

  check_auth codex
  timeout "\${REVIEW_TIMEOUT}" codex exec \\
    --ephemeral \\
    --sandbox read-only \\
    --model "\${CODEX_MODEL}" \\
    --reasoning-effort "\${REVIEW_EFFORT}" \\
    "\${prompt}" > "\${output_file}" 2>&1 || {
      echo "Codex review timed out or failed" >> "\${output_file}"
      return 1
    }
}

run_gemini_review() {
  local prompt="\$1"
  local output_file="\$2"

  check_auth gemini
  timeout "\${REVIEW_TIMEOUT}" gemini -p "\${prompt}" \\
    --model "\${GEMINI_MODEL}" > "\${output_file}" 2>&1 || {
      echo "Gemini review timed out or failed" >> "\${output_file}"
      return 1
    }
}

# ── Parse verdict ────────────────────────────────────────────────────────────
parse_verdict() {
  local review_file="\$1"
  local verdict_file="\${review_file}.verdict.json"

  local json_block
  json_block=\$(sed -n '/^\`\`\`json/,/^\`\`\`/p' "\$review_file" | sed '1d;\$d')

  if [[ -z "\$json_block" ]]; then
    echo '{"verdict":"UNKNOWN","blocking":["reviewer did not produce a parseable verdict"],"suggestions":[]}' > "\$verdict_file"
    return 1
  fi

  echo "\$json_block" > "\$verdict_file"

  local verdict
  verdict=\$(echo "\$json_block" | jq -r '.verdict // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")

  if [[ "\$verdict" == "APPROVE" ]]; then
    return 0
  else
    return 1
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
round="\${5:-1}"
output_file="\${REVIEWS_DIR}/\${REVIEW_TYPE}-review-round-\${round}.md"
prompt="\$(build_prompt "\${REVIEW_TYPE}")"

case "\$REVIEWER" in
  codex)
    run_codex_review "\$prompt" "\$output_file"
    ;;
  gemini)
    run_gemini_review "\$prompt" "\$output_file"
    ;;
  codex,gemini|both)
    codex_file="\${output_file%.md}-codex.md"
    gemini_file="\${output_file%.md}-gemini.md"
    run_codex_review "\$prompt" "\$codex_file" &
    codex_pid=\$!
    run_gemini_review "\$prompt" "\$gemini_file" &
    gemini_pid=\$!
    wait "\$codex_pid" || true
    wait "\$gemini_pid" || true
    echo "# Codex Review" > "\$output_file"
    cat "\$codex_file" >> "\$output_file"
    echo -e "\\n# Gemini Review" >> "\$output_file"
    cat "\$gemini_file" >> "\$output_file"
    ;;
  *)
    echo "Unknown reviewer: \$REVIEWER" >&2
    exit 1
    ;;
esac

parse_verdict "\$output_file"
exit_code=\$?

echo "Review saved: \${output_file}"
echo "Verdict: \$(jq -r '.verdict' "\${output_file}.verdict.json" 2>/dev/null || echo 'UNKNOWN')"

exit \$exit_code
```

**Create `.claude/commands/build.md`**:

```markdown
Run the cross-model build workflow: PLAN → REVIEW → IMPLEMENT → VERIFY → REVIEW → DONE

## Arguments
- `\$ARGUMENTS` — the task description
- `--mode` — workflow mode (default: plan_review)
  - `plan_review` — Claude plans → Codex reviews → Claude implements → Codex reviews
  - `full_review` — same but Codex + Gemini review in parallel
  - `just_plan` — Claude plans, no external review
- `--reviewer` — override reviewer (codex, gemini, codex,gemini)

## State Machine

States: PLAN → PLAN_REVIEW → IMPLEMENT → VERIFY → IMPL_REVIEW → DONE/NEEDS_HUMAN_REVIEW

Loop limits: 2 plan review rounds, 2 impl review rounds, 2 fix cycles max.

## Steps

### 1. Parse mode
Detect mode from flags or natural language:
- "plan this out" → plan_review (default)
- "full review" / "with gemini" → full_review
- "just plan" / "skip review" → just_plan

### 2. PLAN
Write a detailed implementation plan to `docs/superpowers/plans/YYYY-MM-DD-<topic>.md`.
Include: goal, approach, files to change, risks, test strategy.

### 3. PLAN_REVIEW (skip if just_plan)
Create a checkpoint commit: `chore: review checkpoint (auto)`
Run: `bash scripts/review.sh REVIEWER plan docs/superpowers/plans/YYYY-MM-DD-<topic>.md BRANCH ROUND`
- REVIEWER = codex (plan_review) or codex,gemini (full_review)
- If APPROVE → proceed to IMPLEMENT
- If REQUEST_CHANGES → read blocking issues, revise plan, re-review (max 2 rounds)
- If 2 rounds exhausted → proceed with warnings noted

### 4. IMPLEMENT
Execute the plan. Write code, tests, documentation as specified.
Create checkpoint commit after implementation.

### 5. VERIFY
Run lint and test commands. Fix failures (max 3 retries).
If still failing after 3 retries → BLOCKED state. Preserve state for resume.

### 6. IMPL_REVIEW (skip if just_plan)
Create checkpoint commit.
Run: `bash scripts/review.sh REVIEWER implementation "" BRANCH ROUND`
- If APPROVE → DONE
- If REQUEST_CHANGES → read blocking issues, fix, re-verify, re-review (max 2 rounds)
- If fix_cycle > 2 → NEEDS_HUMAN_REVIEW

### 7. Terminal States
- **DONE** — all reviews passed. Suggest: squash checkpoint commits, create PR.
- **NEEDS_HUMAN_REVIEW** — unresolved blocking findings. Review artifacts preserved in `reviews/`.
- **BLOCKED** — tests/lint won't pass. State preserved for resume.

## Important
- Never store or reference API keys — reviewers authenticate via OAuth
- Checkpoint commits should be squashed before merging
- Review artifacts are committed to `reviews/<branch>/`
```

**Create directories and gitignore entries:**
```bash
mkdir -p reviews
touch reviews/.gitkeep
grep -q '.claude/local/' .gitignore 2>/dev/null || echo '.claude/local/' >> .gitignore
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
9. **Recency Check** — copy the section below exactly
10. **Tool Priority (Token Efficiency)** — copy the section below exactly
11. **Development Workflow** — numbered steps customized for their project
12. **Cross-Model Review** *(only if HAS_CROSS_MODEL_REVIEW)* — copy the section below

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

Recency Check section (copy verbatim):

```
## Recency Check

When recommending anything that moves fast — AI models, SDK versions, CLI tools, library versions, cloud service features — **do not trust training data**. Spin up an Explore agent or use WebSearch to verify you are recommending the current latest version before writing it into code or docs.

Fast-moving areas that always need a live check:
- AI model IDs (Claude, GPT, Gemini, etc.)
- npm/pip package versions
- Framework major versions (Next.js, React, etc.)
- CLI tool install commands
- API endpoints and authentication methods
- Pricing and rate limits

If you cannot verify, say so — "this was current as of my last update, verify before using" — rather than stating a stale version as fact.
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

Cross-Model Review section (include only if HAS_CROSS_MODEL_REVIEW — copy verbatim):

```
## Cross-Model Review

Claude plans and implements. Codex (and optionally Gemini) reviews. The `/build` command orchestrates the workflow.

### Usage
- `/build "add user authentication"` — default: Codex reviews plan and implementation
- `/build --mode full_review "add auth"` — Codex + Gemini review in parallel
- `/build --mode just_plan "add auth"` — plan only, no external review

### State Machine
PLAN → PLAN_REVIEW (max 2 rounds) → IMPLEMENT → VERIFY → IMPL_REVIEW (max 2 rounds) → DONE

### Terminal States
| State | Meaning |
|-------|---------|
| DONE | All reviews passed — squash checkpoint commits and create PR |
| NEEDS_HUMAN_REVIEW | Unresolved blocking findings after exhausting review budget |
| BLOCKED | Tests/lint won't pass after 3 retries |

### Authentication
Reviewers authenticate via OAuth — no API keys are stored or managed by this workflow.
- Codex: `codex auth` (one-time browser login)
- Gemini: `gemini` (one-time Google login)

### Review Artifacts
- `reviews/<branch>/plan-review-round-1.md` — full reviewer output
- `reviews/<branch>/plan-review-round-1.md.verdict.json` — structured verdict
```

---

### Step F — Summary

Print a clear summary listing every file created. If HAS_CROSS_MODEL_REVIEW, also list `scripts/review.sh`, `.claude/commands/build.md`, and `reviews/.gitkeep`.

Commit command:

```
git add CLAUDE.md .mcp.json .claude/ scripts/ reviews/
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
