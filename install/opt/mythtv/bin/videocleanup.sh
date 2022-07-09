#!/bin/bash
# videodeletes.sh - delete watched videos

. /etc/opt/mythtv/mythtv.conf
. /etc/opt/mythtv/private.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
date

# Get a date/time stamp to add to log output
DATE=`date +%F\ %T\.%N`
DATE=${DATE:0:23}
today=`date "+%a %Y/%m/%d"`
numdate=`date "+%Y%m%d"`

BACKEND=backend
# Number of days before lists are deleted
STALEDAYS=27
# Number of days after watched to delete files
WAITDAYS=13

# To only select watched could use this
# jq -r '.VideoMetadataInfoList.VideoMetadataInfos[] | select(.Watched == true) | .FileName'

# List of video Filenames and watched indicators
curl -H "Accept: application/json" "http://$BACKEND:6744/Video/GetVideoList" \
| jq -r '.VideoMetadataInfoList.VideoMetadataInfos[] | {FileName,Watched} | join("/")' \
> $DATADIR/videos.txt
sort < $DATADIR/videos.txt > $DATADIR/${numdate}_videos.srt

# Remove video lists 28 or more days old
staledate=$(date "+%Y%m%d" -d "$STALEDAYS days ago")
for file in $(cd $DATADIR; ls -1 *_videos.srt) ; do
    if [[ "$file" < "${staledate}_videos.srt" ]] ; then
        rm -vf $DATADIR/$file
    fi
done

# Find latest video lists 14 or more days old
procdate=$(date "+%Y%m%d" -d "$WAITDAYS days ago")
for file in $(cd $DATADIR; ls -1 *_videos.srt) ; do
    if [[ "$file" < "${procdate}_videos.srt" ]] ; then
        selectedfile=$DATADIR/$file
    fi
done

# Clear out prior video deleted
true > $DATADIR/video_deletes.sh

if [[ "$selectedfile" == "" ]] ; then
    echo "No file selected, terminating."
    exit
fi

echo selected file $selectedfile

awk -v "outfile=$DATADIR/video_deletes.sh" -v "videodir=$LOCALVIDEODIR" -v numdate=$numdate '

function deletefile(filename, direct) {
    if (direct != priordeldir) {
        print "mkdir -p \"" junkdir direct "\""> outfile
        priordeldir = direct
    }
    print "mv -bv \"" videodir "/" filename "\" " junkdir direct > outfile
}

BEGIN {
    FS = "/"
    currdir = ""
    dirwatched = 0
    dirunwatched = 0
    priorwatchedfn = ""
    priordir = ""
    junkdir = videodir "/../videojunk/" numdate "/"
    priordeldir=""
}

{
#    print $0
    dir = ""
    levels=0
    for (i = 1 ; i < NF-1 ; i++) {
        dir = dir $(i) "/"
        levels++
    }
    if (levels < 1 || levels > 2 || $1 == "Music") {
        print "Skipping " $0 " levels " levels
        next
    }
    fn = dir $(i)
    watched = $(i+1)
#    print "dir:" dir " fn:" fn " watched:" watched
#    print "watched:" dirwatched " unwatched:" dirunwatched
    if (dir != currdir) {
        if (dirunwatched == 0) {
            if (priorwatchedfn != "")
                deletefile(priorwatchedfn, priordir)
        }
        currdir = dir
        dirwatched = 0
        dirunwatched = 0
        priorwatchedfn = ""
        priordir = ""
    }
    if (watched == "true")
        dirwatched++
    else
        dirunwatched++
    if (watched == "true") {
        if (priorwatchedfn != "")
            deletefile(priorwatchedfn, priordir)
        priorwatchedfn = fn
        priordir = dir
    }
}

END {
    if (dirunwatched == 0) {
        if (priorwatchedfn != "") {
            deletefile(priorwatchedfn, priordir)
        }
    }
}
' $DATADIR/videos.srt

chmod +x $DATADIR/video_deletes.sh

