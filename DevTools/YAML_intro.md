# YAML

YAML (rhymes with "camel") is a human-readable data serialization language, mostly used for configuration files.
The name is a recursive acronym, "YAML Ain't Markup Language" (originally "Yet Another Markup Language"): it holds data, not formatted documents.

+ Current version: **YAML 1.2** (2009, revision 1.2.2 in 2021). Many widely used parsers (for example PyYAML, and Go's `yaml.v2`) still follow **YAML 1.1** typing rules, which matters for the pitfalls in section 6.
+ YAML 1.2 is designed as a superset of JSON, so almost any JSON document is also valid YAML.
+ For a comparison with JSON and Markdown, see [cmp_md_yml_json.md](cmp_md_yml_json.md).

## 1. Why use YAML

+ **Readable**: structure comes from indentation instead of braces, brackets, and closing tags.
+ **Comments** with `#`, which JSON doesn't allow.
+ **Richer than JSON**: multi-line strings, anchors to reuse blocks, several documents in one file.
+ **Downside**: whitespace-sensitive and implicitly typed, so small mistakes can change the meaning without an error (section 6).

## 2. Basic syntax

```yaml
# comment: from # to the end of the line
name: my-service          # mapping: "key: value" (a space after the colon is required)
port: 8080

server:                   # nested mapping: indent with spaces (2 is common)
  host: 127.0.0.1
  tls: false

allowed_ips:              # sequence (list): "- " per item
  - 192.168.1.10
  - 10.0.0.5

users:                    # list of mappings
  - name: alice
    role: admin
  - name: bob
    role: viewer
```

Rules:

+ **Indentation uses spaces only**. Tab characters are not allowed for indentation. Items at the same level must have the same indentation.
+ `key: value` needs the space after `:`. `key:value` is a single string, not a mapping.
+ List items under a key may be indented or at the same level as the key; both are valid. Be consistent.
+ Keys are case-sensitive and must be unique within a mapping.

**Flow style** uses JSON-like brackets and is handy for short lists:

```yaml
ports: [80, 443]
limits: {cpu: "500m", memory: 256Mi}
```

## 3. Scalars, types, and quoting

| Value | YAML 1.2 (core schema) | Notes |
| --- | --- | --- |
| `hello`, `Jane Doe` | string | Plain (unquoted) strings |
| `42`, `-7`, `0x1F`, `0o17` | integer | `0o17` is octal in 1.2; in 1.1 octal is `017` |
| `3.14`, `1e3`, `.inf`, `.nan` | float | |
| `true`, `false` | boolean | 1.1 also treats `yes`/`no`/`on`/`off`/`y`/`n` as booleans |
| `null`, `~`, empty value | null | `key:` with nothing after it is null |
| `"42"`, `'true'` | string | Quoting forces a string |

Quoting:

+ **Single quotes** `'...'`: literal; no escapes. Write a single quote as `''`, e.g. `'it''s'`.
+ **Double quotes** `"..."`: support escapes such as `\n`, `\t`, `\"`, `é`.
+ Quote values that start with or contain special characters: `: `, ` #`, or a leading `{`, `[`, `*`, `&`, `!`, `|`, `>`, `@`, `` ` ``, `%`.
+ Explicit tags force a type: `!!str 3.10`, `!!int "42"`.

## 4. Multi-line strings

```yaml
literal: |        # keeps newlines
  line one
  line two
folded: >         # joins lines with spaces (blank line = newline)
  this is one
  long sentence
script: |-        # "-" strips the final newline; "+" keeps all trailing newlines
  echo hello
```

`literal` becomes `"line one\nline two\n"`, `folded` becomes `"this is one long sentence\n"`, and `script` becomes `"echo hello"`.

## 5. Documents, anchors, and merge keys

```yaml
---                       # start of a document
defaults: &defaults       # &name defines an anchor
  restart: always
  log_level: info

web:
  <<: *defaults           # merge the anchored mapping (merge key)
  image: nginx
worker:
  <<: *defaults
  log_level: debug        # override one value
...                       # optional end of document
---                       # a second document in the same file
kind: other
```

+ `---` separates documents in one file; Kubernetes manifests often contain several. `...` ends a document and is rarely needed.
+ `&name` / `*name` (anchor / alias) reuse a node.
+ The merge key `<<` is from YAML 1.1. It is not in the 1.2 core schema, but most tools (Docker Compose, GitLab CI, PyYAML) support it.
  GitHub Actions historically didn't support anchors; check your tool before using them.

## 6. Pitfalls

| You write | Many parsers read | Fix |
| --- | --- | --- |
| `country: NO` | `false` (YAML 1.1 boolean, the "Norway problem") | `country: "NO"` |
| `version: 3.10` | float `3.1` | `version: "3.10"` |
| `mode: 0755` | octal integer 493 (1.1) | `mode: "0755"` if you need the text |
| `time: 12:30` | integer 750 (1.1 base-60 number) | `time: "12:30"` |
| `password: abc#123` | Fine, but `abc #123` becomes `abc` (comment) | Quote values with `#` |
| Tab used for indentation | Parse error | Use spaces; configure the editor |
| Item indented one space too far or too little | Different structure, often no error | Validate with `yamllint` or a schema |

Security: don't load untrusted YAML with a loader that can construct arbitrary objects. In Python use `yaml.safe_load()`, not `yaml.load()` with the default/unsafe loader.

## 7. Checking and converting

```shell
yamllint config.yaml                                   # syntax and style check (pip install yamllint)
python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1])))' config.yaml   # see how PyYAML types the values
yq '.server.port' config.yaml                          # query (mikefarah/yq)
yq -o=json config.yaml                                 # convert to JSON to check the structure
```

Converting to JSON is a quick way to see what a parser really understood.

## 8. Common uses

+ **CI/CD**: GitHub Actions (`.github/workflows/*.yml`), GitLab CI (`.gitlab-ci.yml`), CircleCI.
+ **Containers and DevOps**: Kubernetes manifests, Docker Compose (`compose.yaml`), Ansible playbooks, Helm charts.
+ **Application config**: Spring Boot (`application.yml`), Ruby on Rails (`database.yml`), Home Assistant, ROS 2 parameters.
+ **Docs and metadata**: front matter in Markdown files, MkDocs (`mkdocs.yml`), OpenAPI specs.
+ **Linux device tree**: kernel binding schemas under `Documentation/devicetree/bindings/` are YAML (see [../Linux/dts_intro.md](../Linux/dts_intro.md)).

## 9. Example: application config

```yaml
# Application configuration
app_name: my-web-service
version: "1.2.0"          # quoted: keep it a string
debug: false

server:
  host: 0.0.0.0
  port: 8080
  allowed_ips:
    - 192.168.1.10
    - 10.0.0.5

database:
  host: db.local
  port: 5432
  user: app
  password_env: DB_PASSWORD   # read the secret from an environment variable, don't store it here
```

Don't commit passwords or tokens in YAML config files. Reference an environment variable or a secret store
(Kubernetes Secrets, GitHub Actions secrets) instead.

## Related notes

+ [cmp_md_yml_json.md](cmp_md_yml_json.md): YAML compared with JSON and Markdown
+ [docker_demo.md](docker_demo.md): Docker examples
+ [../Linux/dts_intro.md](../Linux/dts_intro.md): device tree, YAML binding schemas

## Reference

+ YAML specification (1.2.2): <https://yaml.org/spec/1.2.2/>
+ YAML home: <https://yaml.org/>
+ yamllint: <https://yamllint.readthedocs.io/>
+ PyYAML documentation: <https://pyyaml.org/wiki/PyYAMLDocumentation>
+ yq (mikefarah): <https://mikefarah.gitbook.io/yq/>
