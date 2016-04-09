#!/bin/bash
# Install packages needed for mythtv scripts
sudo apt-get install jq
sudo apt-get install mediainfo
sudo apt-get install libiec61883-dev
sudo apt-get install wakeonlan
sudo apt-get install libxml2-utils
sudo apt-get install curl
sudo apt-get install xprintidle

sudo apt-get install jq mediainfo libiec61883-dev wakeonlan libxml2-utils curl xprintidle sysstat ffmpeg


# Add to repos
# mkvtoolnix
# /etc/apt/sources.list
#deb http://www.bunkus.org/ubuntu/precise/ ./
#deb-src http://www.bunkus.org/ubuntu/precise/ ./
wget -q -O - https://www.bunkus.org/gpg-pub-moritzbunkus.txt | sudo apt-key add -
sudo apt-get install mkvtoolnix
# Install ffmpeg & ccextractor in /opt/ffmpeg/bin
# there is alread a /usr/bin/mythccextractor is that the same?

sudo add-apt-repository ppa:stebbins/handbrake-releases
sudo apt-get install handbrake-cli

# Kodi
sudo apt-get install figlet
sudo apt-get install libnfs1 
#libnfs1 not on jessie - maybe libnfs4
sudo apt-get install wakeonlan

sudo apt-get install fswebcam

#Raspi mythtv
sudo apt-get install libxml2-utils

