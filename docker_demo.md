# docker usage

Install Docker Engine on Ubuntu

[docker](https://docs.docker.com/engine/install/ubuntu/)
[docker_wiki](https://en.wikipedia.org/wiki/Docker_(software))

## check the versions of these Docker CLI binary

`docker compose version`  
`docker version`  
`docker --version`  
`docker --help`  
`docker container --help`  
`docker image --help`  
`docker search --help`  

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
+ Start one or more stopped containers: `docker start containers`
+ Stop one or more running containers: `docker stop [CONTAINER_ID_OR_NAME]`
+ Remove containers: `docker rm [CONTAINER_ID_OR_NAME]`

## list, remove images

+ List images: `docker images` or `docker image ls`
+ Removing a specific image by ID or name: `docker rmi <image_id>` or `docker rmi <repository_name>:<tag>`
+ Search Docker Hub for images: `docker search ubuntu -f is-official=true`

## others

+ The default Docker root directory is **/var/lib/docker**
+ Download an image from a registry: `docker pull ubuntu:20.04`
+ see the IP of the container: `cat /etc/hosts`

### Copy files/folders between a container and the local filesystem

+ `docker cp --help`
+ `docker cp <local_path> <container_name_or_id>:<container_path>`
+ `docker cp rk3566-xpi-debian10-avalue ubuntu1804:home`
