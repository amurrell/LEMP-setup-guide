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

---

### During & After The Script

- You'll get prompted for your ssh public key (to setup authorized keys for easier ssh access)

- You'll get prompted to setup mariadb password, just use "password" for now. After everything is installed, you can run `sudo mysql_secure_installation` and follow prompts to remove test databases, anonymous users, and change the root password to something more secure.

- If you choose to **skip setting up a site**, you can always run the setup-site script later from `/var/www/LEMP-setup-guide/scripts/`. You can setup multiple sites using this script, one per run.

---

## Use SimpleDocker to test script

[SimpleDocker](https://github.com/amurrell/SimpleDocker) is just an ubuntu 16.04 Docker Container that you can use to test the scripts in the scripts folder.

Just clone SimpleDocker into the root directory of this LEMP project and alter the docker-compose.yml file to make the volume like:

```
volumes:
            - ../:/var/www/LEMP-setup-guide
```
