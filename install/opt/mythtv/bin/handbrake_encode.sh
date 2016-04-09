#!/bin/bash
echo "Encode mpg file"
echo "Parameters"
echo " 1 - *input file"
echo " 2 -  frame rate 5, 10, 12, 15, 23.976, 24, 25, or 29.97 or blank (=Variable)"
echo "      For Variable leave blank = copy from input"
echo " 3 - *scale - eg. 640:480, 720:404, 852:480, 640:360, 1280:720, 1920:1080"
echo " 4 - quality - default 30"
echo " 5 - crop settings e.g. 8:8:8:8. Default - auto detect"
echo " 6 - audio - lame or copy or others (default copy)"
echo " 7 - start pos HH:MM:SS or sss default 0"
echo " 8 - length HH:MM:SS or sss default all"
echo " 9 - out file optional. if 3 characters long it supplies the extension."
echo "     Default is mkv. Format is mkv unless this has mp4 specified."
echo "10 - encoder: x264 or ffmpeg4, default x264"
echo "11 - title number on dvd - default 1"
echo "12 - Subtitles and other settings, Default -s 1"
echo ""
echo "Subtitle settings:"
echo "Subtitle track(s) in same format as in input: -s <number>"
echo "Subtitle track burned in: -s <number> --subtitle-burn 1"
echo "Subtitle track from SRT file: --srt-file filename --srt-codeset UTF-8"
echo "No Subtitle: ' ' (1 space in quotes)"
echo "Extra parameters can be in HANDBRAKE_EXTRA"

# Size Quality Audio GiB/hr 
# 1080   30     ac3  0.8-1.0

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

if [[ "$3" == "" ]]; then 
  exit 2
fi

set -e

INFILE=$1
FRAMERATE=$2
SCALE=$3
QUALITY=$4
CROP=$5
AUDIO=$6
STARTPOS=$7
LENGTH=$8
OUTFILE=${9}
ENCODER=${10}
TITLENUM=${11}
SUBTITLES=${12}

if [[ "$FRAMERATE" != "" ]]; then
    FRAMERATE="-r $FRAMERATE"
fi

ROWS=${SCALE#*:}
COLS=${SCALE%:*}

if [[ "$QUALITY" == "" ]]; then
    QUALITY=30
fi

if [[ "$CROP" != "" ]]; then
    CROP="--crop $CROP"
fi

if [[ "$AUDIO" == "" ]]; then
    AUDIO=copy
fi

if [[ "$AUDIO" == lame ]]; then
    AUDIO="lame --ac 2 --ab 128"
fi

if [[ "$STARTPOS" == ??:??:?? ]]; then
    STARTPOS=`date --date="1970-01-01 $STARTPOS UTC" +%s`
fi
if [[ "$STARTPOS" != "" ]]; then
#    STARTPOS="--start-at duration:"$STARTPOS
    STARTPOS="--start-at pts:`time.sh $STARTPOS \* 90000 %d`"
fi

if [[ "$LENGTH" == ??:??:?? ]]; then
    LENGTH=`date --date="1970-01-01 $LENGTH UTC" +%s`
fi
if [[ "$LENGTH" != "" ]]; then
#    LENGTH="--stop-at duration:"$LENGTH
    LENGTH="--stop-at pts:`time.sh $LENGTH \* 90000 %d`"
fi

if [[ "$OUTFILE" == "" ]]; then
    if (( ROWS > 480 )) ; then
        OUTFILE="$INFILE.mkv"
    else
        OUTFILE="$INFILE.mkv"
    fi
fi

if [[ ${#OUTFILE} == 3 ]] ; then
    OUTFILE="$INFILE.$OUTFILE"
fi

if [[ "$ENCODER" == "" ]] ; then
    ENCODER=x264
fi

TITLEPARM=
if [[ "$TITLENUM" != "" ]] ; then
    TITLEPARM="-t $TITLENUM"
fi

#if (( ROWS > 480 )) ; then
#    FORMAT=mkv
#else
#    FORMAT=mkv
#fi

extension=${OUTFILE/*./}
FORMAT=mkv
if [[ "$extension" == "mp4" || "$extension" == "mp4_incomplete" ]] ; then
    FORMAT=mp4
fi

if [[ "$SUBTITLES" == "" ]] ; then
    SUBTITLES="-s 1"
fi

# Timings 02/27/2014 (andromeda)
# Using handbrake to encode one 60 minute 1080 video
# -e x264 --x264-preset XXXXXXXX --x264-profile high --x264-tune film -q 30 -E copy
# superfast - 24 min, 900 MB
# faster    - 34 min, 813 MB
# medium    - 43 min, 800 MB

if (( ROWS > 720 )) ; then
    encoder="-e x264  --x264-preset faster --x264-profile high --x264-tune film"
elif (( ROWS > 480 )) ; then
    encoder="-e x264  --x264-preset faster --x264-profile high --x264-tune film"
else
    # qscale can be from 1 (good) to 31 (bad), with sane values being 2-5.
    # -qscale:v 4 will override the bitrate
    # ’-mbd rd -flags +mv4+aic -trellis 2 -cmp 2 -subcmp 2 -g 300
    # xvid was chroma_opt:vhq=0:bvhq=1:quant_type=mpeg:trellis:bitrate=$KBPS:threads=4:turbo:max_key_interval=60
    # things to try: '-bf 2', '-flags qprd', '-flags mv0', '-flags skiprd'. but beware the '-g 100' might cause problems with some decoders.
    #encoder="-vcodec mpeg4 -b ${KBPS}k  -f avi -vtag xvid -mbd rd -flags +mv4+aic -trellis 2 -cmp 2 -subcmp 2 -g 300"
    #removed profile baseline
    encoder="-e x264  --x264-preset medium --x264-profile high --x264-tune film"
fi

if [[ "$ENCODER" == "ffmpeg4" ]]; then
    encoder="-e ffmpeg4 -x mbd=1"
fi
encoderexe="HandBrakeCLI"

set -x

"$encoderexe"  -i "$INFILE" -o "$OUTFILE" -f $FORMAT $encoder -q $QUALITY $FRAMERATE -E $AUDIO \
 --audio-fallback ffac3 $CROP -w $COLS -l $ROWS --decomb $STARTPOS $LENGTH $SUBTITLES $TITLEPARM $HANDBRAKE_EXTRA


