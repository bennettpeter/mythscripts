#!/bin/bash
# Wrapper for mythfilldatabase

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

today=`date "+%a %Y/%m/%d"`

# Options for Mythfilldatabase
# use --only-update-guide to prevent adding new channels
opts="$1"

# Note the --only-update-guide option does not work for SD only for XMLTV
# Note the --remove-new-channels option does not in fact remove new channels, just prevents 
# them being added when using SD
#mythfilldatabase --dd-grab-all --remove-new-channels "$@"

# Get DB password
#. $scriptpath/getconfig.sh
#mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

#if [[ "$OCUR_SOURCEID" != "" && "$OCUR_DELETECHANNELS" != "" ]] ; then
#    echo "delete from channel where channum in ($OCUR_DELETECHANNELS) and sourceid = $OCUR_SOURCEID;" | \
#    $mysqlcmd
#fi

# Reschedule without those channels
#mythutil --resched

# new design using json api

# This command works fine from v 29. However you don't see the logs from the grabber
# This takes the same time as the loop below.
# mythfilldatabase --no-allatonce --refresh all --only-update-guide --max-days 25

# Get DB password from /etc/mythtv/config.xml Also get mysqlcmd
. $scriptpath/getconfig.sh

echo "select sourceid, name from videosource where xmltvgrabber = 'tv_grab_zz_sdjson_sqlite';" \
    | $mysqlcmd > $DATADIR/videosource.txt

# expect names comcast and ota

while read -r sourceid sourcename
do
    echo Processing $sourcename with id $sourceid
    # There are two grabbers that work - tv_grab_zz_sdjson_sqlite and tv_grab_sd_json
    grabber="/usr/local/bin/tv_grab_zz_sdjson_sqlite"
    userid=`id -un`
    rm -f /tmp/${userid}_tv_grab_$sourcename_off*.xml
    "$grabber" --download-only \
        --config-file $HOME/.xmltv/tv_grab_zz_sdjson_sqlite_$sourcename.conf
    set -x
    offset=0
#    for (( offset = 0; offset < 20; offset += 3 )) ; do
#    removed --days 3 --offset $offset
	"$grabber"  --no-download  \
	  --config-file $HOME/.xmltv/tv_grab_zz_sdjson_sqlite_$sourcename.conf \
	  > /tmp/${userid}_tv_grab_$sourcename_off$offset.xml
	mythfilldatabase --file --sourceid $sourceid \
	  --xmlfile /tmp/${userid}_tv_grab_$sourcename_off$offset.xml $opts
#    done
    set -
done < $DATADIR/videosource.txt

# other way
# mythfilldatabase --no-allatonce --refresh all --only-update-guide --max-days 25
# Old datadirect method
# mythfilldatabase --dd-grab-all --remove-new-channels "$@"
