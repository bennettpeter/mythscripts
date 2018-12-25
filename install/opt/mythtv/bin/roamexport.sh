#!/bin/bash
# Export files for roaming MythTV
# TODO - copy channels from .mythtv directory
set -e

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

if [[ ! -d "$LINKSDIR" ]] ; then
    mkdir -p "$LINKSDIR"
    chgrp mythtv "$LINKSDIR"
    chmod g+ws "$LINKSDIR"
fi

rm -rf "$LINKSDIR"/roam
mkdir -p "$LINKSDIR"/roam

. $scriptpath/getconfig.sh
mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

# ROAM_CATEGORIES - example "'Peter','Default','Chicago'"
echo "SELECT basename FROM recorded
        inner join recgroups 
        on recorded.recgroupid = recgroups.recgroupid
        where recgroups.recgroup in ($ROAM_CATEGORIES);" | \
        $mysqlcmd > /tmp/files$$.txt

while read -r filename ; do
    fullfilename=`find "$VIDEODIR" -name $filename 2>/dev/null` || true
    if [[ "$fullfilename" != "" ]] ; then
        ln -s "$fullfilename" "$LINKSDIR"/roam/$filename
    fi
done < /tmp/files$$.txt

# ROAMDIR example - /srv/mythroam
mount -v $ROAMDIR || true

if ! mountpoint $ROAMDIR ; then
    echo ERROR Unable to mount $ROAMDIR
    exit 99
fi

otherdirs="
artwork
banners
coverart
dbbackup
fanart
screenshots
trailers
videos"

ionice -c3 -p$$

mkdir -p $ROAMDIR/recordings
rsync -vLdpt --chmod=g+w --delete-before "$LINKSDIR"/roam/ $ROAMDIR/recordings/

mkdir -p $ROAMDIR/channels
rsync -vdpt  --chmod=g+w --delete-before "$CHANNEL_ICON_DIR"/ $ROAMDIR/channels/

for subdir in $otherdirs ; do
    mkdir -p $ROAMDIR/$subdir
    dirnames=`find "$VIDEODIR" -name $subdir -type d 2>/dev/null` || true
    found=N
    for dirname in $dirnames ; do
        if [[ "$dirname" != ""  && `ls -A "$dirname"` != "" ]] ; then
            if [[ "$found" == Y ]] ; then
                echo ERROR Duplicate directories $subdir
                exit 99
            fi
            rsync -vrpt --chmod=g+w --delete-before "$dirname"/ $ROAMDIR/$subdir/
            found=Y
        fi
    done
done

umount -v $ROAMDIR || true
