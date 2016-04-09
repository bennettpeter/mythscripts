#!/bin/bash
set -e

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1

cd "$TCMOUNTDIR/$TCSUBDIR"

date 

echo Set IO proority to -c3 idle
ionice -c3 -p$$

nice "$scriptpath/multi_encode.sh" -i '*.@(mkv|mpg|mp4|ts)' -l
