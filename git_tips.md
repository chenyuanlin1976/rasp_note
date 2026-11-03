# Git tips: pull strategies and identity

Examples were run with Git 2.43.

## 1. `git pull`: fast-forward, merge, or rebase

`git pull` = `git fetch` (download the remote branch) + integrate it into the current branch.
How it integrates depends on whether the two histories have **diverged**:

```text
Behind only (no local commits)      Diverged (both sides have new commits)

origin:  A---B---C                  origin:  A---B---C
local:   A                          local:   A---X

fast-forward: local -> C            merge:   A---B---C---M      rebase:  A---B---C---X'
                                              \         /
                                               X-------
```

+ **Fast-forward** isn't an integration: Git only moves the branch pointer forward. No new commit, no conflicts.
+ When the branches have diverged, Git must **merge** (a merge commit `M` with two parents)
  or **rebase** (replay the local commits on top of the remote ones as new commits `X'`, with new hashes).
+ If nothing is configured and the branches have diverged, current Git stops with
  `fatal: Need to specify how to reconcile divergent branches.` Choose a default:

| Behavior when diverged | One time | Default (`--global` = all repos; without it, this repo only) |
| --- | --- | --- |
| Refuse: `fatal: Not possible to fast-forward, aborting.` | `git pull --ff-only` | `git config --global pull.ff only` |
| Merge commit | `git pull --no-rebase` | `git config --global pull.rebase false` |
| Rebase local commits | `git pull --rebase` | `git config --global pull.rebase true` |

+ A command-line option overrides the configuration: with `pull.ff only` set, `git pull --rebase` still rebases.
+ Don't set both `pull.ff only` and `pull.rebase true`: a plain `git pull` then still refuses diverged branches.
+ A practical default: `pull.ff only`. When it refuses, decide: `git pull --rebase` if the local commits are only yours,
  or `git pull --no-rebase` to keep them as they are with a merge commit.

### 1.1 Rebase safely

+ Rebase only commits that you haven't pushed or shared. Rebased commits are new commits;
  others who have the old ones get duplicated history.
+ Rebase refuses to start with uncommitted changes (`error: ... Please commit or stash them.`).
  `git pull --rebase --autostash`, or `git config --global rebase.autoStash true`, stashes and reapplies them.
+ On a conflict: fix the files, `git add` them, then `git rebase --continue`. Or `git rebase --abort` to return to the state before the pull.
+ Undo a finished rebase: `git reflog` lists the previous positions of `HEAD`; `git reset --hard ORIG_HEAD`
  (or `HEAD@{n}` from the reflog) moves the branch back. `reset --hard` discards uncommitted changes.

```shell
git fetch && git status                  # "ahead 1, behind 2" = diverged
git log --oneline --graph --all -20      # see both histories before you choose
```

## 2. Identity: `user.name` and `user.email`

Every commit records an author name and email. They are plain text, not a login:
authentication to GitHub or Gerrit uses SSH keys or tokens, configured separately.

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

### 2.1 A different identity per directory

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

### 2.2 Fix the author of the last commit

```shell
git config user.email "you@company.example"
git commit --amend --reset-author --no-edit          # rewrite the last commit with the current identity
```

Like a rebase, this creates a new commit: do it before pushing.
For older commits, use an interactive rebase and amend each one.

## Related notes

+ [Android/Googles_Repo.md](Android/Googles_Repo.md): `repo`, which runs Git across many repositories
+ [Linux/ssh_login.md](Linux/ssh_login.md)

## Reference

+ [git-pull documentation](https://git-scm.com/docs/git-pull)
+ [git-rebase documentation](https://git-scm.com/docs/git-rebase)
+ [git-config documentation (`includeIf`, `pull.*`, `rebase.autoStash`)](https://git-scm.com/docs/git-config)
+ [Pro Git book: Rebasing](https://git-scm.com/book/en/v2/Git-Branching-Rebasing)
