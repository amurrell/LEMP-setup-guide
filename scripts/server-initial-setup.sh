#!/usr/bin/env bash
#
# Adapted
#    from: https://github.com/actuallymentor/Setup-Script-Nginx-Pagespeed-PHP7-Mariadb
#    by:   @actuallymentor, github
#
# This install script uses the following version defaults:
#
#  NOTE: override these versions in the config/versions folder
#        by adding files with override prepended eg "override-php-version"
#
# - openssl: 1.1.1k
# - pagespeed: 1.13.35.2-stable
# - nginx: 1.20.0
# - php: 7.4
# - mariadb: 10.6
#

########################### Variables #############################
workerprocesses=$(grep processor /proc/cpuinfo | wc -l)
workerconnections=$(ulimit -n)
fastcgicache_global=$(<../config/nginx/fastcgicache_global)
fastcgicache=$(<../config/nginx/fastcgicache)

# Figure out global_nginx_conf
cp ../config/nginx/global_nginx_conf ../config/nginx/global_nginx_conf_custom
sed -i'.bak' "s/WORKER_PROCESSES/${workerprocesses}/g;" ../config/nginx/global_nginx_conf_custom
sed -i'.bak' "s/WORKER_CONNECTIONS/${workerconnections}/g;" ../config/nginx/global_nginx_conf_custom
rm ../config/nginx/global_nginx_conf_custom.bak

# Versions
PHP_VERSION=$(<../config/versions/php-version)
NGINX_VERSION=$(<../config/versions/nginx-version)
PAGESPEED_VERSION=$(<../config/versions/pagespeed-version)
OPENSSL_VERSION=$(<../config/versions/openssl-version)
MARIADB_VERSION=$(<../config/versions/mariadb-version)

# detect the ubuntu version and release name
UBUNTU_VERSION=$(lsb_release -r | awk '{print $2}')
UBUNTU_RELEASE_NAME=$(lsb_release -c | awk '{print $2}')

# Version overrides
if [ -f ../config/versions/override-php-version ] && [ ! -z $(<../config/versions/override-php-version) ]; then
	PHP_VERSION=$(<../config/versions/override-php-version)
fi

if [ -f ../config/versions/override-nginx-version ] && [ ! -z $(<../config/versions/override-nginx-version) ]; then
	NGINX_VERSION=$(<../config/versions/override-nginx-version)
fi

if [ -f ../config/versions/override-pagespeed-version ] && [ ! -z $(<../config/versions/override-pagespeed-version) ]; then
	PAGESPEED_VERSION=$(<../config/versions/override-pagespeed-version)
fi

if [ -f ../config/versions/override-openssl-version ] && [ ! -z $(<../config/versions/override-openssl-version) ]; then
	OPENSSL_VERSION=$(<../config/versions/override-openssl-version)
fi

if [ -f ../config/versions/override-mariadb-version ] && [ ! -z $(<../config/versions/override-mariadb-version) ]; then
	MARIADB_VERSION=$(<../config/versions/override-mariadb-version)
fi

# Nginx configurations
global_nginx_conf=$(<../config/nginx/global_nginx_conf_custom)
nginx_conf=$(<../config/nginx/nginx_conf)
mod_pagespeed=$(<../config/nginx/mod_pagespeed)
cache=$(<../config/nginx/cache)
gzipconf=$(<../config/nginx/gzip_conf)
log_format=$(<../config/nginx/log_format_conf)

#Auto security update rules
updaterules=$(<../config/security/updates_rules)
rotaterules=$(<../config/security/rotate_rules)

##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################

sudo apt-get update

### 18.04 AMI has grub issue
### Workaround: Pre-update /etc/default/grub and
### remove /boot/grub/menu.lst to avoid 'file changed'
### prompts from blocking completion of unattended update process
# patch /etc/default/grub <<'EOF'
# 10c10
# < GRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0"
# ---
# > GRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0 nvme.io_timeout=4294967295"
# 19c19
# < GRUB_TERMINAL=console
# ---
# > #GRUB_TERMINAL=console
# EOF
# rm /boot/grub/menu.lst

# Avoid php packaging prompts - setting a timezone
dpkg-reconfigure debconf --frontend=noninteractive
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install grub-pc
DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata
# ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

# sudo apt-get -y upgrade

### Workaround part 2: re-generate /boot/grub/menu.lst
# /usr/sbin/update-grub-legacy-ec2 -y

# Dependencies etc
DEBIAN_FRONTEND=noninteractive apt-get install -y wget
DEBIAN_FRONTEND=noninteractive apt-get install -y git
DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential
DEBIAN_FRONTEND=noninteractive apt-get install -y python
DEBIAN_FRONTEND=noninteractive apt-get install -y dpkg-dev
DEBIAN_FRONTEND=noninteractive apt-get install -y zlib1g-dev
DEBIAN_FRONTEND=noninteractive apt-get install -y libpcre3
DEBIAN_FRONTEND=noninteractive apt-get install -y libpcre3-dev
DEBIAN_FRONTEND=noninteractive apt-get install -y unzip
DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common
DEBIAN_FRONTEND=noninteractive apt-get install -y uuid-dev

# Pagespeed download
cd
wget https://github.com/apache/incubator-pagespeed-ngx/archive/v${PAGESPEED_VERSION}.zip
unzip v${PAGESPEED_VERSION}.zip
nps_dir=$(find . -name "*pagespeed-ngx-${PAGESPEED_VERSION}" -type d)
cd "$nps_dir"
NPS_RELEASE_NUMBER=${PAGESPEED_VERSION/beta/}
NPS_RELEASE_NUMBER=${PAGESPEED_VERSION/stable/}

# Fix psol nginx/ubuntu version combability issues
# issue: on newer glibc - eg with ubuntu jammy, error "undefined reference to `pthread_yield'".
# solution: Install correct psol for unbutu release, based on another contributors' kind fix.
#  which will rely on their psol hosted files for now.
# - source - fix: https://github.com/apache/incubator-pagespeed-ngx/issues/1760#issue-1385031517
# - source - build psol from source example: https://github.com/eilandert/build_psol/blob/main/docker/bootstrap.sh
psol_url=http://www.tiredofit.nl/psol-${UBUNTU_RELEASE_NAME}.tar.xz
wget ${psol_url}
tar xvf psol-${UBUNTU_RELEASE_NAME}.tar.xz

# Openssl Download
wget -qO - https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar xzf  - -C /tmp
cd

# Nginx Download
mkdir -p /etc/nginx
cd
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -xvzf nginx-${NGINX_VERSION}.tar.gz
cd nginx-${NGINX_VERSION}/
./configure \
--add-module=$HOME/$nps_dir ${PS_NGX_EXTRA_FLAGS} \
--prefix=/etc/nginx  \
--sbin-path=/usr/sbin/nginx  \
--conf-path=/etc/nginx/nginx.conf  \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--pid-path=/var/run/nginx.pid \
--lock-path=/var/run/nginx.lock \
--http-client-body-temp-path=/var/cache/nginx/client_temp \
--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp  \
--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp  \
--http-scgi-temp-path=/var/cache/nginx/scgi_temp  \
--user=www-data  \
--group=www-data  \
--with-http_ssl_module  \
--with-http_realip_module  \
--with-http_addition_module  \
--with-http_sub_module  \
--with-http_dav_module  \
--with-http_flv_module  \
--with-http_mp4_module  \
--with-http_gunzip_module  \
--with-http_gzip_static_module  \
--with-http_random_index_module  \
--with-http_secure_link_module \
--with-http_stub_status_module  \
--with-http_auth_request_module  \
--without-http_autoindex_module \
--without-http_ssi_module \
--with-threads  \
--with-stream  \
--with-stream_ssl_module  \
--with-mail  \
--with-mail_ssl_module  \
--with-file-aio  \
--with-http_v2_module \
--with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2'  \
--with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,--as-needed' \
--with-ipv6 \
--with-pcre-jit \
--with-openssl=/tmp/openssl-${OPENSSL_VERSION}
make
sudo make install

# Finish installing pagespeed and nginx configuration
mkdir -p /var/log/ngx_pagespeed
mkdir -p /var/cache/nginx/
mkdir -p /var/cache/nginx/client_temp
git clone https://github.com/Fleshgrinder/nginx-sysvinit-script.git
cd nginx-sysvinit-script
make

sudo update-rc.d -f nginx defaults

mkdir -p /etc/nginx/conf
mkdir -p /etc/nginx/sites
echo "$global_nginx_conf" > /etc/nginx/nginx.conf;
echo "$fastcgicache_global" > /etc/nginx/conf/fastcgicache_global.conf
echo "$nginx_conf" > /etc/nginx/sites/default;
echo "$mod_pagespeed" > /etc/nginx/conf/mod_pagespeed.conf;
echo "$log_format" > /etc/nginx/conf/log_format.conf;
echo "$cache" > /etc/nginx/conf/cache.conf;
echo "$gzipconf" > /etc/nginx/conf/gzip.conf;
echo "$fastcgicache" > /etc/nginx/conf/fastcgicache.conf

# Mariadb
sudo apt-get update
curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
sudo bash mariadb_repo_setup "--mariadb-server-version=${MARIADB_VERSION}"
sudo apt-get update
cat /etc/apt/sources.list.d/mariadb.list
MARIADB_PASSWORD="mariadb-server-${MARIADB_VERSION} mysql-server/root_password password PASS"
MARIADB_PASSWORD_AGAIN="mariadb-server-${MARIADB_VERSION} mysql-server/root_password_again password PASS"
sudo debconf-set-selections <<< ${MARIADB_PASSWORD}
sudo debconf-set-selections <<< ${MARIADB_PASSWORD_AGAIN}
sudo apt-get install -y mariadb-server mariadb-client > /dev/null
sudo service mariadb start # note that this is not mysql anymore, it's mariadb
mysql -u root -pPASS -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'password';"

# remind folks about these:

# Run this to enable mariadb to start on reboot
#sudo systemctl enable mariadb

# Run this to secure the installation!
#sudo mariadb-secure-installation

# PHP
LC_ALL=C.UTF-8 sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update
sudo apt-get -y --no-install-recommends install php${PHP_VERSION}
sudo apt-get -y --no-install-recommends install php${PHP_VERSION}-fpm
sudo apt-get clean

sudo update-alternatives --set php /usr/bin/php${PHP_VERSION}
service php${PHP_VERSION}-fpm start

# PHP
sudo apt-get update && \
	sudo apt-get install -y php${PHP_VERSION}-curl && \
	sudo apt-get install -y php${PHP_VERSION}-mysql && \
	sudo apt-get -y install php-pear && \
	sudo apt-get -y install php${PHP_VERSION}-dev && \
	sudo apt-get -y install libcurl3-openssl-dev && \
	sudo apt-get -y install libyaml-dev && \
	sudo apt-get -y install php${PHP_VERSION}-zip && \
	sudo apt-get -y install php${PHP_VERSION}-mbstring && \
	sudo apt-get -y install php${PHP_VERSION}-memcached && \
	sudo apt-get -y install php${PHP_VERSION}-pgsql && \
	sudo apt-get -y install php${PHP_VERSION}-xml && \
	sudo apt-get -y install php${PHP_VERSION}-intl && \
	sudo apt-get -y install php${PHP_VERSION}-redis && \
	sudo apt-get -y install php${PHP_VERSION}-bcmath && \
	sudo apt-get -y install php${PHP_VERSION}-gd

# FastCGI microcaching
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i "s/^;listen.owner = www-data/listen.owner = www-data/g" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
sed -i "s/^;listen.group = www-data/listen.group = www-data/g" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
sed -i "s/^;listen.mode = 0660/listen.mode = 0660/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
mkdir -p /var/nginx_cache

# note: mcrypt for 7.3 is a pecl extension, so i got rid of it for now.

# adminer and sendy modules
phpenmod mbstring
phpenmod curl
phpenmod xml
phpenmod xmlreader
phpenmod simplexml
phpenmod gd
service php${PHP_VERSION}-fpm restart

# auto security updates
touch /etc/cron.daily/apt-security-updates
touch /etc/logrotate.d/apt-security-updates
echo $updaterules > /etc/cron.daily/apt-security-updates
echo $rotaterules > /etc/logrotate.d/apt-security-updates
sudo chmod +x /etc/cron.daily/apt-security-updates

service nginx restart

# Alter Nginx Conf things

if [ ! -d "/etc/nginx" ]; then
    printf "Does not seem that nginx is installed properly.\n"
    exit 1
fi

cd /etc/nginx
sed -i "s=include /etc/nginx/sites=include /etc/nginx/sites-enabled=g;" nginx.conf
mkdir -p /etc/nginx/sites-available/
mkdir -p /etc/nginx/sites-enabled/
mv /etc/nginx/sites/* /etc/nginx/sites-available/

printf "Script: Done. Read log for status of services"
printf "MariaDB - Action required: Run this to enable mariadb to start on reboot.\n"
printf "sudo systemctl enable mariadb\n"

printf "MariaDB - Action required: Run this to secure the installation!\n"
printf "sudo mariadb-secure-installation\n"
