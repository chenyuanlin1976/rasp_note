# Ubuntu
sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3

[RefWeb](https://www.makeuseof.com/install-python-ubuntu/)

# Raspberry Pi 
`wget https://www.python.org/ftp/python/3.9.9/Python-3.9.9.tgz`
`tar -zxvf Python-3.9.9.tgz`
`cd Python-3.9.9`
`./configure --enable-optimizations`
`sudo make altinstall`
`cd usr/bin`
`sudo rm python`
`sudo ln -s /usr/local/bin/python3.9 python`
`python --version`

[RefWeb](https://linuxhint.com/update-python-raspberry-pi/)
