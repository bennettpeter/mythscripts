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
    sleep 5
    usbreset $RESET_USB
fi

# systemctl restart transmission-daemon.service

# hostname=`cat /etc/hostname`
#if [[ "$hostname" == andromeda ]] ; then
#    pacmd set-default-sink "alsa_output.pci-0000_00_03.0.hdmi-stereo-extra1"
#fi

sleep 30
if ! ip address | grep '192\.168\.1\.' ; then
    # if not at home, unmount encrypted file systems
    set -- `findmnt -n -t fuse.encfs -o TARGET`
    if [[ "$1" != "" ]] ; then
        umount -l -f "$@"
    fi
fi

exit 0
