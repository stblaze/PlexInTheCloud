#!/bin/bash
source vars

## INFO
# Installs and configures mylar
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
apt-get install python-cherrypy
pip install tzlocal

#######################
# Install
#######################
git clone https://github.com/evilhero/mylar /opt/mylar/

# Run it for the first time so it creates the default config file
timeout 5s python /opt/mylar/Mylar.py

#######################
# Configure
#######################
sed -i "s/^http_username =.*/http_username = $username/g" /opt/mylar/config.ini
sed -i "s/^http_password =.*/http_password = $passwd/g" /opt/mylar/config.ini
sed -i "s/^comicvine_api =.*/comicvine_api = $comicvineAPI/g" /opt/mylar/config.ini
sed -i "s/^annuals_on =.*/annuals_on = 1/g" /opt/mylar/config.ini
sed -i "s|^destination_dir =.*|destination_dir = /home/$username/$local/comics|g" /opt/mylar/config.ini
sed -i "s/^create_folders =.*/create_folders = 1/g" /opt/mylar/config.ini
sed -i "s/^enforce_perms =.*/enforce_perms = 1/g" /opt/mylar/config.ini
sed -i "s/^chmod_dir =.*/chmod_dir = 0775/g" /opt/mylar/config.ini
sed -i "s/^chmod_file =.*/chmod_file = 0660/g" /opt/mylar/config.ini
sed -i "s/^chowner =.*/chowner = $username/g" /opt/mylar/config.ini
sed -i "s/^chgroup =.*/chgroup = $username/g" /opt/mylar/config.ini
sed -i "s/^usenet_retention =.*/usenet_retention = $nsRetention/g" /opt/mylar/config.ini
sed -i "s/^nzb_startup_search =.*/nzb_startup_search = 1/g" /opt/mylar/config.ini
sed -i "s|^comic_dir =.*|comic_dir = /home/$username/$encrypted/comics|g" /opt/mylar/config.ini
sed -i "s/^dupeconstraint =.*/dupeconstraint = filetype-cbz/g" /opt/mylar/config.ini
sed -i "s/^autowant_all =.*/autowant_all = 1/g" /opt/mylar/config.ini
sed -i "s/^autowant_upcoming =.*/autowant_upcoming = 1/g" /opt/mylar/config.ini
sed -i "s/^comic_cover_local =.*/comic_cover_local = 1/g" /opt/mylar/config.ini
sed -i "s/^correct_metadata =.*/correct_metadata = 0/g" /opt/mylar/config.ini
sed -i "s/^rename_files =.*/rename_files = 1/g" /opt/mylar/config.ini
sed -i 's/^folder_format =.*/folder_format = $Series ($Year)/g' /opt/mylar/config.ini
sed -i 's/^file_format =.*/file_format = $Series $Issue ($Year)/g' /opt/mylar/config.ini
sed -i "s/^zero_level =.*/zero_level = 1/g" /opt/mylar/config.ini
sed -i "s/^zero_level_n =.*/zero_level_n = 00x/g" /opt/mylar/config.ini
sed -i "s/^add_to_csv =.*/add_to_csv = 1/g" /opt/mylar/config.ini
sed -i "s/^cvinfo =.*/cvinfo = 1/g" /opt/mylar/config.ini
sed -i "s/^enable_meta =.*/enable_meta = 1/g" /opt/mylar/config.ini
sed -i "s/^cbr2cbz_only =.*/cbr2cbz_only = 1/g" /opt/mylar/config.ini
sed -i "s/^ct_tag_cr =.*/ct_tag_cr = 1/g" /opt/mylar/config.ini
sed -i "s/^ct_tag_cbl =.*/ct_tag_cbl = 1/g" /opt/mylar/config.ini
sed -i "s/^ct_cbz_overwrite =.*/ct_cbz_overwrite = 1/g" /opt/mylar/config.ini
sed -i "s/^failed_download_handling =.*/failed_download_handling = 1/g" /opt/mylar/config.ini
sed -i "s/^failed_auto =.*/failed_auto = 1/g" /opt/mylar/config.ini
sed -i "s/^nzb_downloader =.*/nzb_downloader = 1/g" /opt/mylar/config.ini

sed -i "/\[NZBGet\]/,/^$/ s/nzbget_host = .*/nzbget_host = localhost/" /opt/mylar/config.ini
sed -i "/\[NZBGet\]/,/^$/ s/nzbget_port = .*/nzbget_port = 6789/" /opt/mylar/config.ini
sed -i "/\[NZBGet\]/,/^$/ s/nzbget_username = .*/nzbget_username = $username/" /opt/mylar/config.ini
sed -i "/\[NZBGet\]/,/^$/ s/nzbget_password = .*/nzbget_password = $passwd/" /opt/mylar/config.ini
sed -i "/\[NZBGet\]/,/^$/ s/nzbget_category = .*/nzbget_category = comics/" /opt/mylar/config.ini
sed -i "/\[NZBGet\]/,/^$/ s|nzbget_directory = .*|nzbget_directory = /home/$username/nzbget/completed/comics|" /home/$username/.couchpotato/settings.conf


## Post Processing
## NZBget
sed -i "s/^Category4.Name=.*/Category4.Name=comics/g" /opt/nzbget/nzbget.conf
sed -i "s|^Category4.DestDir=.*|Category4.DestDir=/home/$username/nzbget/completed/comics|g" /opt/nzbget/nzbget.conf
sed -i "s/^Category4.PostScript=.*/Category4.PostScript=nzbToMylar.py, Logger.py, uploadComics.sh/g" /opt/nzbget/nzbget.conf

# nzbToMylar
sed -i 's/^nzbToMylar.py:auto_update=.*/nzbToMylar.py:auto_update=1/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToMylar.py:myCategory=.*/nzbToMylar.py:myCategory=comics/g' /opt/nzbget/nzbget.conf
sed -i "s/^nzbToMylar.py:myusername=.*/nzbToMylar.py:myusername=$username/g" /opt/nzbget/nzbget.conf
sed -i "s/^nzbToMylar.py:mypassword=.*/nzbToMylar.py:mypassword=$passwd/g" /opt/nzbget/nzbget.conf
sed -i "s|^nzbToMylar.py:mywatch_dir=.*|nzbToMylar.py:mywatch_dir=/home/$username/nzbget/completed/comics|g" /opt/nzbget/nzbget.conf

#######################
# Structure
#######################
# Create our local directory
mkdir /home/$username/$local/comics

# Create our directory for completed downloads
mkdir /home/$username/nzbget/completed/comics

# Create our ACD directory
## Run the commands as our user since the rclone config is stored in the user's home directory and root can't access it.
su $username <<EOF
cd /home/$username
rclone mkdir $encrypted:comics
EOF

#######################
# Helper Scripts
#######################
tee "/home/$username/nzbget/scripts/uploadComics.sh" > /dev/null <<EOF
#!/bin/bash

#######################################
### NZBGET POST-PROCESSING SCRIPT   ###

# Rclone upload to Amazon Cloud Drive

# Wait for NZBget/Sickrage to finish moving files
sleep 10s

# Upload
rclone move -c /home/$username/$local/comics $encrypted:comics

# Send PP Success code
exit 93
EOF

#######################
# Systemd Service File
#######################
tee "/etc/systemd/system/mylar.service" > /dev/null <<EOF
[Unit]
Description=Mylar - Comic book downloader

[Service]
Type=forking
User=$username
Group=$username
ExecStart=/usr/bin/python /opt/mylar/Mylar.py --daemon --datadir=/opt/mylar --config=/opt/mylar/config.ini --quiet --nolaunch
GuessMainPID=no

[Install]
WantedBy=multi-user.target
EOF

#######################
# Permissions
#######################
chown -R $username:$username /opt/mylar
chmod +x /home/$username/nzbget/scripts/uploadComics.sh
chown -R $username:$username /home/$username/$local/comics
chown -R $username:$username /home/$username/nzbget/completed/comics

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl start mylar
systemctl enable mylar

#######################
# Remote Access
#######################
echo ''
echo "Do you want to allow remote access to Mylar?"
echo "If so, you need to tell UFW to open the port."
echo "Otherwise, you can use SSH port forwarding."
echo ''
echo "Would you like us to open the port in UFW?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 8090; echo ''; echo "Port 8090 open, Mylar is now available over the internet."; echo ''; break;;
        No ) echo "Port 8090 left closed. You can still access it on your local machine by issuing the following command: ssh $username@$ipaddr -L 8090:localhost:8090"; echo "and then open localhost:8090 on your browser."; exit;;
    esac
done
