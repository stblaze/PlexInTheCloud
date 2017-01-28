#!/bin/bash
source vars

## INFO
# This script installs and configures rutorrent
##

#######################
# Pre-Install
#######################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Execute 'sudo su' to swap to the root user." 
   exit 1
fi

#######################
# Dependencies
#######################
apt-get install -y nginx php php-cli php-fpm php-xmlrpc apache2-utils mediainfo unrar-free ffmpeg unzip

#######################
# Setup
#######################
rm -rf /etc/nginx/sites-available/default

tee "/etc/nginx/sites-available/rutorrent" > /dev/null <<EOF
# Forward PHP requests to php-fpm
upstream php-handler {  
  server unix:/run/php/php7.0-fpm.sock;
}

server {  
  listen 6060 default_server;

  root /var/www/rutorrent;
  index index.php index.html;

  server_name localhost;

  location /RPC2 {
    scgi_pass   127.0.0.1:5040;
    include     scgi_params;
  }

  # Send PHP files to our PHP handler
  location ~ .php$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass php-handler;
    fastcgi_index index.php;
    include fastcgi.conf;
  }

  # Password authentication
  location / {
    auth_basic "Restricted";
    auth_basic_user_file /var/www/rutorrent/.htpasswd;
  }
}

EOF

ln -s /etc/nginx/sites-available/rutorrent /etc/nginx/sites-enabled/rutorrent
systemctl restart nginx

#######################
# Install
#######################
git clone https://github.com/Novik/ruTorrent.git /var/www/rutorrent

#######################
# Configure
#######################
sed -i 's/$scgi_port =.*/$scgi_port = 5040;/g' /var/www/rutorrent/conf/config.php
sed -i 's/$scgi_host =.*/$scgi_host = "127.0.0.1";/g' /var/www/rutorrent/conf/config.php

htpasswd -b -c /var/www/rutorrent/.htpasswd $username $passwd

sed -i "s/^AuthName .*/AuthName \"$username\"/g" /var/www/rutorrent/.htaccess
sed -i 's|^AuthUserFile .*|AuthUserFile "/var/www/rutorrent/.htpasswd"|g' /var/www/rutorrent/.htaccess

#######################
# Structure
#######################
mkdir -p /home/$username/rutorrent/

#######################
# Permissions
#######################
chown -R $username:$username /home/$username/rutorrent
chown -R :www-data /var/www/rutorrent
chown :root /var/www/rutorrent/.htpasswd
chmod -R 774 /var/www/rutorrent
chmod 644 /var/www/rutorrent/.htpasswd

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl enable nginx

#######################
# Remote Access
#######################
echo ''
echo "Do you want to allow remote access to ruTorrent?"
echo "If so, you need to tell UFW to open the port."
echo "Otherwise, you can use SSH port forwarding."
echo ''
echo "Would you like us to open the port in UFW?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 6060; echo ''; echo "Port 6060 open, ruTorrent is now available over the internet."; echo ''; break;;
        No ) echo "Port 6060 left closed. You can still access it from your local machine by issuing the following command: ssh $username@$ipaddr -L 6060:localhost:6060"; echo "and then open localhost:6060 on your browser."; break;;
    esac
done

#######################
# Misc.
#######################
adduser $username www-data

echo ''
echo "We need to reboot the machine now."
echo ''
echo "Are you ready to reboot?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo ''; echo "Rebooting Now."; echo ''; reboot -h now; break;;
        No ) echo "Ok, but you'll need to reboot before rutorrent will function properly."; exit;;
    esac
done
