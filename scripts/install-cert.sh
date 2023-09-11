# check for certbot
if ! [ -x "$(command -v certbot)" ]; then
  sudo apt-get update
  sudo apt-get install -y software-properties-common
  LC_ALL=C.UTF-8 sudo add-apt-repository -y ppa:certbot/certbot
  sudo apt-get update
  sudo apt-get install -y certbot
fi

# check registered
printf "checking if registered...\n"
certbot register
if [ $? -eq 0 ]; then
  printf "assuming you went through registration...\n"
else
  printf "already registered!\n"
fi

CERTBOT_CMD='certbot certonly --non-interactive --keep-until-expiring --post-hook "sudo service nginx reload" --cert-name'

# PROMPT - Certificate name
read -p "Certificate name, eg your-site.com:" CERTNAME

CERTBOT_CMD="$CERTBOT_CMD $CERTNAME"

# PROMPT - domains to secure, eg. yoursite.com,www.yoursite.com
read -p "Domain to secure, eg. yoursite.com,www.yoursite.com: " SITEDOMAINS

for i in $(echo $SITEDOMAINS | sed "s/,/ /g")
do
  # PROMPT - webroot for domain $i
  read -p "Webroot for domain $i, eg. /var/www/yoursite.com/app/dist or /var/www/yoursite.com/current/html: " CUR_WEBROOT

  # APPEND
  CERTBOT_CMD="$CERTBOT_CMD --webroot -w $CUR_WEBROOT -d $i"
done

# if you forgot www.your-site.com and go to add it and nginx has config to redirect to https://yoursite.com
# the cert could fail to validate via webroot challenge so you may want to convert back to non ssl and no redirects before
# running this. This is a weird case that could happen though.
eval $CERTBOT_CMD


# NGINX SSL CERT CODE?
read -p "Do you want to create a cron for this cert?. (y)|(n): " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # PROMPT - for the main domain
  read -p "Main domain to use for name of command to run on cron, eg. yoursite.com: " DOMAIN

  # Save command as script
  echo "${CERTBOT_CMD}" > "cert-cron-scripts/$DOMAIN.sh"
  sudo chmod +x "cert-cron-scripts/$DOMAIN.sh"

  ## get current cron text
  if [ $(crontab -l | wc -c) -eq 0 ]; then
    echo crontab is empty
    touch curcron
  else
    crontab -l > curcron
  fi

  #echo new cron into cron file ...


  # * * * * * "command to be executed"
  # - - - - -
  # | | | | |
  # | | | | ----- Day of week (0 - 7) (Sunday=0 or 7)
  # | | | ------- Month (1 - 12)
  # | | --------- Day of month (1 - 31)
  # | ----------- Hour (0 - 23)
  # ------------- Minute (0 - 59)

  # a */12 in second from left would mean every 12 hours (the slash makes it an every...)
  echo "* */12 * * * /var/www/LEMP-setup-guide/scripts/cert-cron-scripts/$DOMAIN.sh" >> curcron
  #install new cron file
  crontab curcron
  rm curcron
fi


# NGINX SSL CERT CODE?
read -p "Do you want nginx SSL cert config to get generated? It will override what you have now. (y)|(n): " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # PROMPT - for the main domain
  read -p "Main domain to use for config, eg. yoursite.com: " DOMAIN

  # CREATE the domain_com variable eg yoursite_com
  echo "$DOMAIN" >> tempdomain.txt
  sed -i 's/\./_/g' tempdomain.txt
  DOMAIN_COM=$(cat tempdomain.txt)
  rm tempdomain.txt

  rm /etc/nginx/sites-available/"$DOMAIN.conf"

  # NGINX - Proxy or not to proxy?
  read -p "Do you need to setup nginx config with upstreams and php? (y)|(n): " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
      # Create nginx config for php streams
      cp /var/www/LEMP-setup-guide/config/site.nginx.ssl.conf /etc/nginx/sites-available/"$DOMAIN.conf"
  else
      # Create nginx config with proxy pass
      cp /var/www/LEMP-setup-guide/config/site.nginx.vueapp.ssl.conf /etc/nginx/sites-available/"$DOMAIN.conf"
  fi

  cd /etc/nginx/sites-available/
  sed -i "s/SITEDOTCOM/${DOMAIN}/g;" "$DOMAIN.conf"
  sed -i "s/SITE_COM/${DOMAIN_COM}/g;" "$DOMAIN.conf"
  sed -i "s/WEBROOTPATH/${WEBROOTPATH}/g;" "$DOMAIN.conf"

  # nginx - handle current path stuff -
  # if /var/www/$DOMAIN/current exists, need to sed nginx config to swap paths
  if [ -d "/var/www/$DOMAIN/current" ]; then
    # For lines that do not contain '/var/www/${DOMAIN}/current', replace '/var/www/${DOMAIN}/' with '/var/www/${DOMAIN}/current/'
    sed -i "/var\/www\/${DOMAIN}\/current/!s/var\/www\/${DOMAIN}\//var\/www\/${DOMAIN}\/current\//g" "$DOMAIN.conf"
  fi

  # This may already exist...
  ln -s /etc/nginx/sites-available/"${DOMAIN}.conf" /etc/nginx/sites-enabled/

  # Test nginx config
  sudo nginx -t

  # if nginx test is good - reload nginx
  if [ $? -eq 0 ]; then
    sudo service nginx reload
  fi
else
    printf "okay, bye!\n"
fi
