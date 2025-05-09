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

arr=($(ps -ef | grep 'soffice.*Passwords\.odt'))
if [[ "${arr[1]}" != "" ]] ; then
    kill ${arr[1]}
fi

# Disable mouse wakeup
# first check if mouse wakeup enabled
# XHC	  S3	*enabled   pci:0000:00:14.0
# XHC on laptop, XHCI on office desktop
if cat /proc/acpi/wakeup|grep "^XHC"$'\t'".*enabled" ; then
    echo XHC | tee /proc/acpi/wakeup
elif cat /proc/acpi/wakeup|grep "^XHCI"$'\t'".*enabled" ; then
    echo XHCI | tee /proc/acpi/wakeup
fi

# Uncomment to force lock
#chassis=`dmidecode --string chassis-type`
#if [[ "$chassis" == "Notebook" ]] ; then
#    env -i XDG_SEAT_PATH=/org/freedesktop/DisplayManager/Seat0 dm-tool switch-to-greeter
#fi

# systemctl stop mysql.service

# unmount NFS file systems
timeout 5s umount -a -l -f -t nfs,nfs4

# unmount encrypted file systems
#~ set -- `findmnt -n -t fuse.encfs -o TARGET`
#~ if [[ "$1" != "" ]] ; then
    #~ umount -l -f "$@"
#~ fi
# systemctl stop transmission-daemon.service

exit 0
