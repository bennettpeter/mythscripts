#!/bin/bash

if ! mountpoint /srv/mythroam ; then
    if ! mount /srv/mythroam ; then
        echo Press enter to exit
        read -e junk
        exit 2
    fi
fi

/opt/mythtv/bin/run_opt.sh mythtv/prd mythbackend --logpath /tmp
umount /srv/mythroam
echo Press enter to exit
read -e junk
