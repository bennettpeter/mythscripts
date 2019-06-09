#!/bin/bash
#systemd
#This is run before sleep, hibernate, etc.

# Prevent duplicate sleep requests
DATE=`date +%F\ %T\.%N`
DATADIR=/var/opt/mythtv
echo $DATE > $DATADIR/checklogin
chown mythtv:mythtv $DATADIR/checklogin

killall mythfrontend
# systemctl stop mythtv-backend.service

# Disable mouse wakeup
# first check if mouse wakeup enabled
# XHC	  S3	*enabled   pci:0000:00:14.0
if cat /proc/acpi/wakeup|grep "^XHC"$'\t'".*enabled" ; then
    echo XHC | tee /proc/acpi/wakeup
fi

env -i XDG_SEAT_PATH=/org/freedesktop/DisplayManager/Seat0 dm-tool switch-to-greeter

# systemctl stop mysql.service

# unmount NFS file systems
timeout 5s umount -a -l -f -t nfs,nfs4

# unmount encrypted file systems
set -- `findmnt -n -t fuse.encfs -o TARGET`
if [[ "$1" != "" ]] ; then
    umount -l -f "$@"
fi

exit 0
