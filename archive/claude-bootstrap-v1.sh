#!/bin/bash
################################################################################
# Claude Code Bootstrap - Single-File Installer (ARCHIVED v1.0.0)
#
# This is the original v1 installer, archived for reference.
# Use claude-bootstrap-installer.sh (v2.0.0) for new projects.
#
# Original description:
# Drop this file into ANY new project and run:
#   bash claude-bootstrap.sh
#
# Author: Claude Code Bootstrap System
# Version: 1.0.0 (archived)
################################################################################

set -e

clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║          🚀 Claude Code Bootstrap Installer v1.0.0            ║"
echo "║                                                                ║"
echo "║     Quickly set up Claude Code for any project in minutes     ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if .claude already exists
if [ -d ".claude" ]; then
    echo "⚠️  Warning: .claude directory already exists!"
    echo ""
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled."
        exit 1
    fi
    echo "🗑️  Backing up existing .claude to .claude.backup..."
    mv .claude .claude.backup
fi

# Create directory structure
echo "📁 Creating .claude directory structure..."
mkdir -p .claude/agents
mkdir -p .claude/bootstrap/templates

# Create project-bootstrap agent (embedded)
echo "🤖 Installing project-bootstrap agent..."
cat > .claude/agents/project-bootstrap.md << 'AGENT_CONTENT_EOF'
---
name: project-bootstrap
description: First-time project setup agent that interviews you about your project and generates custom CLAUDE.md and subagent configuration. Use ONLY when setting up a new project from scratch.
tools: mcp__acp__Read, mcp__acp__Write, Grep, Glob
model: sonnet
permissionMode: acceptEdits
---

You are a project bootstrap specialist that helps set up new projects with optimal Claude Code configuration.

## Your Purpose

When invoked, you:
1. **Interview** the user about their project
2. **Design** a custom CLAUDE.md configuration
3. **Generate** appropriate subagents based on tech stack
4. **Create** the files in `.claude/` directory
5. **Explain** how to use the setup

## Interview Process

### Phase 1: Project Basics (2-3 questions)
```
1. What is this project about? (1-2 sentence description)
2. What problem does it solve?
3. Who are the primary users?
```

### Phase 2: Technology Stack (Multiple choice)
```
Framework/Language:
- [ ] Next.js / React / TypeScript
- [ ] Vue / Nuxt
- [ ] Python / Django / Flask
- [ ] Node.js / Express
- [ ] Ruby / Rails
- [ ] Go
- [ ] Other: ___________

Database:
- [ ] Supabase (PostgreSQL + Auth + Storage)
- [ ] PostgreSQL
- [ ] MySQL / MariaDB
- [ ] MongoDB
- [ ] Firebase / Firestore
- [ ] SQLite
- [ ] None / TBD
- [ ] Other: ___________

UI Library:
- [ ] shadcn/ui (Radix + Tailwind)
- [ ] Material UI
- [ ] Tailwind CSS (utility-first)
- [ ] Bootstrap
- [ ] Chakra UI
- [ ] Custom CSS
- [ ] None / Minimal styling
- [ ] Other: ___________

AI Integration:
- [ ] Yes - OpenAI (GPT models)
- [ ] Yes - Anthropic (Claude)
- [ ] Yes - Other provider
- [ ] Maybe later
- [ ] No

Deployment Platform:
- [ ] Vercel
- [ ] Netlify
- [ ] AWS (EC2, Lambda, etc.)
- [ ] Google Cloud
- [ ] Heroku
- [ ] Docker / Self-hosted
- [ ] Railway / Render
- [ ] Not decided yet
- [ ] Other: ___________
```

### Phase 3: Testing & Workflow
```
Testing needs:
- [ ] E2E browser testing (Playwright recommended)
- [ ] E2E with Cypress
- [ ] Unit tests only (Jest, Vitest, pytest, etc.)
- [ ] Integration tests
- [ ] None yet (will add later)

Git workflow:
- [ ] Direct commits to main
- [ ] Feature branches + PR reviews
- [ ] Git flow (develop + release branches)
- [ ] Trunk-based development

Deployment automation:
- [ ] Yes - auto-deploy on push to main
- [ ] Yes - manual approval required
- [ ] No - manual deployments only
```

### Phase 4: Special Requirements
```
Any special requirements?
- Monorepo structure?
- Microservices architecture?
- Specific security/compliance needs?
- Required libraries or frameworks?
- Team size and collaboration needs?
```

## Best Practices

- **Be Minimal**: Only create what's needed
- **Be Specific**: Use actual tech names and versions
- **Be Helpful**: Explain decisions and provide examples
- **Be Adaptable**: Offer defaults if user is unsure

Remember: Create a **tailored, minimal, focused** setup - nothing more, nothing less.
AGENT_CONTENT_EOF

# Create README
echo "📖 Creating README..."
cat > .claude/bootstrap/README.md << 'README_CONTENT_EOF'
# Claude Code Bootstrap System (v1)

This is the v1 bootstrap system. See claude-bootstrap-installer.sh v2.0.0 for the current version.

## Quick Start

1. Invoke the bootstrap agent:
   ```
   > Use the project-bootstrap agent to set up this project
   ```

2. Answer questions about your tech stack

3. Get your custom CLAUDE.md + subagents!

4. Commit to git:
   ```bash
   git add CLAUDE.md .claude/
   git commit -m "feat: Add Claude Code configuration"
   ```
README_CONTENT_EOF

# Create general assistant template
echo "📝 Creating templates..."
cat > .claude/bootstrap/templates/general-assistant.md << 'TEMPLATE_CONTENT_EOF'
---
name: general-assistant
description: General-purpose development assistant for {{PROJECT_TYPE}}. Use for code editing, file operations, and general development tasks.
tools: mcp__acp__Read, mcp__acp__Write, mcp__acp__Edit, Grep, Glob, mcp__acp__Bash
model: sonnet
---

You are a general-purpose development assistant for {{PROJECT_NAME}}.

## Your Role
- Code editing and refactoring
- File operations
- Debugging and troubleshooting
- General development support

## Tech Stack
{{TECH_STACK}}

## Best Practices
{{BEST_PRACTICES}}

Delegate specialized tasks to appropriate subagents when available.
TEMPLATE_CONTENT_EOF

# Success message
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Installation Complete!                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Created:"
echo "   .claude/agents/project-bootstrap.md"
echo "   .claude/bootstrap/README.md"
echo "   .claude/bootstrap/templates/"
echo ""
echo "🚀 Next Steps:"
echo ""
echo "   1. Open Claude Code in this project directory"
echo ""
echo "   2. Run this command:"
echo "      > Use the project-bootstrap agent to set up this project"
echo ""
echo "   3. Answer questions about your tech stack"
echo ""
echo "   4. Get your custom CLAUDE.md + subagents!"
echo ""
echo "   5. Commit the generated files:"
echo "      git add CLAUDE.md .claude/"
echo "      git commit -m \"feat: Add Claude Code configuration\""
echo ""
echo "📖 For more info:"
echo "   cat .claude/bootstrap/README.md"
echo ""
echo "🎉 Happy coding with Claude!"
echo ""
