#!/bin/bash

# Parameter 1 - recorder name e.g. hdmirec1

# Test of OCR. To use this first run vlc and select a page that is used.
# For You page
# Menu
# Favorite Channels page
# For each page run this and ensure the text is recognized.
# Note you must exit vlc while running this.
# it will display the OCR content of the heading and Channel list.
# If there are errors try tweaking the IMAGES or GRAYLEVEL settings

recname=$1

. /etc/opt/mythtv/mythtv.conf

# Select the [default] section of conf and put it in a file
# to source it
awk '/^\[default\]$/ { def = 1; next }
/^\[/ { def = 0; next }
def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
> $DATADIR/etc_${recname}.conf
. $DATADIR/etc_${recname}.conf
. $DATADIR/${recname}.conf

# Kill vlc
wmctrl -c vlc

function getpagename {
    if [[ "$1" == "" ]] ; then
        crop="240x64+62+0"
    else
        crop="$1"
    fi
    rm -f $DATADIR/${recname}_capture.$IMAGES $DATADIR/${recname}_heading.txt
    ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s 1280x720 -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.$IMAGES
    convert $DATADIR/${recname}_capture.$IMAGES -crop "$crop" -negate $DATADIR/${recname}_heading.$IMAGES
    gocr -l $GRAYLEVEL $DATADIR/${recname}_heading.$IMAGES > $DATADIR/${recname}_heading.txt 2>/dev/null
    pagename=$(head -1 $DATADIR/${recname}_heading.txt)
}

pagename=
getpagename
echo "Page Name for main pages: \"$pagename\""
if [[ "$pagename" == For*You ]] ; then
    echo "Page name matches For*You"
else
    echo "Page name does not match For*You"
fi
if [[ "$pagename" == Favorite*Channels ]] ; then
    echo "Page name matches Favorite*Channels"
else
    echo "Page name does not match Favorite*Channels"
fi
pagename=
getpagename "240x64+62+10"
echo "Page Name if on Search page: \"$pagename\""
if [[ "$pagename" == Search ]] ; then
    echo "Page name matches Search"
else
    echo "Page name does not match Search"
fi

convert $DATADIR/${recname}_capture.$IMAGES -crop 86x600+208+120 -negate $DATADIR/${recname}_channels.$IMAGES
gocr -C 0-9 -l $GRAYLEVEL $DATADIR/${recname}_channels.$IMAGES > $DATADIR/${recname}_channels.txt 2>/dev/null
onscreen=($(sed s/_//g $DATADIR/${recname}_channels.txt))
echo Channels before cleaning:
cat $DATADIR/${recname}_channels.txt
echo "Channels after Cleaning: ${onscreen[@]}"
xdg-open $DATADIR/${recname}_capture.$IMAGES
