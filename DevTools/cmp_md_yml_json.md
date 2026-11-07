# Markdown vs YAML vs JSON

All three are plain-text formats that people and programs can read, but they do different jobs:

+ **Markdown** formats **documents**: prose with headings, lists, links, and code.
+ **YAML** holds **data** in a form people edit by hand, usually configuration.
+ **JSON** holds **data** in a strict form that programs exchange, usually over APIs.

Markdown is a markup language; YAML and JSON are data serialization formats. So the real choice is usually between YAML and JSON,
while Markdown is chosen whenever the content is text for people to read.

## 1. Overview

| | Markdown | YAML | JSON |
| --- | --- | --- | --- |
| Kind | Lightweight markup language | Data serialization language | Data interchange format |
| Extensions | `.md` | `.yaml`, `.yml` | `.json` |
| Specification | No single standard; CommonMark and GitHub Flavored Markdown (GFM) are the common dialects | YAML 1.2 (2009, revised 2021); many tools still follow YAML 1.1 | RFC 8259 / ECMA-404 |
| Main use | READMEs, docs, notes, blogs | Configuration (Docker Compose, Kubernetes, GitHub Actions, Ansible) | Web APIs, data exchange, many config files (`package.json`) |
| Structure from | Symbols (`#`, `-`, `*`, `` ` ``) and blank lines | Indentation (spaces only) and `:` / `-`; also optional `{}` / `[]` flow style | Braces `{}`, brackets `[]`, commas |
| Data types | None (it is text) | Strings, numbers, booleans, null, lists, maps, timestamps (1.1), custom tags | String, number, boolean, null, array, object |
| Comments | HTML comments `<!-- -->` | `# ...` | Not allowed |
| Human editing | Very easy | Easy, but indentation and implicit typing cause mistakes | Tedious (quotes, commas), but unambiguous |
| Parsing | Converted to HTML; not meant as a data source | Needs a library (PyYAML, ruamel.yaml, yaml-cpp, ...) | Built-in or standard library in most languages |

## 2. Markdown

+ Written so that the **raw file reads well** without rendering, and converts easily to HTML (and with Pandoc, to PDF, DOCX, and more).
+ Dialects differ: tables, task lists, and strikethrough come from GFM, not from the original Markdown or CommonMark. Check what your renderer supports.
+ **Front matter**: many static site generators (Jekyll, Hugo, MkDocs) read a YAML block between `---` lines at the top of a Markdown file as page metadata.
  It is a tool convention, not part of Markdown.

```markdown
---
title: User profile
tags: [demo, profile]
---

# User profile: Jane Doe
```

## 3. YAML

+ Structure comes from **indentation with spaces**; tab characters are not allowed for indentation.
+ Supports comments, multi-line strings (`|` keeps newlines, `>` folds them), anchors and aliases (`&name` / `*name`) to reuse blocks,
  and several documents in one file (separated by `---`).
+ YAML 1.2 is (almost) a superset of JSON, so most JSON files are valid YAML.
+ **Pitfalls**: YAML guesses types from plain (unquoted) values, and many parsers still use YAML 1.1 rules:
  - `country: NO` becomes the boolean `false` in YAML 1.1 (`yes`/`no`/`on`/`off` are booleans there).
  - `version: 3.10` becomes the number `3.1`.
  - `mode: 0755` may be read as an octal number.
  - Wrong indentation often produces a **different, still valid** structure instead of an error.
  - Quote strings that could be misread: `country: "NO"`, `version: "3.10"`.
+ Don't load untrusted YAML with a full loader; some loaders can create arbitrary objects (in Python use `yaml.safe_load`, not `yaml.load`).

See [YAML_intro.md](YAML_intro.md) for the syntax basics.

## 4. JSON

+ Derived from JavaScript object literals, but language-independent.
+ **Strict syntax**: keys and strings in double quotes, no trailing commas, no comments, no single quotes.
  Any of these errors makes the parser reject the whole document, which makes JSON predictable for programs.
+ Only six types. There are no dates, binary data, or integer vs float distinction; numbers have no defined precision
  (large integers may lose precision in JavaScript, which uses 64-bit floats).
+ Object members are unordered by specification, and duplicate keys are not portable.
+ Variants: **JSON Lines** (one JSON value per line, for logs and streams), **JSON Schema** (validation), and **JSONC / JSON5** (comments and trailing commas, for config files such as VS Code settings).

## 5. Same data in each format

Markdown presents the data for a reader; the types (number, boolean) are lost:

```markdown
# User profile: Jane Doe

+ **Age:** 30
+ **Active:** yes
+ **Skills:**
  + Python
  + JavaScript
  + Docker
```

YAML, block style (with a comment, which JSON can't have):

```yaml
user:
  name: Jane Doe
  age: 30          # integer
  active: true     # boolean
  skills:
    - Python
    - JavaScript
    - Docker
```

The same YAML in flow style looks almost like JSON:

```yaml
user: {name: Jane Doe, age: 30, active: true, skills: [Python, JavaScript, Docker]}
```

JSON:

```json
{
  "user": {
    "name": "Jane Doe",
    "age": 30,
    "active": true,
    "skills": ["Python", "JavaScript", "Docker"]
  }
}
```

## 6. Which one to use

| Situation | Use |
| --- | --- |
| Text for people: README, docs, notes | Markdown |
| Config that people edit and want to comment | YAML (or TOML for simpler, flat configs) |
| Data sent between programs, API payloads | JSON |
| Config written and read mainly by tools | JSON |
| Logs or streaming records | JSON Lines |
| Document with a little metadata | Markdown with YAML front matter |

## 7. Command-line tools

```shell
jq '.user.skills[]' user.json                 # query/format JSON
python3 -m json.tool user.json                # validate and pretty-print JSON
yq '.user.age' user.yaml                      # query YAML (mikefarah/yq syntax)
yq -o=json user.yaml > user.json              # YAML -> JSON
yq -P user.json > user.yaml                   # JSON -> YAML (-P = pretty YAML)
pandoc README.md -o README.html               # Markdown -> HTML
```

There are two different tools named `yq` (the Go version by mikefarah and a Python wrapper around `jq`); the examples use the Go version.

## Related notes

+ [YAML_intro.md](YAML_intro.md): YAML syntax and use cases
+ [mermaid_intro.md](mermaid_intro.md): diagrams written inside Markdown

## Reference

+ CommonMark: <https://commonmark.org/>
+ GitHub Flavored Markdown spec: <https://github.github.com/gfm/>
+ YAML specification: <https://yaml.org/spec/>
+ JSON (RFC 8259): <https://www.rfc-editor.org/rfc/rfc8259>
+ JSON overview: <https://www.json.org/>
+ jq manual: <https://jqlang.org/manual/>
+ yq (mikefarah): <https://mikefarah.gitbook.io/yq/>
