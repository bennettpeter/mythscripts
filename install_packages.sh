#!/bin/bash
# Install packages needed for mythtv scripts

if [[ `arch` == x86_64 ]] ; then
    # for x86/x86_64 only
    apt install jq mediainfo libiec61883-dev wakeonlan libxml2-utils curl \
      xprintidle sysstat mysql-client figlet python3-natsort gdebi-core dos2unix acpi sox \
      xdotool python-is-python3 openssh-server x11vnc screen mkvtoolnix handbrake-cli ffmpeg \
      nfs-common nfs-kernel-server gnome-system-monitor
fi

apt install vim xfce4-genmon-plugin
update-alternatives --set editor /usr/bin/vim.basic

if [[ `arch` == arm* ]] ; then
    # raspberry pi
    apt install figlet gdebi-core dos2unix wakeonlan \
        nfs-common nfs-kernel-server

    # raspberry pi proxy
    # apt install screen weechat

    # webcam
    # apt install fswebcam
fi

echo "Backend machine? (Y|N)"
read -e ans
if [[ "$ans" == Y ]] ; then
    # These are for backend
    apt install xmltv mysql-server comskip
#    apt install xmltv apache2 php php-mysql mysql-server comskip
    echo "FireTV Recorder machine? (Y|N)"
    read -e ans
    if [[ "$ans" == Y ]] ; then
        # For firetv recorder on backend
        apt install gocr tesseract-ocr imagemagick vlc jp2a pv
        if [[ ! -f /usr/local/bin/adb ]] ; then
            echo XXXXXX Please Manually put latest adb in /usr/local/bin/adb
        fi
    fi
fi
