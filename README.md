# LEMP-setup-guide
Scripts &amp; Guide for LEMP stack with Pagespeed and http2 modules - on ubuntu 16.04.4

## Using the scripts

Recommended to ssh into your server with agent forwarding ie `ssh root@yourip -A`

```
sudo apt-get install wget
wget https://raw.githubusercontent.com/amurrell/LEMP-setup-guide/master/install/install
sudo chmod +x install
./install
```

## Use SimpleDocker to test script

[SimpleDocker](https://github.com/amurrell/SimpleDocker) is just an ubuntu 16.04 Docker Container that you can use to test the scripts in the scripts folder.

Just clone into the root directory of this project and alter the docker-compose.yml file to make the volume like:

```
volumes:
            - ../:/var/www/LEMP-setup-guide
```
