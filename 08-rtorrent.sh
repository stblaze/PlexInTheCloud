#!/bin/bash
source vars

## INFO
# This script installs and configures rtorrent
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
apt-get install -y tmux

#######################
# Install
#######################
apt-get install -y rtorrent

#######################
# Setup
#######################
mkdir -p /home/$username/rtorrent

#######################
# Configure
#######################
tee "/home/$username/.rtorrent.rc" > /dev/null <<EOF
# Maximum and minimum number of peers to connect to per torrent.
# rtorrent will connect aggressively until it reaches the minimum,
# but stop connecting to new clients when it reaches max.
min_peers = 40  
max_peers = 150

# Same as above but for seeding completed torrents (-1 = same as downloading)
min_peers_seed = 250  
max_peers_seed = 5000

# Maximum number of simultaneous uploads per torrent.
max_uploads = 30

# Global upload and download rate in KiB. "0" for unlimited.
download_rate = 0
upload_rate = 0

# Default directory to save the downloaded torrents.
directory = /home/$username/rutorrent/torrent/download

# Session folder used by rtorrent to store current data
session = /home/$username/rtorrent/session
session.use_lock.set = yes

# Run the rtorrent process as a daemon in the background
#system.daemon.set = true

# Stop torrents when diskspace is low.
schedule = low_diskspace,5,60,close_low_diskspace=1024M

# Port range to use for listening.
port_range = $torrentPort-$torrentPort

# Start opening ports at a random position within the port range.
port_random = no

# Check hash for finished torrents to confirm that the files are correct
check_hash = yes

# Set whether the client should try to connect to UDP trackers.
use_udp_trackers = yes

# Allow encrypted connection and retry with encryption if it fails.
#encryption = allow_incoming,enable_retry,prefer_plaintext
encryption = allow_incoming,try_outgoing,enable_retry

# Disabled DHT and peer exchange. (You can remove this if you're only using public trackers)
dht = disable  
peer_exchange = no

# Finally, the SCGI port rtorrent will be listening on, for communication via ruTorrent
scgi_port = 127.0.0.1:5040
#execute2 = {sh,-c,/usr/bin/php /var/www/rutorrent/php/initplugins.php $username &}
EOF

#######################
# Structure
#######################
mkdir -p /home/$username/rtorrent/session
mkdir -p /home/$username/rtorrent/torrent/{complete/{movie/couchpotato,music,tv/sonarr,game,book,software,other},download/{movie/couchpotato,music,tv/sonarr,game,book,software,other},watch/{movie/couchpotato,music,tv/sonarr,game,book,software,other}} Media/{Movies,'TV Shows'}

#######################
# Systemd Service File
#######################
tee "/etc/systemd/system/rtorrent.service" > /dev/null <<EOF
[Unit]
Description=rTorrent
Requires=network.target local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
KillMode=none
User=$username
ExecStart=/usr/bin/tmux new-session -s rt -n rtorrent -d rtorrent
ExecStop=/usr/bin/tmux send-keys -t rt:rtorrent C-q

[Install]
WantedBy=multi-user.target
EOF

#######################
# Permissions
#######################
chown -R $username:$username /home/$username/rtorrent
chown $username:$username /home/$username/.rtorrent.rc
chmod -R 0755 /home/$username/rtorrent

#######################
# Remote Access
#######################
ufw allow $torrentPort

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl start rtorrent
systemctl enable rtorrent
