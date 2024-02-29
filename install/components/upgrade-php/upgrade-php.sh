set -e

# function to script_echo something in purple
function script_echo() {
	echo -e "\033[35m$1\033[0m"
}

# check that user is root
if [ ! $EUID = 0 ]; then
	script_echo "Please run this script as root!"
	exit 1
fi


# If no args were passed, script_echo out some helpful info
if [ $# -eq 0 ]; then
	script_echo "Usage: upgrade-php.sh OLD_VERSION NEW_VERSION"
	script_echo "Example: upgrade-php.sh 8.0 8.2"
	script_echo "Notes:"
	script_echo '- Set $DEBUG for a verbose output - $DEBUG=true ./upgrade-php.sh [options]'
	exit 1
fi

# For debugging the script
# set -v if
if [ ! -z "$DEBUG" ]; then
	set -v
fi

# Validate that the user passed at least two args
if [ $# -lt 2 ]; then
	script_echo "Please pass the version args (OLD_VERSION NEW_VERSION)"
	script_echo "Example: upgrade-php.sh 8.0 8.2"
	exit 1
fi

# Validate that the version args are valid
# they should be numbers with a decimal point
if [[ ! $1 =~ ^[0-9]+(\.[0-9]+)?$ ]] || [[ ! $2 =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
	script_echo "Please pass valid version args"
	script_echo "Example: upgrade-php.sh 8.0 8.2"
	exit 1
fi

OLD_PHP_VERSION=$1
NEW_PHP_VERSION=$2

# Install new versions of PHP and php-fpm but only if they don't already exist
if [ -f /usr/bin/php${NEW_PHP_VERSION} ]; then
	script_echo "ℹ️ php${NEW_PHP_VERSION} already exists, skipping install"
else
	script_echo "📦 Installing php${NEW_PHP_VERSION}"
	sudo apt-get update
	sudo apt-get -y --no-install-recommends install php${NEW_PHP_VERSION}
fi

if [ -f /usr/sbin/php-fpm${NEW_PHP_VERSION} ]; then
	script_echo "ℹ️ php-fpm${NEW_PHP_VERSION} already exists, skipping install"
else
	script_echo "📦 Installing php-fpm${NEW_PHP_VERSION}"
	sudo apt-get update
	sudo apt-get -y --no-install-recommends install php${NEW_PHP_VERSION}-fpm
fi

# Install all php packages if they don't already exist
script_echo "📦 Installing php packages"
sudo apt-get update && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-curl && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-mysql && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-dev && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-zip && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-mbstring && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-memcached && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-pgsql && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-xml && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-intl && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-redis && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-bcmath && \
	sudo apt-get -y install php${NEW_PHP_VERSION}-gd

# make edits to PHP.ini file
script_echo "🖊 Editing php.ini"
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/${NEW_PHP_VERSION}/fpm/php.ini

# Enable all php extensions
script_echo "📦 Enabling all php extensions"
phpenmod -v $NEW_PHP_VERSION mbstring
phpenmod -v $NEW_PHP_VERSION curl
phpenmod -v $NEW_PHP_VERSION xml
phpenmod -v $NEW_PHP_VERSION xmlreader
phpenmod -v $NEW_PHP_VERSION simplexml
phpenmod -v $NEW_PHP_VERSION gd

# make edits to www.conf file if needed
PHP_WWW_CONF=/etc/php/${NEW_PHP_VERSION}/fpm/pool.d/www.conf
if [ ! -f $PHP_WWW_CONF ]; then
	script_echo "ℹ️ www.conf not found, skipping edits"
else
	script_echo "🖊 Editing www.conf"
	sed -i "s/^;listen.owner = www-data/listen.owner = www-data/g" $PHP_WWW_CONF
	sed -i "s/^;listen.group = www-data/listen.group = www-data/g" $PHP_WWW_CONF
	sed -i "s/^;listen.mode = 0660/listen.mode = 0660/" $PHP_WWW_CONF
fi

# Copy all php-fpm configs but www.conf over to the new version
ls /etc/php/${OLD_PHP_VERSION}/fpm/pool.d/ | grep -v www.conf | while read -r line; do
	# Copy the file to the new version
	script_echo "📦 Copying php-fpm configs for site pool: ${line}"
	sudo cp /etc/php/${OLD_PHP_VERSION}/fpm/pool.d/${line} /etc/php/${NEW_PHP_VERSION}/fpm/pool.d/${line}
done

# loop through each file in sites-enabled
ls /etc/nginx/sites-enabled/ | while read -r line; do
	NGINX_SITE_CONF=${line}

	# Remove the .conf from the end of the file name and save to SITE_NAME
	SITE_NAME=${line%.conf}

	# script_echo which file we're on
	script_echo "🦾 Processing site: ${SITE_NAME}"

	# Get the socket name from inside the nginx file. use that to replace the socket name in the php-fpm file
	# This is the old socket name (get everything between unix: and .sock), and add .sock to the end
	OLD_SOCKET_PREFIX=$(cat /etc/nginx/sites-enabled/${NGINX_SITE_CONF} | grep "unix:" | head -n 1 | grep -oP '(?<=unix:).*(?=sock)')sock
	# replace / with \/ to get a sed friendly string
	OLD_SOCKET_GLOB=$(echo ${OLD_SOCKET_PREFIX} | sed 's/\//\\\//g')

	NEW_SOCKET_PREFIX="/var/run/php${NEW_PHP_VERSION}-fpm.${SITE_NAME}.sock"
	# replace / with \/ to get a sed friendly string
	NEW_SOCKET_GLOB=$(echo ${NEW_SOCKET_PREFIX} | sed 's/\//\\\//g')

	# Do a recursive grep in pool.d to find all the files that have the old socket name
	grep -rl ${OLD_SOCKET_GLOB} /etc/php/${NEW_PHP_VERSION}/fpm/pool.d/ | while read -r phpconfig; do
		# Update php-fpm config
		script_echo "🖊 Editing php-fpm config for site php-fpm config: ${phpconfig}"
		sudo sed -i "s/^listen = ${OLD_SOCKET_GLOB}/listen = ${NEW_SOCKET_GLOB}/g" ${phpconfig}
	done

	# Test php-fpm config and restart
	script_echo "🕵️‍♀️ Testing php-fpm config and restarting"
	sudo php-fpm${NEW_PHP_VERSION} -t && sudo service php${NEW_PHP_VERSION}-fpm restart

	# check that sockets have been created, exit if not
	# there should be 2, sock1 and sock2
	# pattern is /var/run/php${NEW_PHP_VERSION}-fpm.${SITE_NAME}.sock(1 or 2)
	# the -S flag checks if the file exists and is a socket. -f fails bc it's not a regular file
	script_echo "🕵️‍♀️ Checking for php-fpm sockets"
	if [ ! -S ${NEW_SOCKET_PREFIX}1 ] || [ ! -S ${NEW_SOCKET_PREFIX}2 ]; then
		script_echo "Missing php-fpm sockets"
		script_echo "Expected: ${NEW_SOCKET_PREFIX}1"
		script_echo "Expected: ${NEW_SOCKET_PREFIX}2"
		exit 1
	fi

	# update nginx site conf to point to new socket
	# Note! We always want to edit sites-available, not sites-enabled.
	# sites-enabled containts symlinks to sites-available. Making changes there would break the symlink
	script_echo "🖊 Editing nginx site conf"
	sudo sed -i "s/unix:${OLD_SOCKET_GLOB}/unix:${NEW_SOCKET_GLOB}/g" /etc/nginx/sites-available/${NGINX_SITE_CONF}

	# test nginx config
	script_echo "🕵️‍♀️ Testing nginx config"
	sudo nginx -t
done

# update nginx fastcgicache conf to point to a new global socket
# replace any socket that starts with /var/run/php*.sock
# with /var/run/php${NEW_PHP_VERSION}-fpm.sock
if [ ! -f /etc/nginx/conf/fastcgicache.conf ]; then
	script_echo "ℹ️ fastcgicache.conf not found, skipping edits"
else
	script_echo "🖊 Editing nginx fastcgicache conf"
	# sudo sed -i "s/unix:${OLD_SOCKET_GLOB}/unix:${NEW_SOCKET_GLOB}/g" /etc/nginx/conf/fastcgicache.conf
	sudo sed -i "s/\/var\/run\/php.*\.sock/\/var\/run\/php${NEW_PHP_VERSION}-fpm.sock/g" /etc/nginx/conf/fastcgicache.conf
fi

# test nginx config and reload
script_echo "🕵️‍♀️ Testing nginx config and reloading"
sudo nginx -t && sudo service nginx reload

# # Set default PHP version
script_echo "📦 Setting default php version to ${NEW_PHP_VERSION}"
sudo update-alternatives --set php /usr/bin/php${NEW_PHP_VERSION}

script_echo "
✅ All done!
--------------------
📝 Next steps:
- Restart any processes running the old php version, ex: pm2. Check with: \`ps aux | grep php${OLD_PHP_VERSION}\`
- Shut down the old php-fpm service: \`sudo service php${OLD_PHP_VERSION}-fpm stop\`
"
