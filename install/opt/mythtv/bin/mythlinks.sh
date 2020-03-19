#!/bin/bash
# Create links for recordings by name and by date
# Useful if you want to copy recordings or share them.

# parameter 
# 1. blank means By orig date, 'airdate' meanse by air date

param="$1"

set -e

if [[ "$MYTHTVDIR" == "" ]] ; then
    MYTHTVDIR=/usr
fi

# This needed because mythlink.pl fails if you are 
# logged into the LINKSDIR tree
cd /tmp

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
if [[ ! -d "$LINKSDIR" ]] ; then
    mkdir -p "$LINKSDIR"
    chgrp mythtv "$LINKSDIR"
    chmod g+ws "$LINKSDIR"
fi

if [[ "$param" == airdate ]] ; then
    # By Air Date
    rm -rf "$LINKSDIR"/airdate
    $MYTHTVDIR/share/doc/mythtv-backend/contrib/user_jobs/mythlink.pl \
      --dest "$LINKSDIR/airdate" --format "%U/%T/%y%m%d-%H%i %oy%om%od S%ssE%ep %S"
else
    # By Title with orig date
    rm -rf "$LINKSDIR"/origdate
    $MYTHTVDIR/share/doc/mythtv-backend/contrib/user_jobs/mythlink.pl \
      --link "$LINKSDIR/origdate" --format "%U/%T/%oy%om%od S%ssE%ep %S"
fi

