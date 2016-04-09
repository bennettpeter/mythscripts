#!/bin/bash
#systemd
#This is run before sleep, hibernate, etc.


pkill mythfrontend
if systemctl is-active mythtv-backend.service ; then
    systemctl stop mythtv-backend.service
    systemctl stop mysql.service
fi

#if [[ -f /etc/init/mythtv-monitor.conf ]] ; then
#    stop mythtv-monitor
#fi

# unmount NFS file systems
timeout 5s umount -a -l -f -t nfs,nfs4

#for mountpoint in `mount  -t nfs | cut -d' ' -f3` `mount  -t nfs4 | cut -d' ' -f3` ; do
#    timeout 5s umount -l $mountpoint
#done

exit 0
