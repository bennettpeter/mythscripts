#!/bin/bash

# Parameter 1 - recorder name e.g. hdmirec1

# Test of OCR. To use this first run vlc and select a page that is used.
# For You page
# Menu
# Favorite Channels page
# For each page run this and ensure the text is recognized.
# Note you must exit vlc while running this.
# it will display the OCR content of the heading and Channel list.

recname=$1

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

if [[ "$recname" == "" ]] ; then
    recname=hdmirec1
fi

source $scriptpath/hdmifuncs.sh

initialize

getparms

# Close vlc
wmctrl -c vlc
wmctrl -c obs

capturepage
capturepage
echo "Page Name for main pages: \"$pagename\""
if [[ "$pagename" == "For You" ]] ; then
    echo "Page name matches ForYou"
fi
if [[ "$pagename" == "Favorite Channels" ]] ; then
    echo "Page name matches Favorite Channels"
fi

if (( MAX_CHANNUM == 0 )) ; then
    MAX_CHANNUM=99999
fi

if [[ "$pagename" == "Favorite Channels" || "$pagename" == A??*Channels ]] ; then
    adb connect $ANDROID_DEVICE
    while (( last < MAX_CHANNUM )) ; do
        CROP="-crop 86x600+208+120"
        TESSPARM="-c tessedit_char_whitelist=0123456789"
        capturepage
        onscreen=$(cat $DATADIR/${recname}_capture_crop.txt)
        #~ onscreen=$(grep -o '[0-9] ' $DATADIR/${recname}_capture_crop.txt)
        channels=($onscreen)
        arrsize=${#channels[@]}
        if (( arrsize != 5 )) ; then
            channels=($(gocr -C 0-9 -l 200 $DATADIR/${recname}_capture_crop.png))
            arrsize=${#channels[@]}
            if [[ "${channels[@]}" == *_* ]] ; then
                echo ERROR in channel OCR
            fi
        fi
        echo "channels: ${channels[@]}"
        echo "Channels on page: $arrsize"
        echo "${channels[@]}" | sed 's/ /\n/g' > $DATADIR/${recname}_channels.txt
        if ! sort -nc $DATADIR/${recname}_channels.txt ; then
            echo ERROR channels out of sequence
        fi
        #~ fi
        if (( arrsize > 0 )) ; then
            last=${channels[arrsize-1]}
        else
            break
        fi
        if (( last < MAX_CHANNUM )) ; then
            $scriptpath/adb-sendkey.sh DOWN
        fi
    done
    adb disconnect $ANDROID_DEVICE
fi
capturepage
echo "Menu Name: \"$pagename\""
if [[ "$pagename" == Search ]] ; then
    echo "Menu name matches Search"
fi

