# apt, apt-get, dpkg commands

## apt and apt-get

+ **apt** is a newer, high-level command-line tool designed for human interactive use,
+ while **apt-get** is an older, low-level tool optimized for stability and scripting.

They both manage software packages on Debian-based Linux systems, use the same repositories, and share identical download speeds.

## apt and dpkg

+ **apt** is a high-level package manager that downloads software from online repositories and **automatically resolves dependencies**,
+ while **dpkg** is a low-level package manager that **only installs individual, locally downloaded .deb files without managing their dependencies.**
  + after installing packages with dpkg, restore the dependencies with `sudo apt install -f`

## dpkg-query

`dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n`
