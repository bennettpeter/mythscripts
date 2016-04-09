#!/bin/bash

echo "Encode mpg file"
echo "Parameters"
echo "1 - input file or VIDEO_TS directory"
echo "2 - frame rate 30000/1001 (NTSC) or 24000/1001 (PAL/Movie)"
echo "3 - scale - eg. 640:480 or 720:404 or 640:360 or 1280:720 or 1920:1080"
echo "4 - Quality Integer - lower is bettr quality - default = 4"
echo "5 - crop settings e.g. 688:464:6:8 before processing"
echo "6 - audio - mp3lame or copy (default mp3lame)"
echo "7 - start pos HH:MM:SS or 9999"
echo "8 - length HH:MM:SS or 9999"
echo "9 - out file optional"
echo "10 - deinterlace - Y or N, default N"
echo "11 - audio delay in seconds optional"
echo "12 - final aspect if source is not square pixels eg 640:480"
echo "13 - video encoder x264, xvid, copy - default xvid for SD, otherwise x264"
echo "Note the input must be fixed frame rate the same as the desired output"

# Width / bitrate
# 640x480 1000
# 720x480 1200
# 720x480 23.976 fps 1000
# 1280x720 30 fps 3000
# 1280x720 24 fps 2200
# 1920x1080 24 fps 4400


if [[ "$3" == "" ]]; then 
  exit 2
fi

set -e

INFILE=$1
FRAMERATE=$2
SCALE=$3
KBPS=1200
QUALITY=$4
CROP=$5
AUDIO=$6
STARTPOS=$7
LENGTH=$8
DEINTERLACE=${10}
OUTFILE=${9}
DELAY=${11}
ASPECT=${12}
encoder=${13}
indicator=${14}

ROWS=${SCALE#*:}
COLS=${SCALE%:*}
if [[ "$ASPECT" != "" ]] ; then
    ROWS=${ASPECT#*:}
    COLS=${ASPECT%:*}
fi

CROPKW=
CROPCOMMA=
if [[ "$CROP" != "" ]]; then
    CROPKW="crop="
    CROPCOMMA=","
fi

STARTKW=
if [[ "$STARTPOS" != "" ]]; then 
    STARTKW="-ss"
    if [[ $STARTPOS == +([0-9]) ]] ; then
        STARTPOS=`TZ=UTC date --date=@$STARTPOS +%H:%M:%S`
    fi
fi

LENGKW=
if [[ "$LENGTH" != "" ]]; then
    LENGKW="-endpos"
    if [[ $LENGTH == +([0-9]) ]] ; then
        LENGTH=`TZ=UTC date --date=@$LENGTH +%H:%M:%S`
    fi
fi

if [[ "$QUALITY" == "" ]] ; then
    QUALITY=4
fi

if [[ "$AUDIO" = "" ]]; then
    AUDIO=mp3lame
fi

DEINTOPT="pp=fd,"
if [[ "$DEINTERLACE" = N || "$DEINTERLACE" = "" ]]; then
    DEINTOPT=""
elif  [[ "$DEINTERLACE" != Y ]]; then
    echo "Invalid deinterlace option"
    exit 2
fi

if [[ "$OUTFILE" == "" ]]; then
    OUTFILE="$INFILE.avi"
fi

if [[ "$DELAY" == "" ]]; then
    DELAY=0
fi

if [[ "$ASPECT" != "" ]]; then
    ASPECT="-force-avi-aspect $ASPECT"
fi

DVDPARM=""
if [[ -d "$INFILE" ]] ; then
    DVDPARM="dvd://1 -dvd-device"
fi

# Ultrafast - 1hour movie 1080 done in 1 hour including both passes
# poor picture - artifacts
x264uf="preset=ultrafast"

# Superfast - 5 min 1080 2 pass done in 5 min - good quality at 5000 kbits
# Reduce to 0.34 of the size
x264sf="preset=superfast"


# Veryfast - 1hour movie 1080 taking over 3.5 hours - looks like will be 5 hours (no improvement in picture)
x264vf="preset=veryfast"


# FAST 30 fps 45%CPU - ok for 720p
x264f="subq=4:bframes=2:b_pyramid=normal:weight_b"

# HQ
x264hq="subq=5:8x8dct:frameref=2:bframes=3:b_pyramid=normal:weight_b"

# VHQ 14-15 fps
x264vhq="subq=6:partitions=all:8x8dct:me=umh:frameref=5:bframes=3:b_pyramid=normal:weight_b"

#if [[ "$FRAMERATE" == "24000/1001" ]] ; then
    # PULLUP="pullup,softskip,"
    # DEINTOPT=""
#fi

passes=2
if [[ "$encoder" == "" ]] ; then
    if (( COLS > 1280 )) ; then
        encoder="x264"
    elif (( COLS > 720 )) ; then
        encoder="x264"
    else
        encoder="xvid"
    fi
fi
if [[ "$encoder" == "x264"  ]]; then
    encoder="-ovc x264 -x264encopts $x264sf:bitrate=$KBPS:threads=4"
elif [[ "$encoder" == "xvid"  ]]; then
    passes=1
    encoder="-ovc xvid -xvidencopts \
chroma_opt:vhq=0:bvhq=1:quant_type=mpeg:trellis:\
threads=4:turbo"
# removed :max_key_interval=60
else
    encoder="-ovc $encoder"
    passes=1
fi



#wrong
# encoder="-ovc x264 -x264encopts 
# bitrate=$KBPS:cabac:deblock:frameref=3:bframes=2:
# b_adapt:qp_step=4:4x4mv:weight_b:chroma_me:threads=4"

if [[ "$mencoder" == "" ]] ; then
    mencoder="mencoder"
    #mencoder="/C/Products-Video/MPlayer-athlon-svn-31743/mencoder"
fi


# removed pullup,softskip,hqdn3d=2:1:2
# use pullup,softskip if there is 23.97 fps content
# title "Pass 1 %INFILE%"


set -x
#  -ovc xvid -xvidencopts chroma_opt:vhq=0:bvhq=1:quant_type=mpeg:trellis:bitrate=$KBPS:threads=8:pass=1:turbo:max_key_interval=60

# -mc 0 causes "Too many video packets in the buffer" and out of sync sound
# even using 24000/1001 causes that message with 1080 encoding

if [[ "$passes" == 2 ]] ; then 
"$mencoder" $DVDPARM "$INFILE" -ofps $FRAMERATE -nosound -o /dev/null  ${encoder}:pass=1 \
-vf ${PULLUP}$CROPKW$CROP${CROPCOMMA}${DEINTOPT}scale=$SCALE $ASPECT -quiet $MENCODER_EXTRA \
 -passlogfile "$OUTFILE.log" $STARTKW $STARTPOS $LENGKW $LENGTH -delay $DELAY
pass2settings="${encoder}:pass=2:bitrate=$KBPS"
else
    pass2settings="${encoder}:fixed_quant=$QUALITY"
fi

# -xvidencopts bvhq=1:chroma_opt:quant_type=mpeg:bitrate=658:pass=1
# title "Pass 2 %INFILE%"

#  -ovc xvid -xvidencopts chroma_opt:vhq=4:bvhq=1:quant_type=mpeg:trellis:bitrate=$KBPS:threads=8:pass=2:max_key_interval=60

# -mc 0 -noskip - this prevents "too many audio samples in buffer" but results is audio sync issues

set -x

"$mencoder" $DVDPARM "$INFILE" -ofps $FRAMERATE -fps $FRAMERATE \
    -oac $AUDIO -lameopts cbr:br=128:aq=2 -o "$OUTFILE"  \
    $pass2settings -passlogfile "$OUTFILE.log" -vf ${PULLUP}$CROPKW$CROP${CROPCOMMA}${DEINTOPT}scale=$SCALE,harddup $ASPECT $MENCODER_EXTRA \
     $STARTKW $STARTPOS $LENGKW $LENGTH -delay $DELAY
# removed -quiet 

