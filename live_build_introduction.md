# live build introduction

[live-build](https://manpages.debian.org/testing/live-build/index.html)
[lb_config](https://manpages.debian.org/testing/live-build/lb_config.1.en.html)

live-build is a set of scripts to build live system images.  
The idea behind live-build is a tool suite that uses a configuration directory to completely automate and customize all aspects of building a Live image.

## lb options

+ `lb config`   : populates the configuration directory for live-build. This directory is named 'config' and is created in the current directory where lb config was executed.
+ `lb build`    : calls all necessary live-build programs in the correct order to complete the bootstrap, chroot, installer, binary, and source stages.
+ `lb bootstrap`: calls all necessary live-build programs in the correct order to complete the **bootstrap stage**.
+ `lb chroot`   : calls all necessary live-build programs in the correct order to complete the **chroot stage**.
+ `lb installer`: calls all necessary live-build programs in the correct order to complete the **installer stage**.
+ `lb binary`   : calls all necessary live-build programs in the correct order to complete the **binary stage**.
+ `lb source`   : calls all necessary live-build programs in the correct order to complete the **source stage**.

## lb_config optionns

1. **--debian-installer-gui**: defines whether the graphical version of the debian-installer should be provided alongside the text based one. This defaults to true.
