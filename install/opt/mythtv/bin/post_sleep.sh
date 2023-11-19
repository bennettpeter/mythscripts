#!/bin/bash
#systemd
#This is run after sleep, hibernate, etc.

### CURRENTLY DISABLED ###

. /etc/opt/mythtv/mythtv.conf 

#if systemctl is-enabled mysql.service ; then
#    systemctl start mysql.service
#fi
# if systemctl is-enabled mythtv-backend.service ; then
#     systemctl start mythtv-backend.service
# fi

#if systemctl is-enabled nfs-client.target ; then
#    systemctl restart nfs-client.target
#fi

#if [[ "$IS_BACKEND" == true ]] && pidof mythbackend ; then
#    sudo -u mythtv mythutil --resched
#fi

# restart bluetooth when needed
if [[ "$RESTART_BLUETOOTH" == Y ]] ; then
    if systemctl is-enabled bluetooth.service ; then
        systemctl restart bluetooth.service
    fi
fi

# Reset keyboard/mouse
if [[ "$RESET_USB" != "" ]] ; then
    sleep 3
    usbreset $RESET_USB
fi

# systemctl restart transmission-daemon.service

# hostname=`cat /etc/hostname`
#if [[ "$hostname" == andromeda ]] ; then
#    pacmd set-default-sink "alsa_output.pci-0000_00_03.0.hdmi-stereo-extra1"
#fi

exit 0
