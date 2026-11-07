# git pull: fast-forward, merge, or rebase

Examples were run with Git 2.43.

## 1. How `git pull` integrates

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

## 2. Rebase safely

+ Rebase only commits that you haven't pushed or shared. Rebased commits are new commits;
  others who have the old ones get duplicated history.
+ Rebase refuses to start with uncommitted changes (`error: ... Please commit or stash them.`).
  `git pull --rebase --autostash`, or `git config --global rebase.autoStash true`, stashes and reapplies them.
+ On a conflict: fix the files, `git add` them, then `git rebase --continue`. Or `git rebase --abort` to return to the state before the pull.
+ Undo a finished rebase: `git reset --hard ORIG_HEAD` (or `HEAD@{n}` from `git reflog`) moves the branch back.
  `reset --hard` discards uncommitted changes. More on the reflog in [git_cmds.md](git_cmds.md#2-recover-lost-commits-git-reflog).

```shell
git fetch && git status                  # "ahead 1, behind 2" = diverged
git log --oneline --graph --all -20      # see both histories before you choose
```

## Related notes

+ [git_identity.md](git_identity.md): `user.name`, `user.email`, per-directory identity
+ [git_cmds.md](git_cmds.md): log views, reflog, blame, `add -p`, `clean`
+ [Android/Googles_Repo.md](Android/Googles_Repo.md): `repo`, which runs Git across many repositories

## Reference

+ [git-pull documentation](https://git-scm.com/docs/git-pull)
+ [git-rebase documentation](https://git-scm.com/docs/git-rebase)
+ [git-config documentation (`pull.*`, `rebase.autoStash`)](https://git-scm.com/docs/git-config)
+ [Pro Git book: Rebasing](https://git-scm.com/book/en/v2/Git-Branching-Rebasing)
