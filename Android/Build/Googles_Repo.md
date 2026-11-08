# repo: managing many Git repositories

`repo` is Google's command-line tool (written in Python) that manages a source tree made of **many Git repositories**.
AOSP has more than a thousand of them: frameworks, HALs, external libraries, toolchains, prebuilts.
`repo` doesn't replace Git: each project is a normal Git repository, and `repo` runs Git across all of them.
SoC vendor SDKs (Rockchip, Qualcomm, ...) and kernel trees use it too.

Installing `repo` and downloading AOSP: [AOSP_build.md](AOSP_build.md#2-install-repo).

## 1. The manifest

A **manifest** is an XML file that lists every project: its Git repository, its path in the tree, and the revision to check out.
It lives in its own Git repository (for AOSP: `platform/manifest`), and `repo init -b <branch>` selects a branch of it.

```xml
<manifest>
  <remote name="aosp" fetch="https://android.googlesource.com/" />
  <default remote="aosp" revision="refs/heads/android-latest-release" sync-j="4" />

  <project path="frameworks/base" name="platform/frameworks/base" />
  <project path="device/myco/myboard" name="myco/device-myboard" remote="myco" revision="main" />
</manifest>
```

```text
aosp/
├── .repo/
│   ├── manifests/            # the manifest repository (default.xml, ...)
│   ├── local_manifests/      # your own additions (optional, *.xml)
│   ├── projects/, project-objects/   # the Git data of each project
│   └── repo/                 # the repo tool itself
├── frameworks/base/          # checked-out projects
└── ...
```

**Local manifests** (`.repo/local_manifests/*.xml`) add projects or remotes, or remove projects (`<remove-project>`),
without changing the official manifest. Use them for a board's device tree, vendor HALs, or private apps.

## 2. Commands

| Command | Does |
| --- | --- |
| `repo init -u <manifest-url> -b <branch> [--partial-clone] [-g <groups>]` | Set up `.repo/` in the current directory |
| `repo sync -c -j8` | Fetch and update all projects (`-c`: current branch only) |
| `repo sync -l` / `repo sync -n` | Only update the working trees from what is already fetched / only fetch |
| `repo sync --force-sync <project>` | Recover a project whose Git data no longer matches (for example after a manifest change) |
| `repo start <topic> [--all \| <projects>]` | Create a topic branch for your work (at the manifest revision) |
| `repo status`, `repo diff` | Changes in all projects |
| `repo branches`, `repo prune`, `repo abandon <topic>` | List topic branches / delete merged ones / delete one |
| `repo forall [<projects>] -c '<cmd>'` | Run a command in each project (`$REPO_PROJECT`, `$REPO_PATH`, ... are set) |
| `repo upload` | Send commits to the Gerrit code-review server named in the manifest |
| `repo manifest -r -o snapshot.xml` | Write a manifest that pins every project to its current commit |

Examples:

```shell
repo forall -c 'git log --oneline -1'                  # last commit of every project
repo forall -p -c 'git status --short'                 # -p: print each project's name
repo manifest -r -o release-2026-11-03.xml              # record exactly what was built
repo init -m release-2026-11-03.xml && repo sync        # later: reproduce that tree (file copied into .repo/manifests/)
```

## 3. Contribution workflow (AOSP / Gerrit)

1. `repo start my-fix frameworks/base` creates a topic branch in the project you'll change.
2. Edit, `git add`, `git commit`. Commits need a `Change-Id` line; the Gerrit commit-msg hook adds it.
3. `repo upload` sends the commits to Gerrit for review.
4. After review, `repo sync` and `repo prune` remove the merged topic branch.

`repo sync` updates the projects one by one. It isn't atomic: if it fails halfway (network, local changes), some projects are new and others old.
Run it again until it finishes cleanly before you build.

## Related notes

+ [AOSP_build.md](AOSP_build.md), [AOSP_build_system.md](AOSP_build_system.md), [../../DevTools/git_pull_rebase.md](../../DevTools/git_pull_rebase.md), [../../DevTools/git_cmds.md](../../DevTools/git_cmds.md)

## Reference

+ [Repo command reference (AOSP)](https://source.android.com/docs/setup/reference/repo)
+ [Source control workflow (AOSP)](https://source.android.com/docs/setup/create/coding-tasks)
+ [Manifest format, local manifests (git-repo)](https://gerrit.googlesource.com/git-repo/+/HEAD/docs/manifest-format.md)
