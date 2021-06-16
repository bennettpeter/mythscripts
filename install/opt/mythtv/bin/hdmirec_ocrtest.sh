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
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

if [[ "$recname" == "" ]] ; then
    recname=hdmirec1
fi

source $scriptpath/hdmifuncs.sh

ADB_ENDKEY=
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
        #~ if [[ "${channels[@]}" == *_* ]] ; then
            #~ gocr -C 0-9 -l $GRAYLEVEL2 $DATADIR/${recname}_channels.$IMAGES > $DATADIR/${recname}_channels.txt 2>/dev/null
            #~ onscreen=$(cat $DATADIR/${recname}_channels.txt)
            #~ channels2=($onscreen)
            #~ echo "channels2: ${channels2[@]}"
            #~ channels3=()
            #~ if [[ "${channels2[@]}" == *_* ]] ; then
                #~ gocr -C 0-9 -l $GRAYLEVEL3 $DATADIR/${recname}_channels.$IMAGES > $DATADIR/${recname}_channels.txt 2>/dev/null
                #~ onscreen=$(cat $DATADIR/${recname}_channels.txt)
                #~ channels3=($onscreen)
                #~ echo "channels3: ${channels3[@]}"
                #~ if [[ "${channels3[@]}" != *_* ]] ; then
                    #~ channels=(${channels3[@]})
                #~ fi
            #~ else
                #~ channels=(${channels2[@]})
            #~ fi
            #~ if [[ "${channels[@]}" == *_* ]] ; then
                #~ for (( ix=0; ix<arrsize; ix++ )) ; do
                    #~ if [[ "${channels[ix]}" == *_* ]] ; then
                        #~ if [[ "${channels2[ix]}" == *_* ]] ; then
                            #~ channels[ix]="${channels2[ix]}"
                        #~ else
                            #~ channels[ix]="${channels3[ix]}"
                        #~ fi
                    #~ fi
                #~ done
            #~ fi
            #~ echo "corrected channels: ${channels[@]}"
        #~ fi
        #~ arrsize=${#channels[@]}
        echo "Channels on page: $arrsize"
        #~ if [[ "${channels[@]}" == *_* ]] ; then
            #~ echo ERROR in channels.
            #~ error=1
        #~ elif (( arrsize != 5 )) ; then
            #~ echo ERROR incorrect number of entries $arrsize, should be 5
            #~ error=1
        #~ else
            # Get each channel on a new line in a file
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
        #~ if [[ "$last" == *_* ]] ; then
            #~ last=0
        #~ fi
        if (( last < MAX_CHANNUM )) ; then
            $scriptpath/adb-sendkey.sh DOWN
        fi
    done
    adb disconnect $ANDROID_DEVICE
fi
#~ pagename=
#~ getpagename "240x64+62+10"
capturepage
echo "Menu Name: \"$pagename\""
if [[ "$pagename" == Search ]] ; then
    echo "Menu name matches Search"
fi

# xdg-open $DATADIR/${recname}_capture.$IMAGES
