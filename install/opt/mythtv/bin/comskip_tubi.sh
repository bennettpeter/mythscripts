#!/bin/bash
# Commercial skip for tubi recordings
# command line - 
# for a video:
# /opt/mythtv/bin/comskip_tubi.sh "filename"
# the filename must be a full file name relative to the videos directory

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

# Get DB password
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName --batch --column-names=FALSE $DBName"

function errfunc {
    if [[ "$title" == "" ]] ; then
        title="$filename"
    fi
    "$scriptpath/notify.py" "commskip_tubi failed" "$title" "$subtitle"
    exit 2
}
trap errfunc ERR

echo Set IO priority to -c3 idle
ionice -c3 -p$$
error=0
exten=jpg
CROP="-gravity NorthWest -crop 30%x15%"
NEGATE='-channel RGB -negate +channel'
MAX_AD_LEN=240
MIN_AD_LEN=12
EXTRA_SECS=2
frameratex1000=60000
samplerate=1

tempdir=${fullfilename%.*}_tmp

function adstring {
    if (( adend - adstart > MIN_AD_LEN )) ; then
        let fseq1=adstart*60-EXTRA_SECS*60
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
    convert "$file" $CROP $NEGATE -brightness-contrast 0x40 "$tempdir"/temp.$exten
    if tesseract -c page_separator="" "$tempdir"/temp.$exten - 2>/dev/null \
        | egrep "Ad|0:[0-1]" >/dev/null 2>&1; then
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
