#!/bin/bash
#systemd
#This is run before sleep, hibernate, etc.

killall mythfrontend
systemctl stop mythtv-backend.service
systemctl stop mysql.service

# unmount NFS file systems
timeout 5s umount -a -l -f -t nfs,nfs4

exit 0
