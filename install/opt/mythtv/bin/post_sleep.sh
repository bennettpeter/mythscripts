#!/bin/bash
#systemd
#This is run after sleep, hibernate, etc.

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

# restart bluetooth when needed
if [[ "$RESTART_BLUETOOTH" == Y ]] ; then
    if systemctl is-enabled bluetooth.service ; then
        systemctl restart bluetooth.service
    fi
fi

exit 0
