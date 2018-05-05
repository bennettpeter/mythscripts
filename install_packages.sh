#!/bin/bash
# Install packages needed for mythtv scripts

sudo apt install jq mediainfo libiec61883-dev wakeonlan libxml2-utils curl xprintidle sysstat mysql-client figlet python3-natsort gdebi-core dos2unix

sudo apt install git

sudo apt install fswebcam

if [[ `arch` == x86_64 ]] ; then
    wget -q -O - https://www.bunkus.org/gpg-pub-moritzbunkus.txt | sudo apt-key add -
    # Add this to /etc/apt/sources.list.d/mkvtoolnix.download.list:
#deb https://mkvtoolnix.download/ubuntu/ bionic main
#deb-src https://mkvtoolnix.download/ubuntu/ bionic main
    sudo add-apt-repository ppa:stebbins/handbrake-releases

    sudo apt update
    sudo apt install mkvtoolnix handbrake-cli ffmpeg
fi


