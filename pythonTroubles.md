# python troubles

[RefWeb](https://www.pantechsolutions.net/blog/installing-library-packages-in-raspberry-pi/)

By default, Raspbian (Stretch version April 2018 and earlier) uses Python 2.  
However, versions 2 and 3 come installed by default. We just have to make 1 minor change so that the Pi uses Python 3 whenever we type python into a terminal.

1. querry python version  
  `python --version`

2. edit ~/.bashrc and add folling line  
  `alias python='/usr/bin/python3'`

3. No module named 'matplotlib'  
  `sudo pip3 install matplotlib`

4. fail to import numpy.  
  `sudo apt-get install libatlas-base-dev`

The below commands are for updating every applications or package which already installed.  
`sudo apt-get update`  
`sudo apt-get upgrade`
