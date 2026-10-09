#!/bin/bash
# Commercial skip for streamed recordings
# command line - 
# for a video:
# /opt/mythtv/bin/comskip_stream.sh "filename" "service" option 
# the filename must be a full file name relative to the videos directory
# service: "peacock", "tubi", "roku", "disney", "paramount"
# optional: keep

. /etc/opt/mythtv/mythtv.conf

# These overrides enable running this for mythroam
shortname=$(echo "$MYTHCONFDIR" | grep -o "[a-z]*$")
if [[ -f /etc/opt/mythtv/mythtv-$shortname.conf ]] ; then
    . /etc/opt/mythtv/mythtv-$shortname.conf
fi

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
echo "------START------"
date

echo $0 $1 $2 $3 $4 $5 $6 $7

filename="$1"
# Video File
fullfilename=`ls "$VIDEODIR"/video*/videos/"$filename"`

service="$2"
option="$3"

# Get DB password
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName --batch --column-names=FALSE $DBName"

function errfunc {
    if [[ "$title" == "" ]] ; then
        title="$filename"
    fi
    "$scriptpath/notify.py" "commskip_stream failed" "$title" "$subtitle"
    exit 2
}
trap errfunc ERR

echo Set IO priority to -c3 idle
ionice -c3 -p$$
error=0
exten=jpg
tempdir=${fullfilename%.*}_tmp
NEGATE='-channel RGB -negate +channel'
MAX_AD_LEN=240
MIN_AD_LEN=10
EXTRA_SECS=1
samplerate=1
# Number of blank snapshots to mark end of an ad
# Also this number of blanks will negate a false detection
ENDBLANKS=10

vidwidth=$(mediainfo "--Inform=Video;%Width%" "$fullfilename")
vidheight=$(mediainfo "--Inform=Video;%Height%" "$fullfilename")
framerate=$(mediainfo "--Inform=Video;%FrameRate%" "$fullfilename")
frameratex1000=$(echo "$framerate * 1000 / 1" | bc)

# parameters width, height, xoffset, yoffset in a 1280x720 picture
function setcrop {
    let cwidth=${1}*vidwidth/1280
    let cheight=${2}*vidheight/720
    let xoff=${3}*vidwidth/1280
    let yoff=${4}*vidheight/720
    CROP="-crop ${cwidth}x${cheight}+${xoff}+${yoff}"
}

function TESSERACT {
    tesseract -c page_separator= "$tempdir/temp.$exten" -
}

function GOCR {
    gocr -C 0-9: "$tempdir/temp.$exten"
}

case $service in
    peacock)
        # Example: Columbo: S1968E01 Prescription Murder
        # Number of seconds in a black circle bottom left of picture
        # Check on number of seconds 0-999
        setcrop 40 20 65 646
        CONTRAST="-brightness-contrast 0x40"
        OCR=GOCR
        TEST='^[0-9].*$'
        ;;
    tubi)
        # Example: Columbo: S1977E01 The Bye-bye Sky High I.Q. Murder Case
        # Top Left: Ad 1 of 2. This ad will end in 0:23
        # the number of seconds has a black background

        # Check on text unreliable as it has picture background
        #~ setcrop 260 36 54 54
        #~ CONTRAST="-brightness-contrast 0x90"
        #~ OCR=TESSERACT
        #~ TEST='Ad *[1-9it]'

        # Check on time e.g. 0:23
        setcrop 54 30 316 56
        CONTRAST="-brightness-contrast 0x90"
        OCR=GOCR
        TEST='[0-5]:[0-5][0-9]'
        ;;
    roku)
        # Example: Benson
        # top Left: Ad 1 of 3 on picture background
        # Unreliable due to background
        setcrop 120 26 54 54
        CONTRAST="-brightness-contrast 0x90"
        OCR=TESSERACT
        TEST='Ad *[1-9it] *of *[1-9it]'
        ;;
    disney)
        # Example: Deadpool & Wolverine
        # top right: Ad 0:30
        #~ setcrop 36 34 1176 40
        # This OCRs as "Ad\n\n0:30"
        setcrop 76 34 1136 46
        CONTRAST="-brightness-contrast 0x40"
        OCR=TESSERACT
        #~ TEST='^[0-9]+:[0-9][0-9]$'
        TEST='^Ad$'
        ;;
    paramount)
        # Example: Star Trek Deep Space Nine: S01E01
        # top left: Number in a circle followed by "Advertisement"
        # Picture background
        setcrop 200 26 70 87
        CONTRAST="-brightness-contrast 0x40"
        OCR=TESSERACT
        TEST='^[0-9]|Advertisement'
        ;;
    amazon)
        # Example: Hyperdrive: S01E01
        # top right: Ad 0:42 on black background
        setcrop 80 26 1126 54
        CONTRAST="-brightness-contrast 0x40"
        OCR=TESSERACT
        TEST='^Ad *[0-9]'
        ;;
    *)
        echo Unknown service: $service
        # to cause error and invoke errfunc
        false
        ;;
esac


function adstring {
    if (( adend - adstart > MAX_AD_LEN )) ; then
        echo "ERROR: Max ad length $MAX_AD_LENGTH exceeded: $adstart - $adend. Ad ignored" 
    elif (( adend - adstart > MIN_AD_LEN )) ; then
        let fseq1=adstart*60-EXTRA_SECS*60
        if (( fseq1 < 60 )) ; then
            let fseq1=60
        fi
        let fseq2=adend*60+EXTRA_SECS*60
        if [[ "$skip" != "" ]] ; then
            skip="$skip,"
        fi
        skip="$skip$fseq1-$fseq2"
    fi
    adstart=
    adend=
}

rm -rf "$tempdir"
mkdir -p "$tempdir"

# for testing to limit to 5 minutes : -t 00:05:00
nice ffmpeg -hide_banner -loglevel fatal -y -i "$fullfilename" \
    -vf "fps=1/$samplerate" "$tempdir"/frame_%05d.$exten < /dev/null

skip=
adstart=
adend=
blanks=

for file in "$tempdir"/frame_*.$exten ; do
    seq=${file: -9}
    seq=${seq:0:5}
    seq=${seq##+(0)}
    let seq=seq*$samplerate
    convert "$file" $CROP $NEGATE $CONTRAST "$tempdir"/temp.$exten
    if $OCR 2>/dev/null | egrep "$TEST" >/dev/null 2>&1; then
        blanks=
        if [[ $adstart == "" ]] ; then
            adstart=$seq
        else
            adend=$seq
        fi
    else
        let blanks++
        if (( adstart > 0 && blanks > ENDBLANKS )) ; then
            adstring
        fi
    fi
done
adstring

if [[ "$option" != keep ]] ; then
    rm -rf "$tempdir"
fi

echo "Skiplist $skip"
if [[ "$skip" == "" ]] ; then
    echo "Error - empty skip list"
    skip="1-2"
    error=1
fi
echo "Running mythutil"
set -x
mythutil --video "$filename" --setskiplist "$skip" -q
set +x

sqlfn=$(sed "s/'/''/g"<<<$filename)
$mysqlcmd << EOF
    delete from filemarkup
        where filename = '$sqlfn' and type=32;
    insert into filemarkup (filename,mark,type,offset)
        values ('$sqlfn',1,32,$frameratex1000);
EOF

if (( error )) ; then
    # to cause error and invoke errfunc
    false
fi

date
echo "------END------"
