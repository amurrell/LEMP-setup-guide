#!/usr/bin/env bash
#
# Adapted 
#    from: https://github.com/actuallymentor/Setup-Script-Nginx-Pagespeed-PHP7-Mariadb
#    by:   @actuallymentor, github
#
# This upgraded version uses:
#
# - pagespeed: 1.13.35.2-stable
# - nginx: 1.15.9
# - php: 7.3
# - mariadb: 10.3
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

global_nginx_conf=$(<../config/nginx/global_nginx_conf_custom)
nginx_conf=$(<../config/nginx/nginx_conf)
mod_pagespeed=$(<../config/nginx/mod_pagespeed)
cache=$(<../config/nginx/cache)
gzipconf=$(<../config/nginx/gzip_conf)

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
export DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install grub-pc
apt-get install -y tzdata
# ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

# sudo apt-get -y upgrade

### Workaround part 2: re-generate /boot/grub/menu.lst
# /usr/sbin/update-grub-legacy-ec2 -y

# Dependencies etc
sudo apt-get install -y wget
sudo apt-get install -y git
sudo apt-get install -y build-essential
sudo apt-get install -y python
sudo apt-get install -y dpkg-dev
sudo apt-get install -y zlib1g-dev
sudo apt-get install -y libpcre3
sudo apt-get install -y libpcre3-dev
sudo apt-get install -y unzip
sudo apt-get install -y software-properties-common
sudo apt-get install -y uuid-dev

# Pagespeed download
NPS_VERSION=1.13.35.2-stable
cd
wget https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}.zip
unzip v${NPS_VERSION}.zip
nps_dir=$(find . -name "*pagespeed-ngx-${NPS_VERSION}" -type d)
cd "$nps_dir"
NPS_RELEASE_NUMBER=${NPS_VERSION/beta/}
NPS_RELEASE_NUMBER=${NPS_VERSION/stable/}
psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_RELEASE_NUMBER}.tar.gz
[ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL)
wget ${psol_url}
tar -xzvf $(basename ${psol_url})  # extracts to psol/

# Openssl Download
OPENSSL_VERSION='1.0.1s'
wget -qO - https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar xzf  - -C /tmp
cd

# Nginx Download
mkdir -p /etc/nginx
NGINX_VERSION=1.15.9
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
echo "$cache" > /etc/nginx/conf/cache.conf;
echo "$gzipconf" > /etc/nginx/conf/gzip.conf;
echo "$fastcgicache" > /etc/nginx/conf/fastcgicache.conf

# Mariadb
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
sudo add-apt-repository 'deb [arch=amd64] http://mirror.zol.co.zw/mariadb/repo/10.3/ubuntu bionic main'
sudo apt-get update
sudo apt update
sudo apt-get install -y dialog apt-utils
sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password password PASS'
sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password_again password PASS'
sudo apt-get install -y mariadb-server > /dev/null
sudo service mysql start
mysql -uroot -pPASS -e "SET PASSWORD = PASSWORD('password');"

# PHP
LC_ALL=C.UTF-8 sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update
sudo apt-get -y --no-install-recommends install php7.3
sudo apt-get -y --no-install-recommends install php7.3-fpm
sudo apt-get clean

# PHP
sudo apt-get update && \
	sudo apt-get install -y php-curl && \
	sudo apt-get install -y php-mysql && \
	sudo apt-get -y install php-pear && \
	sudo apt-get -y install php-dev && \
	sudo apt-get -y install libcurl3-openssl-dev && \
	sudo apt-get -y install libyaml-dev && \
	sudo apt-get -y install php-zip && \
	sudo apt-get -y install php-mbstring && \
	sudo apt-get -y install php-memcached && \
	sudo apt-get -y install php-pgsql && \
	sudo apt-get -y install php-xml && \
    sudo apt-get -y install php-gd

# FastCGI microcaching
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/7.3/fpm/php.ini
sed -i "s/^;listen.owner = www-data/listen.owner = www-data/g" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/^;listen.group = www-data/listen.group = www-data/g" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/^;listen.mode = 0660/listen.mode = 0660/" /etc/php/7.3/fpm/pool.d/www.conf
mkdir -p /var/nginx_cache

# mcrypt for 7.3 is a pecl extension, so i got rid of it for now.

# adminer and sendy modules
phpenmod mbstring
phpenmod curl
phpenmod xml
phpenmod xmlreader
phpenmod simplexml
phpenmod gd
service php7.3-fpm restart

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
