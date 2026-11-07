# Git identity: `user.name` and `user.email`

Every commit records an author name and email. They are plain text, not a login:
authentication to GitHub or Gerrit uses SSH keys or tokens, configured separately.

## 1. Configuration scopes

| Scope | Option | File | Applies to |
| --- | --- | --- | --- |
| System | `--system` | `/etc/gitconfig` | All users |
| Global | `--global` | `~/.gitconfig` (or `~/.config/git/config`) | All your repositories |
| Local | `--local` (the default when writing) | `.git/config` | This repository; overrides global |

```shell
git config --global user.name "Your Name"            # quote names with spaces
git config --global user.email "you@example.com"
git config user.email "you@company.example"          # only this repository
git config user.email                                # the value in effect
git config --show-origin --show-scope user.email     # and where it comes from
git config --list --show-origin                      # everything
```

## 2. A different identity per directory

```text
# ~/.gitconfig
[user]
	name = Your Name
	email = you@example.com
[includeIf "gitdir:~/work/"]
	path = ~/.gitconfig-work

# ~/.gitconfig-work
[user]
	email = you@company.example
```

Every repository under `~/work/` uses the work email, without per-repository settings. The trailing `/` matches all subdirectories.

## 3. Fix the author of the last commit

```shell
git config user.email "you@company.example"
git commit --amend --reset-author --no-edit          # rewrite the last commit with the current identity
```

This creates a new commit (new hash), like a rebase, so do it before pushing.
For older commits, use an interactive rebase and amend each one.

## Related notes

+ [git_pull_rebase.md](git_pull_rebase.md), [git_cmds.md](git_cmds.md)
+ [Linux/ssh_login.md](Linux/ssh_login.md): SSH keys, which Git hosts use for authentication

## Reference

+ [git-config documentation (`includeIf`, `user.*`)](https://git-scm.com/docs/git-config)
+ [Pro Git book: First-Time Git Setup](https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup)
