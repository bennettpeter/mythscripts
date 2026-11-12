#!/bin/bash
# Remove recording from recorded table if file not found

set -e
. /etc/opt/mythtv/mythtv.conf
. /etc/opt/mythtv/private.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
# exec 1>>$LOGDIR/${scriptname}.log
# exec 2>&1
# date

if [[ "$MYTHTVDIR" == "" ]]   ; then
  MYTHTVDIR=/usr
fi

if [[ "$MYTHCONFDIR" == "" ]] ; then
    export MYTHCONFDIR=$HOME/.mythtv
fi

. $scriptpath/getconfig.sh
mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName -ss $DBName"

echo "
SELECT basename from recorded;
" | \
$mysqlcmd > /tmp/roamfn.txt

true > /tmp/roamdel.sql
true > /tmp/roamdel2.sh

(
	while true ; do
		read filename || echo $?
		if [[ $filename == "" ]] ; then break ; fi
		if ! test -f /srv/mythtv/video*/recordings/$filename ; then
			echo "DELETE FROM recorded WHERE basename = '$filename';" >> /tmp/roamdel.sql
		fi
	done
) < /tmp/roamfn.txt

if [[ -s /tmp/roamdel.sql ]] ; then
	less /tmp/roamdel.sql
	echo "Run DB deletes (Y|N)?"
	read -e ans
	if [[ "$ans" == Y ]] ; then
		$mysqlcmd < /tmp/roamdel.sql
	fi
else
	echo "No DB deletes needed"
fi

ls -1 /srv/mythtv/video*/recordings/*.ts \
	/srv/mythtv/video*/recordings/*.tsx \
	/srv/mythtv/video*/recordings/*.mkv \
	> /tmp/roamfn2.txt 2>/dev/null || rc=$?
(
	while true ; do
		read fullfilename || echo $?
		if [[ $fullfilename == "" ]] ; then break ; fi
		filename=$(basename $fullfilename)
		dbfilename=$(echo "SELECT basename from recorded where basename='$filename';" \
		| $mysqlcmd)
		if [[ $dbfilename != $filename ]] ; then
			echo "rm -f /srv/mythtv/video*/recordings/$filename" >> /tmp/roamdel2.sh
		fi
	done
) < /tmp/roamfn2.txt

if [[ -s /tmp/roamdel2.sql ]] ; then
	less /tmp/roamdel2.sql
	echo "Run file deletes (Y|N)?"
	read -e ans
	if [[ "$ans" == Y ]] ; then
		. /tmp/roamdel2.sql
	fi
else
	echo "No file deletes needed"
fi
