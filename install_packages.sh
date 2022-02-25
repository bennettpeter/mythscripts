#!/bin/bash
# Install packages needed for mythtv scripts

# for x86/x86_64 only
sudo apt install jq mediainfo libiec61883-dev wakeonlan libxml2-utils curl \
  xprintidle sysstat mysql-client figlet python3-natsort gdebi-core dos2unix acpi sox \
  xdotool

# raspberry pi
sudo apt install figlet gdebi-core dos2unix wakeonlan

# raspberry pi proxy
sudo apt install screen weechat

# raspberry pi dev
sudo apt install git ansible

# webcam
sudo apt install fswebcam

# These are for backend
sudo apt install xmltv apache2 php php-mysql mysql-server

# For firetv recorder on backend
sudo apt install gocr tesseract-ocr imagemagick vlc obs-studio jp2a
# Manuallt put latest adb in /usr/local/bin/adb

if [[ `arch` == x86_64 ]] ; then
#    wget -q -O - https://www.bunkus.org/gpg-pub-moritzbunkus.txt | sudo apt-key add -
    # Add this to /etc/apt/sources.list.d/mkvtoolnix.download.list:
#deb https://mkvtoolnix.download/ubuntu/ bionic main
#deb-src https://mkvtoolnix.download/ubuntu/ bionic main
#    sudo add-apt-repository ppa:stebbins/handbrake-releases

#    sudo apt update
    sudo apt install mkvtoolnix handbrake-cli ffmpeg
fi


