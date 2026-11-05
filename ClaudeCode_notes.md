# Claude Code Configuration Files & Extensions: Notes

Knowing where Claude Code's configuration files live and what each one does helps you control the AI's behavior, manage project conventions, and work more efficiently.

---

## Table of Contents

1. [Overview](#1-overview)
2. [CLAUDE.md: Persistent Project Instructions](#2-claudemd-persistent-project-instructions)
3. [.claude/rules/: Modular Rules](#3-clauderules-modular-rules)
4. [SKILL.md: Custom Skills](#4-skillmd-custom-skills)
5. [settings.json: Permissions & Behavior](#5-settingsjson-permissions--behavior)
6. [MCP: Connecting External Tools](#6-mcp-connecting-external-tools)

---

## 1. Overview

| File / Directory | Purpose | Location |
| --- | --- | --- |
| `CLAUDE.md` | Persistent instructions: build/test commands, code style, architecture, things to avoid. Loaded at the start of every session. | Project: `./CLAUDE.md` or `./.claude/CLAUDE.md`<br>User: `~/.claude/CLAUDE.md` |
| `.claude/rules/*.md` | Modular rules; `paths` can limit a rule so it loads only when Claude works on matching files. | Project: `.claude/rules/`<br>User: `~/.claude/rules/` |
| `SKILL.md` | A skill that packages a workflow or domain knowledge. Invoke it with `/skill-name`, or let Claude load it automatically. | Project: `.claude/skills/<name>/SKILL.md`<br>User: `~/.claude/skills/<name>/SKILL.md` |
| `settings.json` | Permissions (`permissions`), environment variables (`env`), hooks, model, and more. | User: `~/.claude/settings.json`<br>Project (shared): `.claude/settings.json` |
| `settings.local.json` | Personal project settings kept out of version control (e.g., personal permission overrides). | `.claude/settings.local.json` |
| `.mcp.json` | Project-level MCP server configuration that can be shared with the team. | Project root |
| `~/.claude.json` | Internal state maintained automatically by Claude Code: account info, UI preferences such as theme, local/user-scope MCP config, project trust state, etc. (usually no need to edit by hand). | Home directory |

> **Settings precedence** (high → low): managed (enterprise policy) → command-line arguments → `.claude/settings.local.json` → `.claude/settings.json` → `~/.claude/settings.json`

---

## 2. CLAUDE.md: Persistent Project Instructions

### 2.1 How it loads

* At startup, Claude reads `CLAUDE.md` files from the current directory upward, level by level. A `CLAUDE.md` in a subdirectory loads only when Claude reads files in that subdirectory.
* Use `@path/to/file` to import other files (e.g., `@docs/architecture.md`).
* Type `/memory` in a session to open and edit the loaded memory files.

### 2.2 Generating it with `/init`

Start Claude Code in the project root, then run `/init`:

```bash
cd /path/to/your/project
claude
# At the Claude Code prompt, type:
/init
```

Claude will:

1. Scan the project: languages, frameworks, package managers, test and build scripts.
2. Generate `CLAUDE.md`, or suggest improvements if one already exists.
3. After it's generated, review it yourself and add team-specific conventions and things to avoid.

### 2.3 Best-practice template

```markdown
# Project Name

## Common Commands
* Install dependencies: `npm install`
* Dev server: `npm run dev`
* All tests: `npm test`
* Single test: `npx jest src/components/Button.test.tsx`
* Lint: `npm run lint`
* Type check: `npx tsc --noEmit`

## Code Style & Architecture
* TypeScript 5.x / Node.js 20+
* Feature-based directory structure (grouped by feature), not layer-based
* Components use PascalCase (`UserProfile.tsx`); functions and variables use camelCase (`getUserData`)
* Style with Tailwind CSS; avoid inline styles
* Wrap API calls in `try...catch` and handle errors through `src/utils/errorHandler.ts`

## DO NOTs
* Don't use the `any` type; use `unknown` or an explicit `interface`
* Don't hard-code API URLs in components; always use environment variables (`import.meta.env`)
* Don't edit `package-lock.json` by hand

## Context & Notes
* State management is migrating from Redux to Zustand; use Zustand for new features
```

### 2.4 The four core sections

| Section | Purpose | Why it matters |
| --- | --- | --- |
| Common commands | Tells Claude how to build, test, and lint | Claude can run the tests itself to check its changes |
| Style & architecture | Tech stack, naming, directory layout | Code matches team conventions, so less fixing in code review |
| DO NOTs | Hard red lines | Keeps the AI from taking sloppy shortcuts |
| Context & notes | Ongoing refactors, special business logic | Keeps new code aligned with the project's long-term direction |

### 2.5 Writing guidelines

* **Keep it concise**: `CLAUDE.md` takes up context tokens in every session. Use bullet points and short sentences.
* **Keep it current**: When the stack changes, just ask Claude to update it, e.g., "*We switched our test framework from Jest to Vitest; please update CLAUDE.md.*"
* **Put it under version control**: Commit the project-level `CLAUDE.md` so the whole team shares the same conventions.

---

## 3. .claude/rules/: Modular Rules

As a project grows, cramming every convention into a single `CLAUDE.md` wastes tokens. `.claude/rules/` lets you split rules across multiple files.

### 3.1 How it works

* **Rule files without `paths`**: Load every session, just like `CLAUDE.md`.
* **Rule files with `paths`**: Load only when Claude works on files matching the glob patterns.
* Splitting by area (frontend, backend, testing, security) keeps them easier to maintain.

### 3.2 Example directory layout

```text
my-project/
├── CLAUDE.md              # Global instructions (keep short: core commands and red lines)
└── .claude/
    ├── settings.json
    └── rules/
        ├── frontend.md    # Frontend component and styling conventions
        ├── backend.md     # API and database conventions
        ├── testing.md     # Test-writing conventions
        └── security.md    # Security and secrets handling
```

### 3.3 Example rule files

`paths` is a YAML list; each item is a glob pattern.

**`.claude/rules/frontend.md`**

```markdown
---
paths:
  - "src/components/**/*"
  - "src/pages/**/*"
---
# Frontend Conventions
* Style UI components with Tailwind CSS; no inline styles
* Use Tailwind design tokens for colors (e.g., `bg-slate-900`); no hard-coded hex values
* Every component needs a matching unit test file (`.test.tsx`)
```

**`.claude/rules/backend.md`**

```markdown
---
paths:
  - "server/**/*"
  - "src/api/**/*"
---
# Backend & API Conventions
* API responses use a uniform shape: `{ success: boolean, data: T, error?: string }`
* Query the database through Prisma ORM; no raw SQL unless needed for performance (with a comment explaining why)
```

### 3.4 Best practices

1. **Keep core principles in `CLAUDE.md`**: global build commands, architectural direction, red lines.
2. **Split `rules/` by module**: In a monorepo, name files after subsystems (e.g., `packages-ui.md`, `packages-core.md`).
3. **Review regularly**: Remove outdated rules so they don't conflict with each other.

---

## 4. SKILL.md: Custom Skills

Skills package repeatable workflows or domain knowledge. You can trigger one manually with `/skill-name`, or Claude can load it automatically based on its `description`.

> Legacy custom slash commands in `.claude/commands/*.md` still work, but new functionality is better written as skills.

### 4.1 Directory layout

```text
my-project/
└── .claude/
    └── skills/
        └── deploy-staging/        # Skill folder (folder name = skill name)
            ├── SKILL.md           # Required: instructions and description
            └── helper-script.sh   # Optional: helper scripts or reference material
```

### 4.2 Template

```markdown
---
name: deploy-staging
description: Runs unit tests, builds the project, and deploys it to the staging server. Use when the user asks to deploy to staging.
disable-model-invocation: true
---

# Deploy to Staging

Follow these steps in order:

1. **Check the working tree**
   - If there are uncommitted changes, ask the user whether to stash or commit them first.

2. **Run tests**
   - Run `npm test`. If anything fails, **stop immediately** and report the error.

3. **Build**
   - Run `npm run build` and confirm it compiles.

4. **Deploy**
   - Run `./scripts/deploy.sh staging`.
   - When done, report the version number and deploy time.
```

### 4.3 Frontmatter fields

| Field | Description |
| --- | --- |
| `name` | Skill name, which is also the slash command name (lowercase letters, digits, hyphens). Defaults to the folder name if omitted. |
| `description` | **The most important field.** Claude uses it to decide when to load the skill automatically, so state clearly what it does and when to use it. |
| `disable-model-invocation` | When `true`, only the user can trigger the skill with `/name`. Recommended for workflows with side effects such as deploying or publishing. |
| `allowed-tools` | Tools the skill may use without asking for confirmation (e.g., `Bash(npm test *)`). |

### 4.4 Best practices

* **Pair with helper scripts**: Put complex shell logic in `.sh`/`.py` files inside the skill folder, and explain in `SKILL.md` how to call them.
* **One job per skill**: Each skill handles a single task (e.g., "generate API docs", "check database migrations").
* **Define error handling**: Tell Claude what to do when tests fail or dependencies are missing, so it doesn't make blind changes.

---

## 5. settings.json: Permissions & Behavior

### 5.1 Template

```json
{
  "permissions": {
    "allow": [
      "Bash(npm test)",
      "Bash(npm run build)",
      "Bash(git status)",
      "Bash(git diff *)"
    ],
    "ask": [
      "Bash(git push *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Read(./.env)",
      "Read(./secrets/**)"
    ],
    "defaultMode": "default"
  },
  "env": {
    "NODE_ENV": "development"
  },
  "model": "opus"
}
```

### 5.2 Permissions (`permissions`)

Rules take the form `ToolName(rule content)`, e.g., `Bash(npm test)`, `Read(./.env)`, `Edit(src/**)`, `WebFetch(domain:example.com)`. In Bash rules, `*` is a wildcard (the older `Bash(npm run test:*)` syntax still works).

| List | Meaning |
| --- | --- |
| `allow` | Runs without confirmation |
| `ask` | Always asks before running |
| `deny` | Blocked (highest priority) |

Valid `defaultMode` values:

| Value | Meaning |
| --- | --- |
| `default` | Standard mode: asks the first time each tool is used |
| `acceptEdits` | Automatically accepts file edits |
| `plan` | Plan mode: can analyze, but can't modify files or run commands |
| `bypassPermissions` | Skips all permission prompts (only recommended in isolated environments such as containers) |

> Type `/permissions` in a session to view and manage permission rules.

### 5.3 Other common fields

* `env`: Environment variables injected into the session (e.g., `CLAUDE_CODE_MAX_OUTPUT_TOKENS` sets the output token limit).
* `model`: The default model.
* `hooks`: Commands that run automatically on specific events (e.g., `PreToolUse`, `PostToolUse`, `Stop`), such as running a formatter after every edit.

> UI preferences such as theme and editor mode are **not** in `settings.json`. They are set with `/config` and stored in `~/.claude.json`.

### 5.4 Tips

1. **Security**: `.claude/settings.json` is committed to version control, so **never** put passwords, API keys, or other secrets in it.
2. **Personal overrides**: Put personal permissions in `.claude/settings.local.json`. Claude Code sets git to ignore this file when it creates it.

---

## 6. MCP: Connecting External Tools

**Model Context Protocol (MCP)** lets Claude connect to external tools, databases, APIs, and local services.

### 6.1 Adding servers with `claude mcp add` (recommended)

```bash
# Local stdio server (everything after `--` is the command that starts the server)
claude mcp add my-db -- npx -y @modelcontextprotocol/server-postgres postgresql://localhost:5432/mydb

# With environment variables
claude mcp add --transport stdio --env API_KEY=your_key my-service -- npx -y some-mcp-server

# Remote HTTP server
claude mcp add --transport http notion https://mcp.notion.com/mcp
```

**Scopes (`--scope`):**

| Scope | Meaning | Stored in |
| --- | --- | --- |
| `local` (default) | Only you, only the current project | `~/.claude.json` |
| `project` | Shared with the team (can be committed) | `.mcp.json` in the project root |
| `user` | All of your projects | `~/.claude.json` |

### 6.2 Editing `.mcp.json` by hand

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/your/project"]
    },
    "my-api": {
      "type": "http",
      "url": "https://api.example.com/mcp",
      "headers": {
        "Authorization": "Bearer ${API_TOKEN}"
      }
    }
  }
}
```

* `.mcp.json` supports `${VAR}` and `${VAR:-default}` environment variable expansion, so tokens don't have to be hard-coded in the file.
* For security, Claude Code asks you to approve servers defined in a project's `.mcp.json` before first use.

### 6.3 Management commands

| Command | Description |
| --- | --- |
| `claude mcp list` | List all servers and their connection status |
| `claude mcp get <name>` | Show details for a specific server |
| `claude mcp remove <name>` | Remove a server |
| `/mcp` (in a session) | View connected servers and available tools, and handle OAuth authentication |

### 6.4 Use cases

* **Database queries**: "*Show me the users who were active in the last 30 days.*"
* **Project analysis**: "*Analyze the dependencies between modules under src. Are there any circular dependencies?*"
* **Third-party services**: Read issues, design files, monitoring data, and more.

### ⚠️ Security notes

* **Least privilege**: Use read-only accounts for databases and APIs where possible, so production data can't be changed by mistake.
* **Protect secrets**: Don't put passwords or tokens in plain text in shared config files; use environment variables instead.
* **Use only trusted servers**: Third-party MCP servers can read your data or introduce prompt-injection risks.
