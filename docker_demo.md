# docker usage

Install Docker Engine on Ubuntu

[docker](https://docs.docker.com/engine/install/ubuntu/)
[docker_wiki](https://en.wikipedia.org/wiki/Docker_(software))

## check the versions of these Docker CLI binary

`docker compose version`  
`docker --version`  
`docker version`  
`docker --help`  
`docker container --help`

## basic command

+ List containers: `docker container ls`
+ List containers: `docker ps`
+ list images: `docker images`
+ Download an image from a registry: `docker pull ubuntu:18.04`
+ Create and run a new **container** from an image: `docker run -d --rm -it --name containerName ubuntu:18.04 bash`
+ Execute a command in a running container: `docker exec -it containerName bash`
+ To get the container's OS details: `cat /etc/os-release`

## stop containers

+ List containers: `docker ps -a`
+ Stop containers: `docker stop [CONTAINER_ID_OR_NAME]`
+ Remove containers: `docker rm [CONTAINER_ID_OR_NAME]`

## list, remove images

+ `docker image ls`
+ `docker rmi <image_id>`
+ `docker rmi <repository_name>:<tag>`
+ `docker search ubuntu -f is-official=true`

## compile xpi3566

## others

+ The default Docker root directory is /var/lib/docker
+ Download an image from a registry: `docker pull ubuntu:20.04`
+ see the IP of the container: `cat /etc/hosts`

### copy files to/from container

+ `docker cp <local_path> <container_name_or_id>:<container_path>`
+ `docker cp rk3566-xpi-debian10-avalue ubuntu1804:home`
