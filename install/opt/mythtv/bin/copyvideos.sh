#!/bin/bash
# Copy video files from main computer

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
# exec 1>>$LOGDIR/${scriptname}.log
# exec 2>&1
date

mounted=N

# This will return server name for an NFS mount, 
# the string "UUID" for a local mount, empty for a mismatch
vidserver=`grep " $REMOTEVIDEOMNT" /etc/fstab|sed 's/:.*//;s/=.*//'`

if [[ "$vidserver" == "" ]] ; then
    echo "ERROR, no match found for mount directory $REMOTEVIDEOMNT , aborting"
    exit 2
fi

# wakeup_server

if [[ "$vidserver" == UUID ]] ; then
    mounted=Y
elif [[ "$mounted" == N ]] ; then
    "$scriptpath/wakeup.sh" $vidserver
    for try in 1 2 3 4 5 6 7 8 9 ; do
        mount "$REMOTEVIDEOMNT" || true
        if [[ `echo "$REMOTEVIDEOMNT"/*` != "$REMOTEVIDEOMNT/*" ]] ; then
            break;
        fi
        sleep 10
    done
    mounted=Y
fi

if [[ "$mounted" == N ]] ; then
    echo "ERROR Unable to mount $REMOTEVIDEOMNT"
    exit 2
fi

ionice -c3 -p$$

for file in $REMOTEVIDEODIR/*/*.@(mkv|mpg|mp4|avi|srt) \
  $REMOTEVIDEODIR/*/*/*.@(mkv|mpg|mp4|avi|srt) ; do
    if [[ ! -f "$file" ]] ; then
        continue
    fi
    shortfn=${file#$REMOTEVIDEODIR/}
    dirname=$(dirname "$shortfn")
    episode="$(basename "$file")"
    mkdir -p "$LOCALVIDEODIR/$dirname"
    cp -Lvp "$file" "$LOCALVIDEODIR/$dirname/$episode"
    mv -f "$file" "${file}_copied"
done
mythutil --scanvideos
umount -l "$REMOTEVIDEOMNT"
echo Copy Videos complete.
