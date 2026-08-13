#!/bin/bash
# Commercial skip for streamed recordings
# command line - 
# for a video:
# /opt/mythtv/bin/comskip_stream.sh "filename" "option"
# the filename must be a full file name relative to the videos directory
# option: "peacock", "tubi", "roku", "disney"

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

option="$2"

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

case $option in
    peacock)
        setcrop 40 20 65 646
        CONTRAST="-brightness-contrast 0x40"
        OCR=GOCR
        TEST='^[0-9].*$'
        ;;
    tubi)
        setcrop 260 36 54 54
        CONTRAST="-brightness-contrast 0x90"
        OCR=TESSERACT
        TEST='Ad *[1-9]'
        ;;
    roku)
        setcrop 120 26 54 54
        CONTRAST="-brightness-contrast 0x90"
        OCR=TESSERACT
        TEST='Ad *[1-9]'
        ;;
    disney)
        # with Ad 74 34 1146 40
        setcrop 36 34 1176 40
        CONTRAST="-brightness-contrast 0x40"
        OCR=GOCR
        TEST='^[0-9]+:[0-9][0-9]$'
        ;;
    *)
        echo Unknown option: $option
        # to cause error and invoke errfunc
        false
        ;;
esac


function adstring {
    if (( adend - adstart > MIN_AD_LEN )) ; then
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

for file in "$tempdir"/frame_*.$exten ; do
    seq=${file: -9}
    seq=${seq:0:5}
    seq=${seq##+(0)}
    let seq=seq*$samplerate
    convert "$file" $CROP $NEGATE $CONTRAST "$tempdir"/temp.$exten
    if $OCR 2>/dev/null | egrep "$TEST" >/dev/null 2>&1; then
        if [[ $adstart == "" ]] ; then
            adstart=$seq
        else
            adend=$seq
        fi
    else
        if (( seq - adstart > MAX_AD_LEN )) ; then
            adstring
        fi
    fi
done
adstring

rm -rf "$tempdir"

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
