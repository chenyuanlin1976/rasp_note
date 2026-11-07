# apt, apt-get and dpkg: package management on Debian/Ubuntu

Debian-based systems (Debian, Ubuntu, Raspberry Pi OS, Jetson Linux) manage software as `.deb` packages,
with tools on two layers: **apt** / **apt-get** on top and **dpkg** below.
Examples were checked against apt 2.4 and dpkg 1.21 (Ubuntu 22.04).

## 1. The tools

| Tool | Level | What it does |
| --- | --- | --- |
| `apt` | High | Downloads packages from repositories and **resolves dependencies**. Made for interactive use: progress bar, colors, short commands |
| `apt-get`, `apt-cache` | High | Same engine and repositories as `apt`, but with a stable output format and options. Use them in scripts |
| `dpkg` | Low | Installs, removes and inspects `.deb` files that are already on disk. **Doesn't download or resolve dependencies** |
| `dpkg-query` | Low | Queries the database of installed packages |

`apt` and `apt-get` use the same repositories and download the same packages, so neither is faster.
`apt` prints "WARNING: apt does not have a stable CLI interface" when its output is piped: in scripts, use `apt-get`.

## 2. apt: everyday commands

```shell
sudo apt update                       # refresh the package lists from the repositories
sudo apt upgrade                      # upgrade installed packages
sudo apt full-upgrade                 # upgrade, also adding/removing packages if needed
sudo apt install <pkg>                # install with dependencies
sudo apt remove <pkg>                 # remove, keep config files
sudo apt purge <pkg>                  # remove including system-wide config files
sudo apt autoremove                   # remove dependencies that are no longer needed
apt search <keyword>                  # search names and descriptions
apt show <pkg>                        # version, size, dependencies, description
apt list --installed                  # all installed packages
apt list --upgradable                 # packages with a pending upgrade
apt download <pkg>                    # fetch the .deb into the current directory (no sudo)
```

| apt | apt-get / apt-cache equivalent |
| --- | --- |
| `apt install`, `remove`, `purge`, `update`, `upgrade`, `autoremove` | `apt-get` with the same subcommand |
| `apt full-upgrade` | `apt-get dist-upgrade` |
| `apt search`, `apt show` | `apt-cache search`, `apt-cache show` |
| `apt list --installed` | `dpkg -l` |

## 3. Installing a local .deb file

Prefer apt, which resolves the dependencies:

```shell
sudo apt install ./package.deb        # the ./ (or any path) is required, otherwise apt looks up a package name
```

With dpkg, dependencies are not installed. If some are missing, the package is left unconfigured;
`apt -f install` (`--fix-broken`) then installs the missing dependencies and finishes the setup:

```shell
sudo dpkg -i package.deb
sudo apt -f install
```

## 4. dpkg and dpkg-query: inspecting packages

```shell
dpkg -l                               # list installed packages (status, version, arch)
dpkg -l '*python3*'                   # list matching packages
dpkg -L <pkg>                         # files installed by a package
dpkg -S /usr/bin/xxd                  # which package owns a file
dpkg -s <pkg>                         # status and details of an installed package
dpkg -c package.deb                   # files inside a .deb (not installed)
dpkg -I package.deb                   # control information of a .deb
sudo dpkg -r <pkg>                    # remove (dpkg -P = purge)
```

In `dpkg -l`, the first column `ii` means "desired: install, status: installed"; `rc` means removed with config files left over.

List installed packages by size (`Installed-Size` is in KiB), largest last:

```shell
dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n
```

## Related notes

+ [update-alternatives_cmds.md](update-alternatives_cmds.md): switching default commands; part of dpkg
+ [static_shared_lib.md](static_shared_lib.md): `-dev` packages that provide headers and linker names
+ [../shellScript/linux_cmds.md](../shellScript/linux_cmds.md): Linux command cheat sheet

## Reference

+ [apt(8) man page](https://manpages.debian.org/stable/apt/apt.8.en.html)
+ [dpkg(1) man page](https://manpages.debian.org/stable/dpkg/dpkg.1.en.html)
+ [dpkg-query(1) man page](https://manpages.debian.org/stable/dpkg/dpkg-query.1.en.html)
+ [Debian Reference: Debian package management](https://www.debian.org/doc/manuals/debian-reference/ch02.en.html)
