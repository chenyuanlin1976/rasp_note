# ssh login

[RefWebsite](https://www.raspberrypi.org/documentation/computers/remote-access.html)

login command: `ssh login user@hostname`

## example

1. create public key and private key at ~/.ssh
2. Copy your public key to server; and next time, you can login without typing password.  
`ssh-keygen`  
`ssh-copy-id your_key_path user@server_host`

## copy file between local and  remote server

`scp user@remote_hostname:~/Downloads/srcFile D:\dstFileCopy`  
`scp srcFile user@dst_hostname:~/folder/dstFile`  
`scp -r D:\test\* user@remote_hostname:~/folder/`

## rsync command

`sudo apt install rsync`

`rsync -avh ~/myPath/mySrcFile pi@raspberrypi:~/dstFolder/`

`rsync -avh -e ssh ~/myPath/mySrcFile pi@raspberrypi:~/dstFolder/`  
`rsync -avh -e 'ssh -i ~/myAuthorizedKey' ~/myPath/mySrcFile pi@raspberrypi:~/dstFolder/`

## get ip address

`hostname -I`  
`ifconfig`  
`ip addr`

## using putty

Host name: raspberrypi  
name: pi  
password: raspberry
