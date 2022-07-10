#!/bin/bash
# videodeletes.sh - delete watched videos

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
date

# Get a date/time stamp to add to log output
DATE=`date +%F\ %T\.%N`
DATE=${DATE:0:23}
today=`date "+%a %Y/%m/%d"`
numdate=`date "+%Y%m%d"`

BACKEND=localhost
# You can run this script on a different host by setting BACKEND
# to a different value, but then you must set DELETE_VIDEOS=N since
# the videos will be on a different system and delete will fail.
#~ BACKEND=backend
#~ DELETE_VIDEOS=N

set -e
# To only select watched could use this
# jq -r '.VideoMetadataInfoList.VideoMetadataInfos[] | select(.Watched == true) | .FileName'

# List of video Filenames and watched indicators
curl -H "Accept: application/json" "http://$BACKEND:6744/Video/GetVideoList" \
| jq -r '.VideoMetadataInfoList.VideoMetadataInfos[] | {FileName,Watched} | join("\t")' \
> $DATADIR/videos.txt
rc=${PIPESTATUS[0]}

if (( rc != 0 )) ; then
    echo ERROR: curl failed
    exit $rc
fi

LC_COLLATE=C sort < $DATADIR/videos.txt > $DATADIR/${numdate}_videos.srt

staledate=$(date "+%Y%m%d" -d "$VIDEO_STALEDAYS days ago")
procdate=$(date "+%Y%m%d" -d "$VIDEO_WAITDAYS days ago")
selectedfile=
latestfile=
for file in $(cd $DATADIR; ls -1 *_videos.srt) ; do
    # Remove video lists 28 or more days old
    if [[ ! "$file" > "${staledate}_videos.srt" ]] ; then
        rm -vf $DATADIR/$file
    fi
    # Find video list 14 or more days old
    if [[ ! "$file" > "${procdate}_videos.srt" ]] ; then
        selectedfile=$DATADIR/$file
    fi
    # Find latest video list
    latestfile=$DATADIR/$file
done

# Clear out prior video deleted
true > $DATADIR/video_deletes.sh

echo selected file: $selectedfile, latest file: $latestfile.

if [[ "$selectedfile" == "" || "$latestfile" == "" ]] ; then
    echo "No file selected, terminating."
    exit
fi

awk -v outfile=$DATADIR/video_deletes.sh \
  -v numdate=$numdate -v latestfile=$latestfile \
  -v videodir="$LOCALVIDEODIR" '

function deletefile(filename) {
    print "rm -fv \"" videodir "/" filename "\" " > outfile
}

function matchup() {
    while (fn2 < fn && !eof2) {
        eof2 = ! getline < latestfile
        fn2=$1
        watched2=$2
    }
    x = fn2<fn 
}

BEGIN {
    FS = "\t"
    fn=""
    fn2=""
    eof2=0
    delcount=0
    videocount=0
    keepcount=0
}

{
    fn = $1
    watched = $2
    videocount++
    if (match(fn,'"$VIDEO_PRESERVE"')) {
        keepcount++
        next
    }
    if (watched == "true") {
        matchup()
        if (fn == fn2) {
            if (watched2 == "true") {
                deletefile(fn)
                delcount++
            }
        }
        else
            print "WARNING: File:" fn " has already been deleted."
    }
}

END {
    print "Total number of videos: " videocount
    print "Number of videos deleted: " delcount
    print "Number of videos in preserved directories: " keepcount
}

' $selectedfile

chmod +x $DATADIR/video_deletes.sh

if [[ "$DELETE_VIDEOS" == Y ]] ; then
    echo "Deleting videos"
    $DATADIR/video_deletes.sh
    echo "Deleting empty directories"
    find $LOCALVIDEODIR -type d -empty -delete -print
    mythutil --scanvideos
fi

exit













