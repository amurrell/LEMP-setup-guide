# Easy-to-Use LEMP Setup Guide

🙌 This guide offers a streamlined provisioning script to help you easily install a LEMP stack (Nginx, MariaDB/MySQL, PHP) on LTS Ubuntu (18.04, 20.04, 22.04). It also includes individual "adhoc" scripts for quickly setting up websites, managing logs, installing SSL certificates, and adding other helpful tools.

You can also incorporate this LEMP setup guide into other provisioning scripts. See how to do it with [SimpleDocker](https://github.com/amurrell/SimpleDocker).

## Features

### Initial Installation
- **Nginx**: Built from source, includes Pagespeed module
- **MariaDB/MySQL**: Comes with MariaDB by default
- **PHP**: Includes PHP-FPM for better performance

### Additional Scripts
- **Website Setup**: Automates the setup of a new website, including configurations for Nginx, PHP, and database credentials.
- **Log Management**: Helps manage server logs to prevent them from becoming too large.
- **SSL Certificates**: Uses Certbot to automatically secure your site with SSL.
- **Extra Tools**: Includes optional installations for Composer, NVM, PM2, Redis, and PostgreSQL for more tooling resources.

## Default Software Versions

These are the versions installed by default, but you can easily change them:

- MariaDB: 10.11 (LTS)
- Nginx: 1.24.0 (Stable)
- OpenSSL: 3.0.10 (LTS)
- Pagespeed: 1.15.0.0-8917 (master branch) - _(recommend using 1.13.35.2-stable for nginx < 1.23.0)_
- PHP: 8.2

### Customizing Versions
If you want to use different versions of the software, navigate to the `config/versions` folder. Create new files with the prefix `override-`, like `override-php-version`, and follow the [detailed setup guide](#setup-guide-with-overrides) to implement your changes.

---

## Quick start

This method accepts the default versions. [Read the setup guide for using overrides here](#setup-guide-with-overrides).

### SSH into your server:

This is where you want to setup the environment.

Recommended to ssh into your server with agent forwarding ie `ssh root@yourip -A`. However, it is recommended to use deploy keys if you want to use git repos in automated provisioning scripts.

### CD & Paste:

`cd /var/www/`, or where you want your websites to live.

```
sudo apt-get install wget
wget https://raw.githubusercontent.com/amurrell/LEMP-setup-guide/main/install/install
sudo chmod +x install
./install
```

Jump down to: [During & After The Script](#during--after-the-script)

---

## Setup Guide With Overrides

### SSH & cd into preferred folder

First, `ssh` into your server and navigate to your website installation location, eg. `cd /var/www/`.

Recommended to ssh into your server with agent forwarding ie `ssh root@yourip -A` if you are not planning to use deployment keys for your projects.

### Clone the repo

```
git clone https://github.com/amurrell/LEMP-setup-guide.git
```

### Update your versions

```
cd LEMP-setup-guide/config/versions

# see the services
ls

# look at one of them
cat php-version

# create override file
echo "8.0" > override-php-version
```

### Run the install script

After you're done overriding versions, you can install!

```
cd scripts
chmod +x server-initial-setup.sh
./server-initial-setup.sh
```
---

### During & After The Script

- You'll get prompted for your ssh public key (to setup authorized keys for easier ssh access)

- (Only on 16.04 install,) You'll get prompted to setup mariadb/mysql password, just use "password" for now.

- After everything is installed, you can run `sudo mysql_secure_installation` (or `sudo mariadb_secure_installation`) and follow prompts to remove test databases, anonymous users, and change the root password to something more secure.

- If you choose to **skip setting up a site**, you can always run the setup-site script later from `/var/www/LEMP-setup-guide/scripts/`. You can setup multiple sites using this script, one per run.

---

## Other Scripts & Components

### Scripts

The following scripts are used "per site" that you want to setup on your server. They prompt and guide you through their functionality.

- **setup-site** - sets up a site based on git repo, creates nginx / php as needed.

  This script can also take flags to support provisioning script use cases of this repo.

  For more info, run `./setup-site --help`, or the table below.

  ```
  ./setup-site
   --domain=mysite.com
   --github=git@github...
   --deploy-subfolder=false
   --web-root-path=null
   --deploy-key-public-file=mysite-deploy-key.pub
   --deploy-key-private-file=mysite-deploy-key
   --php-pools=true
   --nginx-with-php=true
   --nginx-site-conf-path=/var/www/LEMP-setup-guide/config/site.nginx.conf (or site.nginx.vueapp.conf)
   --php-with-mysql=true
   --php-site-conf-path=/var/www/LEMP-setup-guide/config/site.php-fpm.conf
   --mysql-create-db=true
   --mysql-root-user=root
   --mysql-root-pass=1234
   --database-name=site_com
   --database-user=site.com
   --database-pass=cRaZyPaSs
   --database-host=localhost
   --database-port=3306
  ```

  | Option                         | Description                                                                                                                                                            | Default Value                                                     |
  |--------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------|
  | `--domain=DOMAIN_NAME`         | Specify domain e.g. `mysite.com`                                                                                                                                      | None                                                              |
  | `--github=GITHUB_REPO`         | Specify GitHub repo using SSH e.g. `git@github.com:youruser/yourrepo.git`                                                                                             | None                                                              |
  | `--deploy-subfolder`           | Specify if you want to deploy a subfolder of the repo. Possible values: `true`, `false` or path e.g. `releases`                                                        | `false`                                                           |
  | `--web-root-path=PATH`         | Specify the path to the web root path within your "domain" folder or repo.                                                                                             | Blank (index file should be directly in the folder)                |
  | `--owner-user=USER`            | Specify the owner user (used for deploy & ssh key ownership)                                                                                                           | Result of `whoami`                                                |
  | `--deploy-key-public-file=PATH`| Specify the path to the public deploy key file                                                                                                                        | None                                                              |
  | `--deploy-key-private-file=PATH`| Specify the path to the private deploy key file                                                                                                                       | None                                                              |
  | `--php-pools`                  | Specify if you want to set up PHP pools. Possible values: `true` or `false`                                                                                            | `false`                                                           |
  | `--nginx-with-php`             | Specify if you want to set up Nginx with PHP upstreams. Possible values: `true` or `false`                                                                             | `false`                                                           |
  | `--nginx-site-conf-path=PATH`  | Specify the path to the Nginx site conf file                                                                                                                          | `/var/www/LEMP-setup-guide/config/site.nginx.conf` (or `site.nginx.vueapp.conf`) |
  | `--php-with-mysql`             | Specify if you want to set up PHP with MySQL env vars. Possible values: `true` or `false`                                                                              | `false`                                                           |
  | `--php-site-conf-path=PATH`    | Specify the path to the PHP site conf file                                                                                                                            | `/var/www/LEMP-setup-guide/config/site.php-fpm.conf`              |
  | `--mysql-create-db`            | Specify if you want to set up a MySQL database. Possible values: `true` or `false`                                                                                     | `false`                                                           |
  | `--mysql-root-user=USER`       | Specify the MySQL root user                                                                                                                                           | `root`                                                            |
  | `--mysql-root-pass=PASS`       | Specify the MySQL root pass                                                                                                                                           | `1234`                                                            |
  | `--database-name=NAME`         | Specify the database name                                                                                                                                             | None                                                              |
  | `--database-user=USER`         | Specify the database user                                                                                                                                             | None                                                              |
  | `--database-pass=PASS`         | Specify the database password                                                                                                                                         | None                                                              |
  | `--database-host=HOST`         | Specify the database host                                                                                                                                             | `localhost`                                                       |
  | `--database-port=PORT`         | Specify the database port                                                                                                                                             | `3306`                                                            |
  | `--help`                       | Display the help message and exit                                                                                                                                     | None                                                              |


- **setup-logrotate** (needs logrotate command and syslog user)
- **install-cert** - sets up certbot for ssl on your site, with option to update nginx or not - creates a cronjob to keep fetching. ideal if you want control over how certbot affects nginx conf files.

---

### Installable Components
There are also **components** in the `install` folder, which allow you to install other specific common tools, as well as your own custom scripts.

- composer
- pm2
- nvm
- redis
- postgressql
- custom
- upgrade-php (see [Upgrade PHP Readme for help](./install/components/upgrade-php/UPGRADE_PHP_README.md))

### Custom Scripts

The custom scripts have a `install` file that will loop through scripts in the `scripts` folder. You can name these with numbers to create an order of when they will run.

- **install** -  (running this will loop through scripts in `/scripts`
- **/scripts** - Add bash scripts here, make sure to `chmod +x` them. eg. `000-running-custom-scripts.sh`

---

## Use SimpleDocker to test script

[SimpleDocker](https://github.com/amurrell/SimpleDocker) is a blank canvas for an ubuntu Docker Container that you can use to develop and test provisioning scripts. It comes with a few helpful tools to get you started and to test your scripts efficiently.

SimpleDocker comes with a "pre-run" example of LEMP-setup-guide's initial installation script. You can use this to test your own changes to the script, or to test your custom scripts. The "pre-run" scripts get cached into the docker container so that it's easy to up/down without waiting beyond the original script.

Note:

If testing with simple docker, you'll need to install `apt-get -y install rsyslog` and `apt-get -y install logrotate` to use setup-logrorate.
