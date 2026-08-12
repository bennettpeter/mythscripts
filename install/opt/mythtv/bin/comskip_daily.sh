#!/bin/bash
# Daily Commercial skip run
# Make sure the oldest unwatched episodes of certain shows have been run
# Set up /etc/opt/mythtv/comskip_shows.txt as follows, one line per title
# r = recording, v = video
# T = tubi recording in video directory
# R = Roku, P = Peacock, D = disney
# comskip_shows.txt must have double apostrophe is there are showa with
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
# v Video Title
# r Recording title
while read -r type stitle ; do
    if [[ "$type" == r  && "$stitle" != "" ]] ; then
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
    if [[ "$type" != r  && "$stitle" != "" ]] ; then
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
                if [[ "$type" == T ]] ; then
                    $scriptpath/comskip_tubi.sh "$filename" tubi
                elif [[ "$type" == R ]] ; then
                    $scriptpath/comskip_tubi.sh "$filename" roku
                elif [[ "$type" == P ]] ; then
                    $scriptpath/comskip_tubi.sh "$filename" peacock
                elif [[ "$type" == D ]] ; then
                    $scriptpath/comskip_tubi.sh "$filename" disney
                elif [[ "$type" == v ]] ; then
                    echo $scriptpath/comskip.sh "$filename"
                    $scriptpath/comskip.sh "$filename"
                fi
            fi
        done < /tmp/comskip$$.csv
    fi
done < /etc/opt/mythtv/comskip_shows.txt

date
echo "------END------"
