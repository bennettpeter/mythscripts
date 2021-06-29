#!/bin/bash

# Check favorite channels against upcoming

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`


$scriptpath/myth_upcoming_recordings.pl --plain_text --recordings -1 --hours 336 \
  --text_format "%cn\n" | sort -un | tail -n +2 > $DATADIR/recording_channels.txt

# In the diff results-
# Extra channels in favorites will have >, that is OK
# Missing channels in favorites will have < or | , that is not ok
# in both cases the first number on the line is the one wanted
# to be added to favorites

diff -yN $DATADIR/recording_channels.txt /etc/opt/mythtv/hdmichans.txt > $DATADIR/channel_diff.txt
missing_chans=$(grep "[<|]" $DATADIR/channel_diff.txt | sed "s/ .*//g")
missing_chans=$(echo $missing_chans)
if [[ "$missing_chans" != "" ]] ; then
    $scriptpath/notify.py "Missing Channels" \
      "Channels missing from xfinity favorites: $missing_chans" &
fi
