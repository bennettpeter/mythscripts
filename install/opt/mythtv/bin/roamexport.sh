#!/bin/bash
# Export files for roaming MythTV
# run with nohup - output goes to scripts directory

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

if [[ `id -nu` != mythtv ]] ; then
    echo "ERROR This must run under mythtv user"
    exit 2
fi

# ROAMDIR example - /srv/mythroam
mount -v $ROAMDIR || true
sleep 1
if ! mountpoint $ROAMDIR ; then
    echo "ERROR Unable to mount $ROAMDIR"
    exit 2
fi

if [[ ! -d "$LINKSDIR" ]] ; then
    mkdir -p "$LINKSDIR"
    chgrp mythtv "$LINKSDIR"
    chmod g+ws "$LINKSDIR"
fi

rm -rf "$LINKSDIR"/roam
mkdir -p "$LINKSDIR"/roam

. $scriptpath/getconfig.sh
mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

# ROAM_GROUPS - example "'Peter','Default','Chicago'"
echo "SELECT basename FROM recorded
        inner join recgroups 
        on recorded.recgroupid = recgroups.recgroupid
        where recgroups.recgroup in ($ROAM_GROUPS);" | \
        $mysqlcmd > /tmp/files$$.txt

# NOTE THIS ONLY WORKS IF RECORDING DIRECTORIES AND FILES HAVE NO SPACES IN THE NAMES
while read -r filename ; do
    # fullfilename=`find "$VIDEODIR" -name "$filename" -o -name "$filename.*" 2>/dev/null` || true
    fullfilename=`ls "$VIDEODIR"/video*/recordings/"$filename" \
        "$VIDEODIR"/video*/recordings/"$filename".* 2>/dev/null` || true
    if [[ "$fullfilename" != "" ]] ; then
        ln -s $fullfilename "$LINKSDIR"/roam/
    fi
done < /tmp/files$$.txt

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

# Remove any files on output not owned by mythtv
find $ROAMDIR -not -path "$ROAMDIR/.*" -not -user mythtv -type f -print0 | xargs -0 rm -fv

mkdir -p $ROAMDIR/recordings
rsync -vLdpt --size-only --chmod=g+w --delete-before "$LINKSDIR"/roam/ $ROAMDIR/recordings/

mkdir -p $ROAMDIR/channels
# CHANNEL_ICON_DIR example /home/mythtv/.mythtv/channels
rsync -vdpt --size-only --chmod=g+w --delete-before "$CHANNEL_ICON_DIR"/ $ROAMDIR/channels/

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
            rsync -vrpt --size-only --chmod=g+w --delete-before "$dirname"/ $ROAMDIR/$subdir/
            found=Y
        fi
    done
done

# Copy comskip parameters
mkdir -p $ROAMDIR/etc
cp -fv /etc/opt/mythtv/comskip_shows.txt $ROAMDIR/etc/

umount -v $ROAMDIR || true
