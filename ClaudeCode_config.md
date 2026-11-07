# Claude Code configuration: CLAUDE.md, rules, settings, skills, MCP

Where Claude Code's configuration files live and what each one does.
Instructions (`CLAUDE.md`, rules) tell Claude how to work; settings control what it may do; skills and MCP servers add workflows and tools.

## 1. Overview

| File / directory | Purpose | Location |
| --- | --- | --- |
| `CLAUDE.md` | Persistent instructions: build/test commands, code style, architecture, things to avoid. Loaded at the start of every session | Project: `./CLAUDE.md` or `./.claude/CLAUDE.md`<br>User: `~/.claude/CLAUDE.md` |
| `.claude/rules/*.md` | Modular rules; `paths` can limit a rule so it loads only when Claude works on matching files | Project: `.claude/rules/`<br>User: `~/.claude/rules/` |
| `settings.json` | Permissions, environment variables, hooks, model, and more | User: `~/.claude/settings.json`<br>Project (shared): `.claude/settings.json` |
| `settings.local.json` | Personal project settings kept out of version control | `.claude/settings.local.json` |
| `SKILL.md` | A skill: a packaged workflow or domain knowledge, run with `/skill-name` or loaded automatically | Project: `.claude/skills/<name>/SKILL.md`<br>User: `~/.claude/skills/<name>/SKILL.md` |
| `.mcp.json` | Project MCP servers, shared with the team | Project root |
| `~/.claude.json` | State kept by Claude Code: account, UI preferences (theme), local/user-scope MCP servers, project trust. Usually not edited by hand | Home directory |

| Kind | Sections |
| --- | --- |
| Instructions | 2. `CLAUDE.md`, 3. `.claude/rules/` |
| Permissions and behavior | 4. `settings.json` |
| Extensions | 5. Skills, 6. MCP servers |

## 2. CLAUDE.md: persistent instructions

### 2.1 How it loads

+ At startup, Claude reads `CLAUDE.md` files from the current directory upward. A `CLAUDE.md` in a subdirectory loads only when Claude reads files in that subdirectory.
+ `@path/to/file` imports another file (e.g. `@docs/architecture.md`).
+ `/memory` in a session opens the loaded memory files for editing.

### 2.2 Generate it with `/init`

```shell
cd /path/to/your/project
claude
# at the Claude Code prompt:
/init
```

Claude scans the project (languages, frameworks, package managers, test and build scripts) and writes `CLAUDE.md`, or suggests improvements to an existing one.
Review the result and add team conventions and things to avoid.

### 2.3 What to put in it

| Section | Purpose | Why it matters |
| --- | --- | --- |
| Common commands | How to build, test, and lint | Claude can run the tests to check its changes |
| Style and architecture | Tech stack, naming, directory layout | Code matches team conventions; less fixing in review |
| DO NOTs | Hard red lines | Keeps Claude from taking shortcuts you don't want |
| Context and notes | Ongoing migrations, special business logic | New code follows the project's direction |

Example:

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

This repository's own [CLAUDE.md](CLAUDE.md) is a real example for a notes repository.

### 2.4 Writing guidelines

+ **Keep it concise**: `CLAUDE.md` uses context tokens in every session. Use bullet points and short sentences.
+ **Keep it current**: when the stack changes, ask Claude to update it ("We switched from Jest to Vitest; please update CLAUDE.md.").
+ **Commit it**: the project `CLAUDE.md` gives the whole team the same conventions.

## 3. .claude/rules/: modular rules

When one `CLAUDE.md` grows too large, split the conventions into several files under `.claude/rules/`.

+ **Without `paths`**: the rule loads every session, like `CLAUDE.md`.
+ **With `paths`**: the rule loads only when Claude works on files matching the glob patterns.
+ Keep core principles (build commands, architecture, red lines) in `CLAUDE.md`. Split the rest by area or, in a monorepo, by package (`packages-ui.md`, `packages-core.md`).
+ Review the rules regularly and remove outdated ones, so they don't contradict each other.

```text
my-project/
├── CLAUDE.md              # global instructions (short: core commands and red lines)
└── .claude/
    ├── settings.json
    └── rules/
        ├── frontend.md    # frontend component and styling conventions
        ├── backend.md     # API and database conventions
        ├── testing.md     # test-writing conventions
        └── security.md    # security and secrets handling
```

`paths` is a YAML list of glob patterns in the file's frontmatter:

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

## 4. settings.json: permissions and behavior

### 4.1 Example

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

### 4.2 Precedence

High to low: managed (enterprise policy) → command-line arguments → `.claude/settings.local.json` → `.claude/settings.json` → `~/.claude/settings.json`.

+ `.claude/settings.json` is committed, so **never** put passwords, API keys, or other secrets in it.
+ Put personal permissions in `.claude/settings.local.json`. Claude Code configures git to ignore it when it creates the file.

### 4.3 Permissions

Rules have the form `ToolName(rule content)`: `Bash(npm test)`, `Read(./.env)`, `Edit(src/**)`, `WebFetch(domain:example.com)`.
In Bash rules, `*` is a wildcard (the older `Bash(npm run test:*)` form still works).

| List | Meaning |
| --- | --- |
| `allow` | Runs without confirmation |
| `ask` | Always asks before running |
| `deny` | Blocked (highest priority) |

Common `defaultMode` values:

| Value | Meaning |
| --- | --- |
| `default` | Asks the first time each tool is used |
| `acceptEdits` | Accepts file edits automatically |
| `plan` | Plan mode: can analyze, but can't modify files or run commands |
| `bypassPermissions` | Skips all permission prompts (only in isolated environments such as containers) |

Newer versions add more modes; check the settings documentation for the current list.
`/permissions` in a session shows and edits the rules.

### 4.4 Other fields

+ `env`: environment variables for the session (e.g. `CLAUDE_CODE_MAX_OUTPUT_TOKENS` sets the output token limit).
+ `model`: the default model.
+ `hooks`: commands that run on events (`PreToolUse`, `PostToolUse`, `Stop`, ...), for example a formatter after every edit.

UI preferences such as theme and editor mode are **not** in `settings.json`. They are set with `/config` and stored in `~/.claude.json`.

## 5. Skills: SKILL.md

A skill packages a repeatable workflow or domain knowledge. Run it with `/skill-name`, or let Claude load it automatically based on its `description`.
Old custom slash commands in `.claude/commands/*.md` still work, but new ones are better written as skills.

### 5.1 Layout and template

```text
my-project/
└── .claude/
    └── skills/
        └── deploy-staging/        # skill folder (folder name = skill name)
            ├── SKILL.md           # required: description and instructions
            └── helper-script.sh   # optional: helper scripts or reference material
```

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

### 5.2 Frontmatter fields

| Field | Description |
| --- | --- |
| `name` | Skill name and slash command name (lowercase letters, digits, hyphens). Defaults to the folder name |
| `description` | **The most important field.** Claude uses it to decide when to load the skill, so say what it does and when to use it |
| `disable-model-invocation` | `true`: only the user can run the skill with `/name`. Recommended for side effects such as deploying or publishing |
| `allowed-tools` | Tools the skill may use without asking (e.g. `Bash(npm test *)`) |

### 5.3 Guidelines

+ **One job per skill**, e.g. "generate API docs" or "check database migrations".
+ **Put complex logic in scripts** (`.sh`, `.py`) inside the skill folder, and say in `SKILL.md` how to call them.
+ **Define error handling**: say what to do when tests fail or dependencies are missing.

## 6. MCP servers: external tools

The **Model Context Protocol (MCP)** connects Claude to external tools, databases, APIs, and local services.

### 6.1 Add a server with `claude mcp add`

```shell
# local stdio server (everything after -- is the command that starts it)
claude mcp add my-db -- npx -y @modelcontextprotocol/server-postgres postgresql://localhost:5432/mydb

# with environment variables
claude mcp add --transport stdio --env API_KEY=your_key my-service -- npx -y some-mcp-server

# remote HTTP server
claude mcp add --transport http notion https://mcp.notion.com/mcp
```

| Scope (`--scope`) | Meaning | Stored in |
| --- | --- | --- |
| `local` (default) | Only you, only the current project | `~/.claude.json` |
| `project` | Shared with the team (can be committed) | `.mcp.json` in the project root |
| `user` | All of your projects | `~/.claude.json` |

### 6.2 Edit `.mcp.json` by hand

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

+ `.mcp.json` expands `${VAR}` and `${VAR:-default}`, so tokens don't have to be written into the file.
+ Claude Code asks you to approve servers from a project's `.mcp.json` before their first use.

### 6.3 Manage servers

| Command | Description |
| --- | --- |
| `claude mcp list` | List servers and their connection status |
| `claude mcp get <name>` | Details of one server |
| `claude mcp remove <name>` | Remove a server |
| `/mcp` (in a session) | Connected servers and their tools; OAuth sign-in |

Example requests once a server is connected: "Show me the users who were active in the last 30 days" (database),
"Read the open issues labeled bug" (issue tracker).

### 6.4 Security

+ **Least privilege**: use read-only database and API accounts where possible.
+ **Protect secrets**: keep passwords and tokens in environment variables, not in shared config files.
+ **Trusted servers only**: a third-party MCP server can read your data and can carry prompt-injection risks.

## Related notes

+ [CLAUDE.md](CLAUDE.md): this repository's instructions for Claude Code
+ [git_pull_rebase.md](git_pull_rebase.md), [git_cmds.md](git_cmds.md)

## Reference

+ [Claude Code documentation](https://docs.claude.com/en/docs/claude-code/overview)
+ [Model Context Protocol](https://modelcontextprotocol.io/)
