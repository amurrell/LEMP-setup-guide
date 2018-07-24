# check for certbot
if ! [ -x "$(command -v certbot)" ]; then
  sudo apt-get update
  sudo apt-get install -y software-properties-common
  LC_ALL=C.UTF-8 sudo add-apt-repository -y ppa:certbot/certbot
  sudo apt-get update
  sudo apt-get install -y python-certbot-nginx 

fi

CERTBOT_CMD='certbot certonly --cert-name'

# PROMPT - Certificate name
read -p "Certificate name, eg mysitescerts:" CERTNAME

CERTBOT_CMD="$CERTBOT_CMD $CERTNAME"

# PROMPT - domains to secure, eg. yoursite.com,www.yoursite.com
read -p "Domain to secure, eg. yoursite.com,www.yoursite.com:" SITEDOMAINS


for i in $(echo $SITEDOMAINS | sed "s/,/ /g")
do
  # PROMPT - webroot for domain $i
  read -p "Webroot for domain $i, eg. /var/www/yoursite.com/app/dist" CUR_WEBROOT

  # APPEND
  CERTBOT_CMD="$CERTBOT_CMD --webroot -w $CUR_WEBROOT -d $i"
done

printf "The command to run is:\n"
printf "$CERTBOT_CMD\n"

# NGINX SSL CERT CODE?
read -p "Do you want nginx SSL cert config to get generated? It will override what you have now..." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # PROMPT - for the main domain
  read -p "Main domain to use for config, eg. yoursite.com" DOMAIN

  # CREATE the domain_com variable eg yoursite_com
  echo "$DOMAIN" >> tempdomain.txt
  sed -i 's/\./_/g' tempdomain.txt
  DOMAIN_COM=$(cat tempdomain.txt)
  rm tempdomain.txt

  # NGINX - Proxy or not to proxy?
  read -p "Do you need to setup nginx config with upstreams and php?" -n 1 -r
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
