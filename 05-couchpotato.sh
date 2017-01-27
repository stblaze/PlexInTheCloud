#!/bin/bash
source vars

## INFO
# This script installs and configures couchpotato
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
apt-get install -y git-core libffi-dev libssl-dev zlib1g-dev libxslt1-dev libxml2-dev python python-pip python-dev build-essential

pip install lxml cryptography pyopenssl

#######################
# Install
#######################
git clone https://github.com/CouchPotato/CouchPotatoServer.git /opt/couchpotato/

# Run it for the first time so it creates the default config file
su $username <<EOF
cd /home/$username
timeout 5s python /opt/couchpotato/CouchPotato.py
EOF

#######################
# Configure
#######################
## Write CouchPotato API to nzbget.conf so it can send post-processing requests
### Copy the api key from the CP config file
cpAPI=$(cat /home/$username/.couchpotato/settings.conf | grep "api_key = ................................" | cut -d= -f 2)

### Cut the single blank space that always gets added to the front of $cpAPI
cpAPInew="$(sed -e 's/[[:space:]]*$//' <<<${cpAPI})"

### Write the API key to nzbget.conf
sed -i "s/^nzbToCouchPotato.py:cpsapikey=.*/nzbToCouchPotato.py:cpsapikey=$cpAPInew/g" /opt/nzbget/nzbget.conf

## Configure CouchPotato
### CouchPotato stores our passwords as md5sum hashes...heh heh heh
cppassword=$(echo -n $passwd | md5sum | cut -d ' ' -f 1)
sed -i "/\[core\]/,/^$/ s/username = .*/username = $username/" /home/$username/.couchpotato/settings.conf
sed -i "/\[core\]/,/^$/ s/password = .*/password = $cppassword/" /home/$username/.couchpotato/settings.conf

### blackhole
sed -i '/\[blackhole\]/,/^$/ s/enabled = .*/enabled = 0/' /home/$username/.couchpotato/settings.conf

### nzbget
sed -i '/\[nzbget\]/,/^$/ s/enabled = .*/enabled = 1/' /home/$username/.couchpotato/settings.conf
sed -i "/\[nzbget\]/,/^$/ s/password = .*/password = $passwd/" /home/$username/.couchpotato/settings.conf
sed -i "/\[nzbget\]/,/^$/ s/username = .*/username = $username/" /home/$username/.couchpotato/settings.conf
sed -i "/\[nzbget\]/,/^$/ s/category = .*/category = movies/" /home/$username/.couchpotato/settings.conf

### nzb
sed -i "s/^retention =.*/retention = $nsRetention/g" /home/$username/.couchpotato/settings.conf

### subtitles
sed -i '/\[subtitle\]/,/^$/ s/languages = .*/languages = en/' /home/$username/.couchpotato/settings.conf
sed -i '/\[subtitle\]/,/^$/ s/force = .*/force = False/' /home/$username/.couchpotato/settings.conf
sed -i '/\[subtitle\]/,/^$/ s/enabled = .*/enabled = 1/' /home/$username/.couchpotato/settings.conf

### renamer
sed -i '/\[renamer\]/,/^$/ s/enabled = .*/enabled = 1/' /home/$username/.couchpotato/settings.conf
sed -i '/\[renamer\]/,/^$/ s/file_name = .*/file_name = <thename>-<year>.<ext>/' /home/$username/.couchpotato/settings.conf
sed -i '/\[renamer\]/,/^$/ s/next_on_failed = .*/next_on_failed = 0/' /home/$username/.couchpotato/settings.conf
sed -i "/\[renamer\]/,/^$/ s|from = .*|from = /home/$username/nzbget/completed/movies|" /home/$username/.couchpotato/settings.conf
sed -i "/\[renamer\]/,/^$/ s|to = .*|to = /home/$username/$local/movies|" /home/$username/.couchpotato/settings.conf
sed -i '/\[renamer\]/,/^$/ s/cleanup = .*/cleanup = 1/' /home/$username/.couchpotato/settings.conf
sed -i '/\[renamer\]/,/^$/ s/unrar_modify_date = .*/unrar_modify_date = 1/' /home/$username/.couchpotato/settings.conf
sed -i '/\[renamer\]/,/^$/ s/run_every = .*/run_every = 0/' /home/$username/.couchpotato/settings.conf
sed -i '/\[renamer\]/,/^$/ s/force_every = .*/force_every = 24/' /home/$username/.couchpotato/settings.conf

## Post Processing
## NZBget
sed -i "s/^Category1.Name=.*/Category1.Name=movies/g" /opt/nzbget/nzbget.conf
sed -i "s|^Category1.DestDir=.*|Category1.DestDir=/home/$username/nzbget/completed/movies|g" /opt/nzbget/nzbget.conf
sed -i "s/^Category1.PostScript=.*/Category1.PostScript=nzbToCouchPotato.py, Logger.py, uploadMovies.sh/g" /opt/nzbget/nzbget.conf

# nzbToCouchPotato
sed -i 's/^nzbToCouchPotato.py:auto_update=.*/nzbToCouchPotato.py:auto_update=1/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToCouchPotato.py:cpsCategory=.*/nzbToCouchPotato.py:cpsCategory=movies/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToCouchPotato.py:cpsdelete_failed=.*/nzbToCouchPotato.py:cpsdelete_failed=1/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToCouchPotato.py:getSubs=.*/nzbToCouchPotato.py:getSubs=1/g' /opt/nzbget/nzbget.conf
sed -i "s/^nzbToCouchPotato.py:subLanguages=.*/nzbToCouchPotato.py:subLanguages=$openSubtitlesLang/g" /opt/nzbget/nzbget.conf
sed -i "s|^nzbToCouchPotato.py:cpswatch_dir=.*|nzbToCouchPotato.py:cpswatch_dir=/home/$username/nzbget/completed/movies|g" /opt/nzbget/nzbget.conf

#######################
# Structure
#######################
# Create our local directory
mkdir /home/$username/$local/movies

# Create our directory for completed downloads
mkdir /home/$username/nzbget/completed/movies

# Create our ACD directory
## Run the commands as our user since the rclone config is stored in the user's home directory and root can't access it.
su $username <<EOF
cd /home/$username
rclone mkdir $encrypted:movies
EOF

# Create our Plex library
# Must be done manually for now
echo ''
echo ''
echo 'Now you need to create your Plex TV Library.'
echo '1) In a browser open https://app.plex.tv/web/app'
echo '2) In the left hand side, click on "Add Library"'
echo '3) Select "Movies", leave the default name, and choose your preferred language before clicking "Next"'
echo "4) Click 'Browse for media folder' and navigate to /home/$username/$encrypted/movies"
echo '5) Click on the "Add" button and then click on "Add library"'
echo ''

# Create a Plex Token
token=$(curl -H "Content-Length: 0" -H "X-Plex-Client-Identifier: PlexInTheCloud" -u "${plexUsername}":"${plexPassword}" -X POST https://my.plexapp.com/users/sign_in.xml | cut -d "\"" -s -f22 | tr -d '\n')

# Grab the Plex Section ID of our new library
movieID=$(curl -H "X-Plex-Token: ${token}" http://127.0.0.1:32400/library/sections | grep "movie" | grep "title=" | awk -F = '{print $6" "$7" "$8}' | sed 's/ art//g' | sed 's/title//g' | sed 's/type//g' | awk -F \" '{print "Section=\""$6"\" ID="$2}' | cut -d '"' -f2)

#######################
# Helper Scripts
#######################
tee "/home/$username/nzbget/scripts/uploadMovies.sh" > /dev/null <<EOF
#!/bin/bash

#######################################
### NZBGET POST-PROCESSING SCRIPT   ###

# Rclone upload to Amazon Cloud Drive

# Wait for NZBget/Sickrage to finish moving files
sleep 10s

# Upload
rclone move -c /home/$username/$local/movies $encrypted:movies

# Tell Plex to update the Library
wget http://localhost:32400/library/sections/$movieID/refresh?X-Plex-Token=$token

# Send PP Success code
exit 93
EOF

#######################
# Systemd Service File
#######################
tee "/etc/systemd/system/couchpotato.service" > /dev/null <<EOF
[Unit]
Description=CouchPotato application instance
After=rcloneMount.service

[Service]
ExecStart=/opt/couchpotato/CouchPotato.py
Type=simple
User=$username
Group=$username

[Install]
WantedBy=multi-user.target
EOF

#######################
# Permissions
#######################
chown -R $username:$username /opt/couchpotato
chown -R $username:$username /home/$username/nzbget/completed/movies
chown -R $username:$username /home/$username/$local/movies
chmod +x /home/$username/nzbget/scripts/uploadMovies.sh
chown root:root /etc/systemd/system/couchpotato.service
chmod 644 /etc/systemd/system/couchpotato.service

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl start couchpotato
systemctl enable couchpotato
systemctl restart couchpotato

#######################
# Remote Access
#######################
echo ''
echo "Do you want to allow remote access to CouchPotato?"
echo "If so, you need to tell UFW to open the port."
echo "Otherwise, you can use SSH port forwarding."
echo ''
echo "Would you like us to open the port in UFW?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 5050; echo ''; echo "Port 5050 open, CouchPotato is now available over the internet."; echo ''; break;;
        No ) echo "Port 5050 left closed. You can still access it from your local machine by issuing the following command: ssh $username@$ipaddr -L 5050:localhost:5050"; echo "and then open localhost:5050 on your browser."; exit;;
    esac
done
