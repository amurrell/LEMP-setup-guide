#!/usr/bin/env bash
#
# Adapted 
#    from: https://github.com/actuallymentor/Setup-Script-Nginx-Pagespeed-PHP7-Mariadb
#    by:   @actuallymentor, github
#

########################### Variables #############################
workerprocesses=$(grep processor /proc/cpuinfo | wc -l)
workerconnections=$(ulimit -n)

fastcgicache_global='fastcgi_cache_path /var/nginx_cache/fcgi levels=1:2 keys_zone=microcache:100m inactive=60m;
fastcgi_cache_key "$scheme$request_method$host$request_uri";
fastcgi_cache_use_stale updating error timeout invalid_header http_500;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;'

fastcgicache='set $skip_cache 1;

# POST requests and urls with a query string should always go to PHP
if ($request_method = POST) {
    set $skip_cache 1;
}   
if ($query_string != "") {
    set $skip_cache 1;
}   

# Dont cache uris containing the following segments
if ($request_uri ~* "/wp-admin/|/xmlrpc.php|wp-.*.php|/feed/|index.php|sitemap(_index)?.xml") {
    set $skip_cache 1;
}   

# Dont use the cache for logged in users or recent commenters
if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
    set $skip_cache 1;
}

location ~ \.php$ {
    include fastcgi.conf;
    fastcgi_pass unix:/run/php/php7.2-fpm.sock;

    try_files $uri =404;
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    
    fastcgi_cache_bypass $skip_cache;
    fastcgi_no_cache $skip_cache;

    fastcgi_cache microcache;
    fastcgi_cache_valid  60m;

}'

global_nginx_conf="
user  www-data www-data;
worker_processes  $workerprocesses;

events {
    worker_connections  $workerconnections;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    server_tokens off;

    sendfile        on;
    #tcp_nopush     on;

    # Gzip configuration
    include /etc/nginx/conf/gzip.conf;

    #PHP and FastCGI cache
    include /etc/nginx/conf/fastcgicache_global.conf;

    # Add my servers
    include /etc/nginx/sites/*;

    # Buffers
    client_body_buffer_size 10K;
    client_header_buffer_size 1k;
    client_max_body_size 8m;
    large_client_header_buffers 2 1k;

    # Timeouts

    client_body_timeout 12;
    client_header_timeout 12;
    keepalive_timeout 15;
    send_timeout 10;

    # Log off
    access_log off;
}
"
nginx_conf='
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/localhost;
    index index.html index.htm index.php;

    server_name localhost;
    client_max_body_size 32M;
    large_client_header_buffers 4 16k;

    include /etc/nginx/conf/mod_pagespeed.conf;
    include /etc/nginx/conf/cache.conf;
    include /etc/nginx/conf/gzip.conf;

    # PHP and fastcgicache
    include /etc/nginx/conf/fastcgicache.conf;

    location / {
        try_files $uri $uri/ /index.php;
    }
    error_page 401 403 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
    }
}'
mod_pagespeed='
pagespeed on;
pagespeed RewriteLevel PassThrough;
pagespeed FetchHttps enable;
pagespeed EnableFilters add_head;
# pagespeed EnableFilters combine_css;
# pagespeed EnableFilters rewrite_css;
# pagespeed EnableFilters fallback_rewrite_css_urls;
# pagespeed EnableFilters rewrite_style_attributes;
# pagespeed EnableFilters rewrite_style_attributes_with_url;
# pagespeed EnableFilters flatten_css_imports;
# pagespeed EnableFilters inline_css;
# pagespeed EnableFilters inline_google_font_css;
# pagespeed EnableFilters prioritize_critical_css;

pagespeed CssInlineMaxBytes 25600;
pagespeed JsInlineMaxBytes 8192;
pagespeed ImageRecompressionQuality 75;
pagespeed JpegRecompressionQualityForSmallScreens 65;

# pagespeed EnableFilters rewrite_javascript;
# pagespeed EnableFilters rewrite_javascript_external;
# pagespeed EnableFilters rewrite_javascript_inline;
# pagespeed EnableFilters combine_javascript;
# pagespeed EnableFilters canonicalize_javascript_libraries;
# pagespeed EnableFilters inline_javascript;
# pagespeed EnableFilters defer_javascript;
pagespeed EnableFilters dedup_inlined_images;
# pagespeed EnableFilters lazyload_images;

pagespeed EnableFilters local_storage_cache;
pagespeed EnableFilters rewrite_images;
pagespeed EnableFilters convert_jpeg_to_progressive;
pagespeed EnableFilters convert_png_to_jpeg;
pagespeed EnableFilters convert_jpeg_to_webp;
pagespeed EnableFilters convert_to_webp_lossless;
pagespeed EnableFilters insert_image_dimensions;
pagespeed EnableFilters inline_images;
pagespeed EnableFilters recompress_images;
pagespeed EnableFilters recompress_jpeg;
pagespeed EnableFilters recompress_png;
pagespeed EnableFilters recompress_webp;
pagespeed EnableFilters convert_gif_to_png;
pagespeed EnableFilters strip_image_color_profile;
pagespeed EnableFilters strip_image_meta_data;
pagespeed EnableFilters resize_images;
pagespeed EnableFilters resize_rendered_image_dimensions;
pagespeed EnableFilters resize_mobile_images;

pagespeed EnableFilters remove_comments;
pagespeed EnableFilters collapse_whitespace;
pagespeed EnableFilters elide_attributes;
pagespeed EnableFilters extend_cache;
pagespeed EnableFilters extend_cache_css;
pagespeed EnableFilters extend_cache_images;
pagespeed EnableFilters extend_cache_scripts;

pagespeed EnableFilters sprite_images;
pagespeed EnableFilters convert_meta_tags;

pagespeed EnableFilters in_place_optimize_for_browser;
pagespeed EnableFilters insert_dns_prefetch;

pagespeed FileCachePath /var/ngx_pagespeed_cache;

location ~ "\.pagespeed\.([a-z]\.)?[a-z]{2}\.[^.]{10}\.[^.]+" {
  add_header "" "";
}
location ~ "^/pagespeed_static/" { }
location ~ "^/ngx_pagespeed_beacon$" { }
pagespeed EnableCachePurge on;
'
cache='
location ~* .(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 365d;
}
'
gzipconf='
gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_types text/plain text/css text/xml application/xml application/javascript application/x-javascript text/javascript;
'

#Auto security update rules
updaterules='echo "**************" >> /var/log/apt-security-updates
date >> /var/log/apt-security-updates
aptitude update >> /var/log/apt-security-updates
aptitude safe-upgrade -o Aptitude::Delete-Unused=false --assume-yes --target-release `lsb_release -cs`-security >> /var/log/apt-security-updates
echo "Security updates (if any) installed"'
rotaterules='/var/log/apt-security-updates {
    rotate 2
    weekly
    size 250k
    compress
    notifempty
}'


##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################

sudo apt-get update
sudo apt-get -y upgrade

# Dependencies etc
sudo apt-get install -y git build-essential python dpkg-dev zlib1g-dev libpcre3 libpcre3-dev unzip software-properties-common

# Pagespeed download
cd
NPS_VERSION=1.11.33.2
wget https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip -O release-${NPS_VERSION}-beta.zip
unzip release-${NPS_VERSION}-beta.zip
cd incubator-pagespeed-ngx-release-${NPS_VERSION}-beta/
wget https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz
tar -xzvf ${NPS_VERSION}.tar.gz  # extracts to psol/

OPENSSL_VERSION='1.0.1s'
wget -qO - https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar xzf  - -C /tmp
cd
# check http://nginx.org/en/download.html for the latest version
NGINX_VERSION=1.10.1
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -xvzf nginx-${NGINX_VERSION}.tar.gz
cd nginx-${NGINX_VERSION}/
./configure \
--add-module=$HOME/incubator-pagespeed-ngx-release-${NPS_VERSION}-beta ${PS_NGX_EXTRA_FLAGS} \
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

mkdir /var/log/ngx_pagespeed
mkdir /var/cache/nginx/
mkdir /var/cache/nginx/client_temp
git clone https://github.com/Fleshgrinder/nginx-sysvinit-script.git
cd nginx-sysvinit-script
make

sudo update-rc.d -f nginx defaults

mkdir /etc/nginx/conf
mkdir /etc/nginx/sites
echo "$global_nginx_conf" > /etc/nginx/nginx.conf;
echo "$fastcgicache_global" > /etc/nginx/conf/fastcgicache_global.conf
echo "$nginx_conf" > /etc/nginx/sites/default;
echo "$mod_pagespeed" > /etc/nginx/conf/mod_pagespeed.conf;
echo "$cache" > /etc/nginx/conf/cache.conf;
echo "$gzipconf" > /etc/nginx/conf/gzip.conf;
echo "$fastcgicache" > /etc/nginx/conf/fastcgicache.conf

# Mariadb
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
sudo add-apt-repository 'deb [arch=amd64,i386] http://mirrors.supportex.net/mariadb/repo/10.3/ubuntu xenial main'
sudo apt-get update
sudo apt-get install -y dialog apt-utils
sudo apt-get install mariadb-server

# export DEBIAN_FRONTEND=noninteractive
# sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password password root'
# sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password_again password root'
# sudo apt-get install -y mariadb-server > /dev/null
sudo service mysql start

# PHP
sudo apt-get install -y software-properties-common
sudo apt-get install -y python-software-properties
LC_ALL=C.UTF-8 sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update
sudo apt-get -y --no-install-recommends install php7.2
sudo apt-get -y --no-install-recommends install php7.2-fpm
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
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/7.2/fpm/php.ini
sed -i "s/^;listen.owner = www-data/listen.owner = www-data/g" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/^;listen.group = www-data/listen.group = www-data/g" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/^;listen.mode = 0660/listen.mode = 0660/" /etc/php/7.2/fpm/pool.d/www.conf
mkdir /var/nginx_cache

# Default contents
mkdir -p /var/www/localhost
echo '<?php phpinfo(); ?>' > /var/www/localhost/index.php

# mcrypt for 7.2 is a pecl extension, so i got rid of it for now.

# adminer and sendy modules
phpenmod mbstring
phpenmod curl
phpenmod xml
phpenmod xmlreader
phpenmod simplexml
phpenmod gd
service php7.2-fpm restart
mkdir /var/www/localhost/adminer
cd /var/www/localhost/adminer
wget -O index.php https://www.adminer.org/static/download/4.2.4/adminer-4.2.4-mysql.php


# Firewall
# ufw allow ssh
# ufw allow http
# ufw allow https
# yes | ufw enable

# auto security updates
touch /etc/cron.daily/apt-security-updates
touch /etc/logrotate.d/apt-security-updates
echo $updaterules > /etc/cron.daily/apt-security-updates
echo $rotaterules > /etc/logrotate.d/apt-security-updates
sudo chmod +x /etc/cron.daily/apt-security-updates


# Create server check cron

service nginx restart

# Alter Nginx Conf things

if [ ! -d "/etc/nginx" ]; then  
    printf "Does not seem that nginx is installed properly.\n"
    exit 1
fi

cd /etc/nginx
sed -i "s=include /etc/nginx/sites=include /etc/nginx/sites-enabled=g;" nginx.conf
mkdir /etc/nginx/sites-available/
mkdir /etc/nginx/sites-enabled/
mv /etc/nginx/sites/* /etc/nginx/sites-available/

# PROMPT - SSH PUBLIC KEY (Authorized Keys)
cr=`echo $'\n.'`
cr=${cr%.}
read -p "Your SSH public key...paste it $cr" SSHPUBKEY

# Check if /var/www exists
if [ ! -d "~/.ssh/" ]; then  
    printf "SSH folder does not seem to exist for this user. Going to create the folder now.\n"
    cd ~/ && mkdir .ssh
fi

if [ ! "$SSHPUBKEY" == '' ]; then
    echo "$SSHPUBKEY" > ~/.ssh/authorized_keys
fi

# Prompt Site Setup
cd /var/www/LEMP-setup-guide/scripts
./setup-site

