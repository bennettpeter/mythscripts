#!/bin/bash
#systemd
#This is run after sleep, hibernate, etc.

#if systemctl is-enabled mysql.service ; then
#    systemctl start mysql.service
#fi
if systemctl is-enabled mythtv-backend.service ; then
    systemctl start mythtv-backend.service
fi

if systemctl is-enabled nfs-client.target ; then
    systemctl restart nfs-client.target
fi

exit 0
