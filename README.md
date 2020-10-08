# LEMP-setup-guide
Scripts &amp; Guide for LEMP stack with Pagespeed and http2 modules - on ubuntu 18.04 or 16.04.4

Also includes scripts for setting up a site with php streams/database or via proxy, logrotate, certbot (with cron, but won't interfere with nginx from source).

## Start using the scripts

Recommended to ssh into your server with agent forwarding ie `ssh root@yourip -A`

### Ubuntu 18.04 LTS, Nginx 1.15.9, mod_pagespeed 1.13.35.2-stable, php 7.3, mariadb 10.3
```
sudo apt-get install wget
wget https://raw.githubusercontent.com/amurrell/LEMP-setup-guide/master/install/install-upgraded
sudo chmod +x install-upgraded
./install-upgraded
```

### Ubuntu 16.04 LTS, Nginx 1.10.1, mod_pagespeed 1.11.33.2, php 7.2, mariadb 10.3
```
sudo apt-get install wget
wget https://raw.githubusercontent.com/amurrell/LEMP-setup-guide/master/install/install
sudo chmod +x install
./install
```

---

### During & After The Script

- You'll get prompted for your ssh public key (to setup authorized keys for easier ssh access)

- (Only on 16.04 install,) You'll get prompted to setup mariadb password, just use "password" for now. After everything is installed, you can run `sudo mysql_secure_installation` and follow prompts to remove test databases, anonymous users, and change the root password to something more secure.

- If you choose to **skip setting up a site**, you can always run the setup-site script later from `/var/www/LEMP-setup-guide/scripts/`. You can setup multiple sites using this script, one per run.

---

## Other Scripts & Components

### Scripts

The following scripts are used "per site" that you want to setup on your server. They prompt and guide you through their functionality.

- **setup-site** - sets up a site based on git repo, creates nginx / php as needed
- **setup-logrotate** (needs logrotate command and syslog user)
- **install-cert** - sets up certbot for ssl on your site, with option to update nginx or not - creates a cronjob to keep fetching. ideal if you want control over how certbot affects nginx conf files.

### Installable Components
There are also **components** in the `install` folder, which allow you to install other specific common tools, as well as your own custom scripts. 

- composer
- pm2
- nvm
- redis
- postgressql
- custom

### Custom Scripts

The custom scripts have a `install` file that will loop through scripts in the `scripts` folder. You can name these with numbers to create an order of when they will run. 

- **install** -  (running this will loop through scripts in `/scripts`
- **/scripts** - Add bash scripts here, make sure to `chmod +x` them. eg. `000-running-custom-scripts.sh`

---

## Use SimpleDocker to test script

[SimpleDocker](https://github.com/amurrell/SimpleDocker) is just an ubuntu 16.04 or 18.04 Docker Container that you can use to test the scripts in the scripts folder.

Just clone SimpleDocker into the root directory of this LEMP project and alter the docker-compose.yml file to make the volume like:

```
volumes:
            - ../:/var/www/LEMP-setup-guide
```

Change the branch to 18.04 to use that version of SimpleDocker.

If testing with simple docker, you'll need to install `apt-get -y install rsyslog` and `apt-get -y install logrotate` to use setup-logrorate.
