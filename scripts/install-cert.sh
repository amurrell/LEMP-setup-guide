# check for certbot
if ! [ -x "$(command -v certbot)" ]; then
  sudo apt-get update
  sudo apt-get install -y software-properties-common
  LC_ALL=C.UTF-8 sudo add-apt-repository -y ppa:certbot/certbot
  sudo apt-get update
  sudo apt-get install -y python-certbot-nginx 
fi

# check registered
printf "checking if registered...\n"
certbot register
if [ $? -eq 0 ]; then
  # registering
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
  read -p "Webroot for domain $i, eg. /var/www/yoursite.com/app/dist: " CUR_WEBROOT

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

  #echo new cron into cron file
  # 43 6 * * * certbot renew --post-hook "systemctl reload nginx"
  echo "00 09 * * 1-5 /var/www/LEMP-setup-guide/scripts/cert-cron-scripts/$DOMAIN.sh" >> curcron
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

  # NGINX - Proxy or not to proxy?
  read -p "Do you need to setup nginx config with upstreams and php? (y)|(n): " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
      # Create nginx site config with PHP upstreams
      rm /etc/nginx/sites-available/"$DOMAIN.conf"
      cp /var/www/LEMP-setup-guide/config/site.nginx.ssl.conf /etc/nginx/sites-available/"$DOMAIN.conf"
      cd /etc/nginx/sites-available/
      sed -i "s/SITEDOTCOM/${DOMAIN}/g;" "$DOMAIN.conf"
      sed -i "s/SITE_COM/${DOMAIN_COM}/g;" "$DOMAIN.conf"
      # This may already exist...
      ln -s /etc/nginx/sites-available/"${DOMAIN}.conf" /etc/nginx/sites-enabled/
  else
      # Create nginx config with proxy pass
      rm /etc/nginx/sites-available/"$DOMAIN.conf"
      cp /var/www/LEMP-setup-guide/config/site.nginx.vueapp.ssl.conf /etc/nginx/sites-available/"$DOMAIN.conf"
      cd /etc/nginx/sites-available/
      sed -i "s/SITEDOTCOM/${DOMAIN}/g;" "$DOMAIN.conf"
      sed -i "s/SITE_COM/${DOMAIN_COM}/g;" "$DOMAIN.conf"
      # This may already exist
      ln -s /etc/nginx/sites-available/"${DOMAIN}.conf" /etc/nginx/sites-enabled/
  fi

else
    printf "okay, bye!\n"
fi
