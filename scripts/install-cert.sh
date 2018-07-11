# check for certbot
if ! [ -x "$(command -v certbot)" ]; then
  sudo apt-get update
  sudo apt-get install -y software-properties-common
  LC_ALL=C.UTF-8 sudo add-apt-repository -y ppa:certbot/certbot
  sudo apt-get update
  sudo apt-get install -y python-certbot-nginx 

fi

sudo certbot --nginx