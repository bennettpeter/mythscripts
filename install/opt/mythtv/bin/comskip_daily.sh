#!/bin/bash
# Daily Commercial skip run
# Make sure the oldest unwatched episodes of certain shows have been run

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
# v Video Title
# r Recording title
while read -r type stitle ; do
    if [[ "$type" == r  && "$stitle" != "" ]] ; then
        echo "Checking for recordings of $stitle"
        $mysqlcmd << EOF > /tmp/comskip$$.csv
SELECT basename, recorded.chanid, recorded.starttime, recgroup, title, subtitle, originalairdate, MAX(type=4)
FROM recordedmarkup right outer join recorded using (chanid, starttime)
where recgroup != 'Deleted' and watched = 0 and title = '$stitle'
group by basename, recorded.chanid, recorded.starttime, recgroup, title, subtitle, originalairdate
order by originalairdate
limit 3;
EOF
        while IFS=$'\t' read -r basename chanid starttime recgroup title subtitle originalairdate done extra ; do
            echo "Found $title - $subtitle, skip done = $done"
            if [[ "$done" != 1 ]] ; then
                echo /opt/mythtv/bin/comskip.sh "$basename" "$chanid" "$starttime" "$recgroup" "$title" "$subtitle"
                /opt/mythtv/bin/comskip.sh "$basename" "$chanid" "$starttime" "$recgroup" "$title" "$subtitle"
            fi
        done < /tmp/comskip$$.csv
    fi
    if [[ "$type" == v  && "$stitle" != "" ]] ; then
        echo "Checking for videos of $stitle"
        $mysqlcmd << EOF > /tmp/comskip$$.csv
SELECT filename, title, subtitle, MAX(type=4)
FROM filemarkup right outer join videometadata using (filename)
WHERE watched = 0 AND title = '$stitle'
group by filename, title, subtitle
order by filename
limit 3;
EOF
        while IFS=$'\t' read -r filename title subtitle done extra ; do
            echo "Found $title - $subtitle, skip done = $done"
            if [[ "$done" != 1 ]] ; then
                echo /opt/mythtv/bin/comskip.sh "$filename"
                /opt/mythtv/bin/comskip.sh "$filename"
            fi
        done < /tmp/comskip$$.csv
    fi
done < /etc/opt/mythtv/comskip_shows.txt

date
echo "------END------"
