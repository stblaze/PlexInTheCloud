#!/bin/bash
source vars

## INFO
# This script installs and configures sickrage
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
apt-get install -y unrar-free git-core openssl libssl-dev python2.7

#######################
# Install
#######################
git clone https://github.com/SickRage/SickRage.git /opt/sickrage/

# Run SickRage for the first time to create default config files
timeout 5s python /opt/sickrage/SickBeard.py

#######################
# Configure
#######################
sed -i "s/^tv_download_dir =.*/tv_download_dir = \/home\/$username\/nzbget\/completed\/tv/g" /opt/sickrage/config.ini
sed -i "s/^root_dirs =.*/root_dirs = 0|\/home\/$username\/$overlayfuse\/tv/g" /opt/sickrage/config.ini
sed -i "s|naming_pattern =.*|naming_pattern = Season %0S\\\%S_N-S%0SE%0E-%E_N-%Q_N|g" /opt/sickrage/config.ini

sed -i "s/^web_username =.*/web_username = $username/g" /opt/sickrage/config.ini
sed -i "s/^web_password =.*/web_password = $passwd/g" /opt/sickrage/config.ini

sed -i "s/^nzbget_username =.*/nzbget_username = $username/g" /opt/sickrage/config.ini
sed -i "s/^nzbget_password =.*/nzbget_password = $passwd/g" /opt/sickrage/config.ini
sed -i "s/^nzbget_host =.*/nzbget_host = localhost:6789/g" /opt/sickrage/config.ini

sed -i "s/^use_nzbs =.*/use_nzbs = 1/g" /opt/sickrage/config.ini
sed -i "s/^nzb_method =.*/nzb_method = nzbget/g" /opt/sickrage/config.ini

sed -i "s/^opensubtitles_password =.*/opensubtitles_password = $openSubtitlesPassword/g" /opt/sickrage/config.ini
sed -i "s/^opensubtitles_username =.*/opensubtitles_username = $openSubtitlesUsername/g" /opt/sickrage/config.ini
sed -i "s/^subtitles_languages =.*/subtitles_languages = $openSubtitlesLang/g" /opt/sickrage/config.ini

sed -i 's/^SUBTITLES_SERVICES_LIST =.*/SUBTITLES_SERVICES_LIST = "opensubtitles,addic7ed,legendastv,shooter,subscenter,thesubdb,tvsubtitles"/g' /opt/sickrage/config.ini
sed -i "s/^use_subtitles =.*/use_subtitles = 1/g" /opt/sickrage/config.ini
sed -i 's/^SUBTITLES_SERVICES_ENABLED =.*/SUBTITLES_SERVICES_ENABLED = 1|0|0|0|0|0|0|0|0/g' /opt/sickrage/config.ini

sed -i "s/^use_failed_downloads =.*/use_failed_downloads = 1/g" /opt/sickrage/config.ini
sed -i "s/^delete_failed =.*/delete_failed = 1/g" /opt/sickrage/config.ini

## Post-Processing
# nzbget
sed -i "s/^Category2.Name=.*/Category2.Name=tv/g" /opt/nzbget/nzbget.conf
sed -i "s|^Category2.DestDir=.*|Category2.DestDir=/home/$username/nzbget/completed/tv|g" /opt/nzbget/nzbget.conf
sed -i "s/^Category2.PostScript=.*/Category2.PostScript=nzbToSickBeard.py, Logger.py, uploadTV.sh/g" /opt/nzbget/nzbget.conf

# nzbToSickBeard
sed -i 's/^nzbToSickBeard.py:auto_update=.*/nzbToSickBeard.py:auto_update=1/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToSickBeard.py:sbCategory=.*/nzbToSickBeard.py:sbCategory=tv/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToSickBeard.py:sbdelete_failed=.*/nzbToSickBeard.py:sbdelete_failed=1/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToSickBeard.py:getSubs=.*/nzbToSickBeard.py:getSubs=1/g' /opt/nzbget/nzbget.conf
sed -i "s/^nzbToSickBeard.py:subLanguages=.*/nzbToSickBeard.py:subLanguages=$openSubtitlesLang/g" /opt/nzbget/nzbget.conf
sed -i "s/^nzbToSickBeard.py:sbusername=.*/nzbToSickBeard.py:sbusername=$username/g" /opt/nzbget/nzbget.conf
sed -i "s/^nzbToSickBeard.py:sbpassword=.*/nzbToSickBeard.py:sbpassword=$passwd/g" /opt/nzbget/nzbget.conf
sed -i "s|^nzbToSickBeard.py:sbwatch_dir=.*|nzbToSickBeard.py:sbwatch_dir=/home/$username/nzbget/completed/tv|g" /opt/nzbget/nzbget.conf

#######################
# Structure
#######################
# Create our local directory
mkdir -p /home/$username/$local/tv

# Create our directory for completed downloads
mkdir -p /home/$username/nzbget/completed/tv

# Create our ACD directory
## Run the commands as our user since the rclone config is stored in the user's home directory and root can't access it.
su $username <<EOF
cd /home/$username
rclone mkdir $encrypted:tv
EOF

# Create our Plex library
# Must be done manually for now
echo ''
echo ''
echo 'Now you need to create your Plex TV Library.'
echo '1) In a browser open https://app.plex.tv/web/app'
echo '2) In the left hand side, click on "Add Library"'
echo '3) Select "TV Shows", leave the default name, and choose your preferred language before clicking "Next"'
echo "4) Click 'Browse for media folder' and navigate to /home/$username/$encrypted/tv"
echo '5) Click on the "Add" button and then click on "Add library"'
echo ''

# Create a Plex Token
token=$(curl -H "Content-Length: 0" -H "X-Plex-Client-Identifier: PlexInTheCloud" -u "${plexUsername}":"${plexPassword}" -X POST https://my.plexapp.com/users/sign_in.xml | cut -d "\"" -s -f22 | tr -d '\n')

# Grab the Plex Section ID of our new library
tvID=$(curl -H "X-Plex-Token: ${token}" http://127.0.0.1:32400/library/sections | grep "show" | grep "title=" | awk -F = '{print $6" "$7" "$8}' | sed 's/ art//g' | sed 's/title//g' | sed 's/type//g' | awk -F \" '{print "Section=\""$6"\" ID="$2}' | cut -d '"' -f2)

#######################
# Helper Scripts
#######################
tee "/home/$username/nzbget/scripts/uploadTV.sh" > /dev/null <<EOF
#!/bin/bash

#######################################
### NZBGET POST-PROCESSING SCRIPT   ###

# Rclone upload to Amazon Cloud Drive

# Wait for NZBget/Sickrage to finish moving files
sleep 10s

# Upload
rclone move -c /home/$username/$local/tv $encrypted:tv

# Tell Plex to update the Library
wget http://localhost:32400/library/sections/$tvID/refresh?X-Plex-Token=$token

# Send PP Success code
exit 93
EOF

#######################
# Systemd Service File
#######################
tee "/etc/systemd/system/sickrage.service" > /dev/null <<EOF
[Unit]
Description=SickRage Daemon
After=rcloneMount.service

[Service]
User=$username
Group=$username

Type=forking
GuessMainPID=no
ExecStart=/usr/bin/python2.7 /opt/sickrage/SickBeard.py -q --daemon --nolaunch --datadir=/opt/sickrage

[Install]
WantedBy=multi-user.target
EOF

#######################
# Permissions
#######################
chown -R $username:$username /home/$username/$local/tv
chown -R $username:$username /opt/sickrage
chmod +x /home/$username/nzbget/scripts/uploadTV.sh
chown root:root /etc/systemd/system/sickrage.service
chmod 644 /etc/systemd/system/sickrage.service

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl start sickrage
systemctl enable sickrage

#######################
# Remote Access
#######################
echo ''
echo "Do you want to allow remote access to Sickrage?"
echo "If so, you need to tell UFW to open the port."
echo "Otherwise, you can use SSH port forwarding."
echo ''
echo "Would you like us to open the port in UFW?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 8081; echo ''; echo "Port 8081 open, Sickrage is now available over the internet."; echo ''; break;;
        No ) echo "Port 8081 left closed. You can still access it on your local machine by issuing the following command: ssh $username@$ipaddr -L 8081:localhost:8081"; echo "and then open localhost:8081 on your browser."; exit;;
    esac
done
