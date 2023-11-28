# Upgrade PHP

## Overview

This script will upgrade PHP from one version to another, and make all changes that LEMP setup guide makes to the PHP and PHP-FPM configs as part of the initial/per-site setup.

> Note:
> - The script must be run as root (`sudo su` first if you're not already root)
> - It will exit on the first error it encounters
> - It assumes that at least 1 site has already been set up. You can run the LEMP setup guide to set up a site.

It will do the following:

1. Install new versions of PHP and php-fpm if they don't already exist
1. Install all php packages
1. Enable all php extensions
1. Make edits to PHP.ini file
1. Make edits to www.conf file if needed
1. Copy all php-fpm configs but www.conf over to the new version
1. Loop through each file in /etc/nginx/sites-enabled. Per site:
    - Update php-fpm config
    - Test php-fpm config
    - Check that new php-fpm sockets have been created
    - Update nginx site conf to point to new socket
    - Test nginx config
1. Update nginx fastcgicache conf to point to a new global socket
1. Test nginx config and reload (this sets the new php version live)
1. Update default PHP version
1. Output next steps

## Usage

```sh
upgrade-php.sh OLD_VERSION NEW_VERSION
```

Example: upgrade-php.sh 8.0 8.2

> Note:
> - Set $DEBUG for a verbose output - $DEBUG=true ./upgrade-php.sh [options]
> - You can also run it without args to see the usage info: ./upgrade-php.sh

## Troubleshooting

- If you're having issues with the script, try running it with the $DEBUG variable set to true. This will output more verbose information about what the script is doing.

```sh
$DEBUG=true ./upgrade-php.sh OLD_VERSION NEW_VERSION
```
