# update-alternatives: switch default commands (python, gcc, editor)

When several programs provide the same command (several Python or GCC versions, several editors),
Debian and Ubuntu use the **alternatives system** to decide which one runs by default.
`update-alternatives` (part of `dpkg`) creates, removes, displays and switches the symlinks behind it.
Examples were checked against Debian update-alternatives 1.21.1 (Ubuntu 22.04 / Jetson).
Fedora and RHEL ship a compatible tool named `alternatives`.

## 1. How it works

Each alternative group has a **name** (e.g. `editor`), a generic **link** (e.g. `/usr/bin/editor`)
and a set of registered **paths**, each with an integer **priority**. The link points through `/etc/alternatives/`:

```text
/usr/bin/editor  ->  /etc/alternatives/editor  ->  /usr/bin/vim.basic
 (generic link)        (altdir, one per name)       (selected path)
```

+ The state of every group is kept in the admin directory `/var/lib/dpkg/alternatives/<name>`.
+ A group is in one of two modes:
  + **auto**: the path with the **highest priority** is selected, and it is re-evaluated when packages are installed or removed.
  + **manual**: the path chosen with `--config` or `--set` stays selected, even if a higher-priority one is installed later.
+ **Slave links** (e.g. the man page) switch together with the master link.

## 2. Command reference

```shell
update-alternatives [options] <command>
```

Commands that change the system need `sudo`; the read-only ones (`--display`, `--query`, `--list`, `--get-selections`) don't.

| Command | Description |
| --- | --- |
| `--install <link> <name> <path> <priority>` | Register `<path>` in group `<name>` (creates the group if needed) |
| `--remove <name> <path>` | Unregister one path and its slaves. If it was selected, the group falls back to auto mode |
| `--remove-all <name>` | Remove the whole group |
| `--config <name>` | Show the registered paths and choose one interactively (sets manual mode) |
| `--set <name> <path>` | Select a path non-interactively (sets manual mode) |
| `--auto <name>` | Return to auto mode: the highest priority wins |
| `--display <name>` | Show mode, current selection, all paths with priorities and slaves |
| `--query <name>` | Same as `--display`, in a machine-readable format |
| `--list <name>` | List only the registered paths |
| `--get-selections` | List every group with its mode and current selection |

Useful options:

| Option | Meaning |
| --- | --- |
| `--verbose` / `--quiet` | More or less output (`--quiet` for scripts) |
| `--altdir <dir>` | Alternatives directory (default `/etc/alternatives`) |
| `--admindir <dir>` | Administrative state directory (default `/var/lib/dpkg/alternatives`) |
| `--force` | Replace a real file at `<link>` (normally refused). Use with care |

## 3. --install in detail

```shell
sudo update-alternatives --install <link> <name> <path> <priority> \
    [--slave <s-link> <s-name> <s-path>]...
```

+ `<link>`: the generic symlink, e.g. `/usr/bin/python`.
+ `<name>`: the group name, i.e. the file name under `/etc/alternatives/`, e.g. `python`.
+ `<path>`: the real binary to register, e.g. `/usr/bin/python3.12`. It must exist.
+ `<priority>`: integer; in auto mode the highest one is selected.
+ `--slave`: an extra link that follows the master, e.g. the man page or `g++` together with `gcc`.
  All paths of a group should declare the same slaves.

Paths are compared as strings, so `--set` and `--remove` must use exactly the path that was registered.
Check it with `--list` first: for example, Debian registers vim as `/usr/bin/vim.basic`, not `/usr/bin/vim`.

## 4. Example: editor

```shell
update-alternatives --list editor                    # see which paths are registered
update-alternatives --display editor                 # mode, current value, priorities
sudo update-alternatives --config editor             # pick one from a menu
sudo update-alternatives --set editor /usr/bin/vim.basic   # or select it directly
sudo update-alternatives --auto editor               # back to "highest priority wins"
```

To add an editor that its package didn't register:

```shell
sudo update-alternatives --install /usr/bin/editor editor /usr/bin/code 10
```

## 5. Example: python

```shell
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.10 10
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.12 20

update-alternatives --display python        # auto mode -> python3.12 (priority 20)
sudo update-alternatives --config python    # choose python3.10 interactively (manual mode)
sudo update-alternatives --remove python /usr/bin/python3.10
```

`--config` shows a menu like this; enter the selection number, or press Enter to keep the current choice:

```text
  Selection    Path                 Priority   Status
------------------------------------------------------------
* 0            /usr/bin/python3.12   20        auto mode
  1            /usr/bin/python3.10   10        manual mode
  2            /usr/bin/python3.12   20        manual mode
```

Caveats:

+ **Never redirect `/usr/bin/python3`.** apt, `add-apt-repository`, `ufw`, `lsb_release` and other system tools
  run with `#!/usr/bin/python3` and need the distribution's Python version and its modules.
  Switching `python3` to another version can break them. Only manage the unversioned `python` name, if anything.
+ On Ubuntu 20.04 and later, `/usr/bin/python` may already be provided by the `python-is-python3` package
  (`dpkg -S /usr/bin/python`). Don't let a package and the alternatives system manage the same link:
  either keep the package, or remove it before creating a `python` group.
+ For project work, don't change system defaults at all:
  use a virtual environment (`python3 -m venv .venv`) per project,
  or a user-space version manager such as `pyenv` when you need many Python versions.

## 6. Example: gcc with g++ as a slave

Switch the C and C++ compilers together, so `gcc` and `g++` never come from different versions:

```shell
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-11
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 120 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-12

sudo update-alternatives --config gcc
gcc --version && g++ --version
```

If `/usr/bin/gcc` is a symlink owned by a package (e.g. `gcc` on Ubuntu), apt may overwrite it on upgrade;
re-run `--auto gcc` or `--config gcc` afterwards if needed.

## Related notes

+ [apt_dpkg_cmd.md](apt_dpkg_cmd.md): apt and dpkg, which also provide update-alternatives
+ [ufw_cmds.md](ufw_cmds.md): ufw, one of the system tools that depends on the system `python3`

## Reference

+ [update-alternatives(1) man page](https://manpages.debian.org/stable/dpkg/update-alternatives.1.en.html)
+ [Debian Wiki: DebianAlternatives](https://wiki.debian.org/DebianAlternatives)
