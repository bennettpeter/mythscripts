#!/bin/bash

if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
    exit 0
fi

case $1 in
    hibernate|suspend)
        pkill mythfrontend
        if [[ -f /etc/init/mythtv-backend.conf ]] ; then
            stop mythtv-backend
            stop mysql
        fi
        if [[ -f /etc/init/mythtv-monitor.conf ]] ; then
            stop mythtv-monitor
        fi
        # killall /usr/lib/telepathy/telepathy-gabble
        # killall pidgin
        # unmount NFS file systems
        for mountpoint in `mount  -t nfs | cut -d' ' -f1` `mount  -t nfs4 | cut -d' ' -f1` ; do
            umount -l $mountpoint
    done
    ;;
    thaw|resume)
        if [[ -f /etc/init/mythtv-monitor.conf ]] ; then
            start mythtv-monitor
        fi
        if [[ -f /etc/init/mythtv-backend.conf ]] ; then
            if grep "^start on " /etc/init/mysql.conf ; then
                start mysql
            fi
            if grep "^start on " /etc/init/mythtv-backend.conf ; then
                start mythtv-backend
            fi
        fi
        # if [[ -f /etc/init.d/transmission-daemon ]] ; then
        #     /etc/init.d/transmission-daemon restart
        # fi
    ;;
esac
exit 0
