# Useful Git commands: history, recovery, and cleanup

Built-in commands for viewing history, recovering lost commits, finding who changed what,
staging part of a change, and cleaning the work tree.

## 1. View history (`git log`)

```shell
git log --oneline --graph --decorate --all      # compact graph of every branch
git log -p -n 3 -- <file>                       # last 3 commits that touched <file>, with their diffs
git log --follow -- <file>                      # history across renames
```

| Option | Effect |
| --- | --- |
| `--oneline` | One line per commit: short hash + subject |
| `--graph` | Text drawing of branches and merges |
| `--decorate` | Branch, tag, and `HEAD` names next to commits (on by default in a terminal since Git 2.13) |
| `--all` | All branches and tags, not only the current branch |
| `-p` | Show the patch (diff) of each commit |
| `-n <N>` | Limit to N commits |
| `-- <path>` | Only commits that touch that path |

An alias saves typing:

```shell
git config --global alias.lg "log --oneline --graph --decorate --all"
git lg
```

## 2. Recover lost commits (`git reflog`)

The reflog records every position of `HEAD` (and of each branch): commits, checkouts, resets, rebases, amends.
A commit that no branch points to any more, after a bad `reset --hard` or rebase, is still listed there.

```shell
git reflog                          # HEAD@{0} = now, HEAD@{1} = before the last move, ...
git branch rescue HEAD@{5}          # safe: keep the old state on a new branch
git reset --hard HEAD@{5}           # or move the current branch back (discards uncommitted changes)
```

+ The reflog is **local** to your clone; it isn't pushed or cloned.
+ Entries expire: by default after 90 days, or 30 days for commits that are no longer reachable (`gc.reflogExpire`, `gc.reflogExpireUnreachable`).
+ Uncommitted changes were never in a commit, so the reflog can't recover them.

## 3. Find who changed what (`git log -S`/`-G`, `git blame`)

```shell
git log -S "search_term"            # commits that add or remove that string (the "pickaxe")
git log -G "regex" -p               # commits whose diff has a changed line matching the regex
git blame <file>                    # last commit, author, and date for each line
git blame -L 40,60 <file>           # only lines 40-60
```

+ `-S` matches when the **number of occurrences** of the string changes, so it finds where a function was introduced or removed.
  A commit that only moves the string within a file isn't listed; `-G` lists it.
+ `git blame` shows who touched a line last, which may be a reformat. `git blame -w` ignores whitespace changes,
  and `git log -L 40,60:<file>` shows the full history of a line range.

## 4. Stage part of a change (`git add -p`)

```shell
git add -p                          # walk through each hunk of the unstaged changes
git add -p <file>                   # only that file
```

For each hunk, Git asks: `y` stage, `n` skip, `s` split into smaller hunks, `e` edit the hunk by hand, `q` quit, `?` help.
Check the result with `git diff --staged` before you commit.
`git restore -p` (discard) and `git reset -p` (unstage) work the same way.

## 5. Remove untracked files (`git clean`)

```shell
git clean -nd                       # dry run: list untracked files and directories
git clean -fd                       # delete them
git clean -fdx                      # also delete ignored files (build outputs, node_modules, ...)
git clean -fdX                      # delete ONLY ignored files
```

`git clean` deletes files that Git never tracked, so they can't be restored from Git. Always run `-n` first.
By default it refuses to run without `-f` (`clean.requireForce`).

## Related notes

+ [git_pull_rebase.md](git_pull_rebase.md): pull strategies and safe rebasing
+ [git_identity.md](git_identity.md)
+ [Android/Googles_Repo.md](Android/Googles_Repo.md)

## Reference

+ [git-log documentation](https://git-scm.com/docs/git-log)
+ [git-reflog documentation](https://git-scm.com/docs/git-reflog)
+ [git-blame documentation](https://git-scm.com/docs/git-blame)
+ [git-add documentation](https://git-scm.com/docs/git-add)
+ [git-clean documentation](https://git-scm.com/docs/git-clean)
