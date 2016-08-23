#!/bin/bash
# Install packages needed for mythtv scripts

sudo apt-get install jq mediainfo libiec61883-dev wakeonlan libxml2-utils curl xprintidle sysstat mysql-client figlet

sudo apt-get install fswebcam

if [[ `arch` == x86_64 ]] ; then
    wget -q -O - https://www.bunkus.org/gpg-pub-moritzbunkus.txt | sudo apt-key add -
    sudo apt-get install mkvtoolnix

    sudo add-apt-repository ppa:stebbins/handbrake-releases
    sudo apt-get install handbrake-cli
fi


