#!/bin/bash
# Daily Commercial skip run
# Make sure the oldest unwatched episodes of certain shows have been run
# Set up /etc/opt/mythtv/comskip_shows.txt as follows, one line per title
# r = recording, other = video with service name used by comskip_stream
#     recording = recording in video directory
# comskip_shows.txt must have double apostrophe if there are shows with
# apostrophe in the title

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
echo "------START------"
date

# Get DB password
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName --batch --column-names=FALSE $DBName"

# Format of comskip_shows.txt
# r Recording title
# xxx Video Title
#  where xxx is the service:  "peacock", "tubi", "roku", "disney", "paramount"
#  xxx is "recording" for default Mythtv comskip
while read -r type stitle ; do
    if [[ "$type" == "#" || "$type" == "" ]] ; then continue ; fi
    if [[ "$type" == r ]] ; then
        if [[ "$stitle" == "" ]] ; then echo Missing Title ; continue ; fi
        echo "Checking for recordings of $stitle"
        $mysqlcmd << EOF > /tmp/comskip$$.csv
SELECT basename, recorded.chanid, recorded.starttime, recgroup, title, MAX(type=4), originalairdate, subtitle
FROM recordedmarkup right outer join recorded using (chanid, starttime)
where recgroup not in ('Deleted','Shorts') and watched = 0 and title = '$stitle'
group by basename, recorded.chanid, recorded.starttime, recgroup, title, subtitle, originalairdate
order by if (originalairdate < "1920-01-01", recorded.starttime, originalairdate), season, episode
limit 3;
EOF
        while IFS=$'\t' read -r basename chanid starttime recgroup title done originalairdate subtitle extra ; do
            echo "Found $title - $subtitle, skip done = $done"
            if [[ "$done" != 1 ]] ; then
                echo $scriptpath/comskip.sh "$basename" "$chanid" "$starttime" "$recgroup" "$title" "$subtitle"
                $scriptpath/comskip.sh "$basename" "$chanid" "$starttime" "$recgroup" "$title" "$subtitle"
            fi
        done < /tmp/comskip$$.csv
    fi
    if [[ "$type" != r ]] ; then
        if [[ "$stitle" == "" ]] ; then  echo Missing Title ; continue ; fi
        echo "Checking for videos of $stitle type $type"
        $mysqlcmd << EOF > /tmp/comskip$$.csv
SELECT filename, title, MAX(type=4), subtitle
FROM filemarkup right outer join videometadata using (filename)
WHERE watched = 0 AND title = '$stitle'
group by filename, title, subtitle
order by filename
limit 3;
EOF
        while IFS=$'\t' read -r filename title done subtitle extra ; do
            echo "Found $title - $subtitle, skip done = $done"
            if [[ "$done" != 1 ]] ; then
                if [[ "$type" == recording ]] ; then
                    $scriptpath/comskip.sh "$filename"
                else
                    $scriptpath/comskip_stream.sh "$filename" "$type"
                fi
            fi
        done < /tmp/comskip$$.csv
    fi
done < /etc/opt/mythtv/comskip_shows.txt

date
echo "------END------"
