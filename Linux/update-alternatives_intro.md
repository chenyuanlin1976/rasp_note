# update-alternatives intro

If you work on Linux systems (particularly Debian or Ubuntu-based distributions),  
you will often encounter situations where you need multiple versions of Python installed simultaneously.  
The `update-alternatives` command is a built-in system tool designed precisely to manage these competing versions  
and determine which one runs by default when you type python or python3 in your terminal.

## What is update-alternatives?

`update-alternatives` creates, removes, maintains, and displays information  
about the symbolic links comprising the Debian alternatives system.  
When multiple programs fulfill the same function (like different versions of Python),  
the system uses symlinks managed by this tool to point to the active default.

## How to Use update-alternatives for Python

Below is a practical guide on how to register, configure, and switch between Python versions using the tool.

1. Registering Python Versions:  
   + Before you can switch between versions, you need to register them with the alternatives system,  
     assigning each a priority (**higher numbers mean higher priority**):  
     Syntax: **`sudo update-alternatives --install <link> <name> <path> <priority>`**
     `sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.10 10`  
     `sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.12 20`  
2. Configuring and Switching Versions:
   + To interactively choose which version should be the default, run the configuration command:  
     `sudo update-alternatives --config python`  
     You will see an interactive menu listing the registered versions.  
     You can simply enter the selection number corresponding to the version you want to activate.
3. Checking Current Status:  
   To view the current status and links configured for Python, use:  
   `sudo update-alternatives --display python`
4. Removing an Alternative:  
   `sudo update-alternatives --remove python /usr/bin/python3.10`

## Best Practices and Caveats

+ Note on Modern Development: While update-alternatives is fantastic for setting system-wide defaults  
  (which system tools and scripts might rely on), it is generally not recommended for managing project-specific environments.
+ Use Virtual Environments (venv): For developing Python applications, always rely on venv or virtualenv to keep dependencies isolated per project.
+ Consider pyenv: If you frequently need to switch between many different Python versions for development  
  without messing with system packages, tools like pyenv offer a more flexible, user-space alternative.
+ Avoid Breaking System Python: On many modern Linux distributions,  
  modifying the system-wide `/usr/bin/python` symlink carelessly can break package managers or system utilities (like apt or ufw)  
  that depend on a specific Python version. Always be cautious when altering global defaults.

## Basic Syntax Structure

`sudo update-alternatives [options] <command>`

### Core Commands

| Command   | Description                                                                            | Example                                         |
| --------- | -------------------------------------------------------------------------------------- | ----------------------------------------------- |
| --install | Adds a group of alternatives to the system.                                            | NOTE_1                                          |
| --remove  | Removes an alternative and its associated slaves from the group.                       | sudo update-alternatives --remove <name> <path> |
| --config  | Displays choices for a given name and prompts you to select the default interactively. | sudo update-alternatives --config <name>        |
| --display | Displays detailed information about a specific alternative group.                      | sudo update-alternatives --display <name>       |
| --list    | Lists all targets of the alternatives group.                                           | sudo update-alternatives --list <name>          |
| --auto    | Switches an alternative group to automatic mode (highest priority wins).               | sudo update-alternatives --auto <name>          |
| --set     | Manually sets an alternative path without interactive prompts.                         | sudo update-alternatives --set <name> <path>    |

NOTE_1: `sudo update-alternatives --install <link> <name> <path> <priority>`

## Detailed Breakdown of --install Syntax

Syntax: `sudo update-alternatives --install <link> <name> <path> <priority> [--slave <s-link> <s-name> <s-path>]...`

+ <link>: The generic/master symlink path managed by the system (e.g., /usr/bin/python).
+ <name>: The generic name used in the alternatives directory (e.g., python).
+ <path>: The absolute path to the specific binary/file you are registering (e.g., /usr/bin/python3.12).
+ <priority>: An integer value. When the group is in automatic mode, the alternative with the highest priority number is automatically selected.
+ --slave (Optional): Allows you to link secondary files that should change alongside the master  
  (e.g., linking python.1.gz manual pages along with the binary).

## Important Options

You can combine these flags with your commands:

+ --verbose: Generates more detailed explanation output about what the command is doing.
+ --quiet: Generates little or no output, useful for automated scripts.
+ --altdir <directory>: Specifies the alternatives directory (defaults to /etc/alternatives).
+ --admindir <directory>: Specifies the administrative directory containing state info (defaults to /var/lib/dpkg/alternatives).

## Quick Reference Examples

+ Registering an alternative: `sudo update-alternatives --install /usr/bin/editor editor /usr/bin/vim 60`
+ Interactively configuring the default: `sudo update-alternatives --config editor`
+ Forcing a specific path non-interactively: `sudo update-alternatives --set editor /usr/bin/nano`
