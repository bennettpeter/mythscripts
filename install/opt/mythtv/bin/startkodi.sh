#!/bin/bash
# start kodi

LOG_FILE=$HOME/.kodi/temp/kodi.log
rm -f $LOG_FILE.1
mv -f $LOG_FILE $LOG_FILE.1
rm -f $LOG_FILE 
/usr/lib/kodi/kodi.bin --standalone &
while [[ ! -f $LOG_FILE ]] ; do
sleep 1s
done
while read line ; do
if [[ ${line} =~ "application stopped" ]] ; then
echo "Killing kodi"
break
fi
done < <(tail --pid=$$ -f -n0 $LOG_FILE)
killall kodi.bin
fbset -depth 8 && fbset -depth 16
