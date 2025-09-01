#!/bin/bash
set -e

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

# Override to use downloaded ffmpeg
if ! echo $PATH|grep /opt/ffmpeg/bin: ; then
  PATH="/opt/ffmpeg/bin/:$PATH"
fi

# defaults
encoder=x264
ffrate=n
error=n
tomp4=n
format=mkv
audio=copy
titlenum=
chapters=
subtitle=
Width=
Height=
startpos=
length=
x264_preset=faster
audiorate=48000
Quality=
extra_handbrake=
handbrake=
crop=0:0:0:0
detelecine=
reencode=n

while (( "$#" >= 1 )) ; do
    case $1 in
        -i)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -i." ; error=y
            else 
                input="$2"
                shift||rc=$?
            fi
            ;;
        -t)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -t." ; error=y 
            else 
                titlenum="$2"
                shift||rc=$?
            fi
            ;;
        -c)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -c." ; error=y 
            else 
                chapters="$2"
                shift||rc=$?
            fi
            ;;
        -s)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -s." ; error=y 
            else 
                subtitle="$2"
                shift||rc=$?
            fi
            ;;
        -o)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -o." ; error=y 
            else 
                output="$2"
                shift||rc=$?
            fi
            ;;
        -l)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -l." ; error=y 
            else
                Height="$2"
                shift||rc=$?
            fi
            ;;
        -w)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -w." ; error=y 
            else
                Width="$2"
                extra_handbrake="--no-keep-display-aspect --custom-anamorphic"
                shift||rc=$?
            fi
            ;;
        --morph)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for --morph." ; error=y 
            else 
                morph="$2"
                shift||rc=$?
            fi
            ;;
        --preset)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for --preset." ; error=y 
            else 
                preset="$2"
                shift||rc=$?
            fi
            ;;
        -r)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -r." ; error=y 
            else 
                framerate="$2"
                shift||rc=$?
            fi
            ;;
        -e)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -e." ; error=y 
            else 
                encoder="$2"
                shift||rc=$?
            fi
            ;;
        -f)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -f." ; error=y 
            else 
                format="$2"
                shift||rc=$?
            fi
            ;;
        -E)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -E." ; error=y 
            else 
                audio="$2"
                shift||rc=$?
            fi
            ;;
        -R)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -R." ; error=y 
            else 
                audiorate="$2"
                shift||rc=$?
            fi
            ;;
        -q)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -q." ; error=y 
            else 
                Quality="$2"
                shift||rc=$?
            fi
            ;;
        --crop)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for --crop." ; error=y 
            else 
                crop="$2"
                if [[ "$crop" == "AUTO" ]] ; then
                    crop=
                fi
                shift||rc=$?
            fi
           ;;
        --start-at)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for --start-at." ; error=y 
            else 
                startpos="$2"
                shift||rc=$?
            fi
           ;;
        --stop-at)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for --stop-at." ; error=y 
            else 
                length="$2"
                shift||rc=$?
            fi
           ;;
        --pfr)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for --pfr." ; error=y 
            else 
                pfrrate="$2"
                shift||rc=$?
            fi
           ;;
        --ffrate)
            ffrate=y
           ;;
        --tomp4)
            tomp4=y
           ;;
        --detelecine)
            detelecine=y
           ;;
        --reencode)
            reencode=y
            ;;
        --x264-preset)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for --x264-preset." ; error=y 
            else 
                x264_preset="$2"
                shift||rc=$?
            fi
           ;;
        --handbrake)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for --handbrake." ; error=y 
            else 
                handbrake=`echo "$2"|sed 's/@/ /g'`
                shift||rc=$?
            fi
           ;;
        *)
            echo "Invalid option $1"
            error=y
            ;;
    esac
    shift||rc=$?
done

if [[ "$input" == "" ]] ; then echo "Missing input file name." ; error=y ;  fi
if [[ "$preset" != "" && "$Height" != "" ]] ; then echo "Error - cannot use --preset and -l together." ; error=y; fi

if [[ "$framerate" != "" && "$pfrrate" != "" ]] ; then echo  "ERROR -r paramater inacompatible with --pfr." ; error=y ; fi

isDVD=N
if [[ -d "$input/VIDEO_TS" ]] ; then
    isDVD=Y
    if [[ "$titlenum" == "" ]] ; then
        titlenum=0
    fi
else
    if [[ "$subtitle" == "" ]] ; then
        subtitle=1
    fi
fi

if [[ "$encoder" == copy ]] ; then
    if [[ "$format" != mkv ]] ; then echo "Error: -e copy requires mkv output format." ; error=y; fi
    if [[ "$audio" != copy ]] ; then echo "Error: -e copy requires audio copy." ; error=y; fi
fi

if [[ "$error" == y ]] ; then
    echo "Generic encode video"
    echo "Options"
    echo "-i filename Input file."
    echo "  Directory name for a DVD. This directory must have a VIDEO_TS directory under it."
    echo "  Normally for a DVD it will be /media/DVD_NAME"
    echo "-t titlenum Title Number. Applies only to a DVD. Default 0."
    echo "  Use 0 to let a display of available titles without any encoding."
    echo "-c chapters Chapter number or numbers. Applies to a DVD. A number or range. Default all chapters."
    echo "-s subtitles: BURN, NONE, n. Default is first subtitle (1)"
    echo "-o filename Output file."
    echo "  Default is a file in directory encode, located where the input file is."
    echo "  For a DVD default is HOME/Videos/recordings/x264/media/username/dvd_dir/media/username"
    echo "--morph Aspect conversion - default is same as input"
    echo "  LB = crop Letterbox input if 4x3 into 16x9"
    echo "  SQ = stretched picture squeeze 16x9 picture vertically into 4x3" 
    echo "  SQLB = both - History channel FUBAR 16x9 into 16x9" 
    echo "  LB and SQLB override any crop setting provided"
    echo "  Only for use with x264 and ffmpeg (i.e. HandBrake)"
    echo "-l height Number of rows e.g. 480, 720, 1080"
    echo "  Default same as input, will set maximum width appropriately" 
    echo "  Examples" 
    echo "  360 = encode to 360 lines for portable DVD player"
    echo "  480 = encode to 480 rows for DVD quality"
    echo "  720 = encode to 720 rows"
    echo "  1080 = override size found with mediainfo for on demand recordings"
    echo "-w width Number of columns e.g. 640, 1280, 1920"
    echo "  This will distort the picture by forcing a particular size of the "
    echo "  final video. This should be used with crop otherwise auto crop "
    echo "  may result in an unexpected aspect ratio. "
    echo "--preset"
    echo "  PDVD = encode ffmpeg and lame to 360 rows to mp4 quality 4 for portable DVD Player"
    echo "       Use -q 6 for reality shows or those using more than 500MB/hr"
    echo "  ARCHIVE = encode X264 and lame to 480 rows for archiving"
    echo "-r framerate - default is same as input"
    echo "-e encoder - x264, mpeg4, copy - default x264"
    echo "-f format - mkv, mp4 - default mkv"
    echo "-E audio - mp3, copy, ac3, av_aac|aac, others - default copy"
    echo "-q quality - override quality level"
    echo "  Default is 21, 22 or 23 for x264, 4 for mpeg4. Lower is better"
    echo "-R audio sample rate for lame or aac - default 48000"
    echo "--crop T:B:L:R Crop parameter, or AUTO. Defaults to 0:0:0:0."
    echo "  Only for use with x264 and ffmpeg (i.e. HandBrake)"
    echo "--ffrate Fixed frame rate of < 30 fps"
    echo "  Ignored if -r is specified"
    echo "--tomp4 - convert resulting mkv file to mp4 and srt"
    echo "--start-at hh:mm:ss"
    echo "  Time to start encoding. Default at start of file"
    echo "--stop-at hh:mm:ss"
    echo "  Time to start encoding, or length of encoding. This is relative to start time. Default at end of file"
    echo "--pfr rate"
    echo "  Maximum frame rate"
    echo "--detelecine"
    echo "  Use HandBrake detelecine"
    echo "--handbrake  @options"
    echo "  Extra options for handbrake. Usa @ signs for spaces in options."
    echo "--x264-preset xxx"
    echo "  x264-preset. Default is faster"
    echo "  Valid values ultrafast superfast veryfast faster fast medium slow slower veryslow placebo"
    echo "--reencode - Always reencode the file, even if it is already in the correct format"
    echo "Any option that occurs more than once takes the last value"
    echo "Output goes to a log file"
    echo "This should be run with nohup and & except when called from multi_encode.sh"

    exit 2
fi

inputext=${input/*./}
if [[ "$inputext" == "$input" ]] ; then
    bname=${input%/}
else
    bname=`basename "$input" .$inputext`
fi

extension=$format

# DVD width = 852 max height = 480
# Set height and max width and let handbrake calculate the rest

if [[ "$isDVD" == Y ]] ; then
    orgHeight=480
else 
    eval `ffprobe "$input" -show_streams | egrep '^height=[1-9]|^width=[1-9]'`
    orgHeight=$height
    orgWidth=$width
    if [[ "$orgHeight" == "" ]] ; then
        orgHeight=`mediainfo '--Inform=Video;%Height%' "$input"` || echo Error - mediainfo failed
    fi
fi

if [[ "$preset" != "" ]] ; then
    case $preset in
        PDVD)
            Height=360
            encoder=mpeg4
            audio=mp3
            ffrate=y
            tomp4=y
            # Only use -q 6 if the source is bad quality and encodes to a big file, more than 500MB/hour
            # if [[ "$Quality" == "" ]] ;then
            #     Quality=6
            # fi
            ;;
        ARCHIVE)
            Height=480
            audio=mp3
            ;;
        *)
            echo "ERROR invalid preset $preset"
            exit 2
            ;;
    esac
fi

if [[ "$isDVD" == N ]] ; then
    # This gives MP3 but blank for AAC
    AudioCodec=`mediainfo '--Inform=Audio;%CodecID/Hint%' "$input"`
    if [[ "$AudioCodec" == "" ]] ; then
        # This gives AAC result
        AudioCodec=`mediainfo '--Inform=Audio;%Format%' "$input"`
    fi
    SamplingRate=`mediainfo '--Inform=Audio;%SamplingRate%' "$input"`
    VideoFormat=`mediainfo '--Inform=Video;%Format%' "$input"`
fi

if [[ "$reencode" == n ]] ; then

    if [[ ( "$audio" == lame || "$audio" == mp3 ) && "$isDVD" == N ]] ; then
        if [[ "$AudioCodec" == MP3 && "$SamplingRate" == "$audiorate" ]] ; then
            audio=copy
        fi
    fi

    if [[ ( "$audio" == aac || "$audio" == av_aac ) && "$isDVD" == N ]] ; then
        if [[ "$AudioCodec" == AAC && "$SamplingRate" == "$audiorate" ]] ; then
            audio=copy
        fi
    fi

    if [[ "$Height" == "" || "$Height" == "$orgHeight" ]] ; then
        if [[ "$audio" == copy && "$encoder" == x264 && "$VideoFormat" == AVC && "$morph" == "" ]] ; then
            encoder=copy
        fi
    fi
fi

if [[ "$Height" == "" ]] ; then
    Height=$orgHeight
    maxWidth=0
else
    let maxWidth=Height*16/9 1
fi

if (( Height > 1080)) ; then
    Height=1080
fi

if (( maxWidth == 0 || maxWidth > 1920 )) ; then
    maxWidth=1920
fi

if [[ "$Height" == "" ]] ; then 
    echo "Cannot find appropriate height for $input"
    exit 2
fi

if [[ "$morph" == SQ ]] ; then
    let Width=Height*4/3 1
    extra_handbrake="--no-keep-display-aspect --custom-anamorphic"
elif [[ "$morph" == SQLB ]] ; then
    let Width=Height*4/3 1
    let Height=Height*3/4 1
    extra_handbrake="--no-keep-display-aspect --custom-anamorphic"
elif [[ "$morph" == LB ]] ; then
    let Height=Height*3/4 1
    extra_handbrake="--no-keep-display-aspect --custom-anamorphic"
fi


if [[ "$encoder" == x264 && "$Quality" == "" ]] ; then
    if (( Height > 720 )) ; then 
        Quality=23
    elif (( Height > 480 )) ; then 
        Quality=22
    else
        Quality=21
    fi
fi

# make height and width divisible by 2
let Height=Height/2*2
if [[ "$Width" != "" ]] ; then
    let Width=Width/2*2 1
fi
let maxWidth=maxWidth/2*2 1

if [[ ( "$encoder" == mpeg4 ) \
      && "$Quality" == "" ]] ; then
    # 5/18/2014 change from 5 to 4
    Quality=4
fi

#~ if [[ ( "$audio" == lame || "$audio" == mp3 ) && "$isDVD" == N ]] ; then
    #~ AudioCodec=`mediainfo '--Inform=Audio;%CodecID/Hint%' "$input"`
    #~ SamplingRate=`mediainfo '--Inform=Audio;%SamplingRate%' "$input"`
    #~ if [[ "$AudioCodec" == MP3 && "$SamplingRate" == "$audiorate" ]] ; then
        #~ audio=copy
    #~ fi
#~ fi

#~ if [[ ( "$audio" == aac || "$audio" == av_aac ) && "$isDVD" == N ]] ; then
    #~ AudioCodec=`mediainfo '--Inform=Audio;%Format%' "$input"`
    #~ SamplingRate=`mediainfo '--Inform=Audio;%SamplingRate%' "$input"`
    #~ if [[ "$AudioCodec" == AAC && "$SamplingRate" == "$audiorate" ]] ; then
        #~ audio=copy
    #~ fi
#~ fi

if [[ "$ffrate" == y && "$framerate" == "" && "$isDVD" == N ]] ; then
    framerate=`mediainfo '--Inform=Video;%FrameRate%' "$input"`
    if [[ `echo "$framerate > 54" | bc` == 1 ]] ; then
        framerate="29.97"
    elif [[ `echo "$framerate > 30" | bc` == 1 ]] ; then
        framerate="23.976"
    elif [[ `echo "$framerate > 27" | bc` == 1 ]] ; then
        framerate="29.97"
    elif [[ `echo "$framerate == 25" | bc` == 1 ]] ; then
        framerate="25.000"
    else
        framerate="23.976"
    fi
fi


dname=`dirname "$input"`
if [[ "$output" == "" ]] ; then
    if [[ "$isDVD" == Y ]] ; then
        # dname="$HOME/Video/Recordings/$encoder/$bname/$titlenum/$chapters/"
        dname="$HOME/Videos/recordings/$encoder/$bname"
        mkdir -p "$dname"
        sep= ; if [[ "$chapters" != "" ]] ; then sep="_" ; fi
        output="$dname/${bname}_${titlenum}${sep}${chapters}".$extension
    else
        mkdir -p "$dname/encode/"
        output="$dname/encode/$bname".$extension
    fi
fi

output_dname=`dirname "$output"`
mkdir -p "$output_dname"
output_extension=${output/*./}
output_bname=`basename "$output" .$output_extension`

if [[ "$encoder" == copy ]] ; then
    mkvmerge \
    -o "$output" \
    "$input"
else
    encoder_opts=
    case $encoder in
    x264)
        # Timings 02/27/2014 (andromeda)
        # Using handbrake to encode one 60 minute 1080 source video
        # -e x264 --x264-preset XXXXXXXX --x264-profile high --x264-tune film -q 30 -E copy
        # MB = 1000000 bytes
        # superfast & q=30   - 24 min, 900 MB
        # faster & q=30      - 34 min, 813 MB
        # medium & q=30      - 43 min, 800 MB
        # faster & q=23      - 38 min, 1722 MB
        # faster & q=23 720p - 28 min, 901 MB
        # faster & q=23 480p - 24 min, 535 MB
        encoder_opts="--x264-preset $x264_preset --x264-profile high --x264-tune film"
        ;;
    mpeg4)
        encoder_opts=" -x mbd=1"
        ;;
    esac
    framerate_parm=
    if [[ "$framerate" != "" ]]; then
        framerate_parm="-r $framerate --cfr"
    fi
    if [[ "$pfrrate" != "" ]]; then
        framerate_parm="-r $pfrrate --pfr"
    fi
    audio_opts=
    if [[ "$audio" == lame || "$audio" == mp3 ]]; then
        audio=mp3
        audio_opts="--ac 2 --ab 128 --arate $audiorate"
    fi
    if [[ "$audio" == aac ]]; then
        audio=av_aac
        audio_opts="--arate $audiorate"
    fi

    crop_parm=
    if [[ "$crop" != "" ]]; then
        crop_parm="--crop $crop"
    fi
    startpos_parm="$startpos"
    if [[ "$startpos" == ??:??:?? ]]; then
        startpos_parm=`date --date="1970-01-01 $startpos UTC" +%s`
    fi
    if [[ "$startpos_parm" != "" ]]; then
        startpos_parm="--start-at pts:`time.sh $startpos_parm \* 90000 %d`"
    fi
    length_parm="$length"
    if [[ "$length" == ??:??:?? ]]; then
        length_parm=`date --date="1970-01-01 $length UTC" +%s`
    fi
    if [[ "$length_parm" != "" ]]; then
        length_parm="--stop-at pts:`time.sh $length_parm \* 90000 %d`"
    fi
    subtitle_parm=
    if [[ "$subtitle" == "NONE" ]] ; then
        subtitle_parm=" "
    elif [[ "$subtitle" == "" ]] ; then
        subtitle_parm="-s 1"
    else
        subtitle_parm="-s $subtitle"
    fi
    titlenum_parm=
    if [[ "$titlenum" != "" ]] ; then
        titlenum_parm="-t $titlenum"
    fi
    chapter_parm=
    if [[ "$chapters" != "" ]] ; then
        chapter_parm="-c $chapters"
    fi
    widthParm=
    if [[ "$Width" != "" ]] ; then
        widthParm="-w $Width"
        maxWidth=
    fi
    if (( maxWidth > 0 )) ; then
        maxWidthParm="-X $maxWidth"
    fi
    detele_parm=
    if [[ "$detelecine" == y ]]; then
        detele_parm="--detelecine"
    fi
    case $format in
    mkv)
        format=av_mkv
        ;;
    mp4)
        format=av_mp4
        ;;
    esac
    set -x
    HandBrakeCLI  -i "$input" -o "$output" -f $format -e $encoder $encoder_opts  \
        -q $Quality $framerate_parm -E $audio $audio_opts \
        --audio-fallback ac3 $crop_parm $widthParm -l $Height $maxWidthParm \
        --decomb $startpos_parm $length_parm $subtitle_parm $titlenum_parm \
        $chapter_parm $detele_parm $handbrake $extra_handbrake ; rc=$?
    echo HandBrakeCLI Return Code $rc
    if [[ "$rc" != 0 ]] ; then exit $rc ; fi
    if [[ "$isDVD" == Y ]] ; then exit $rc ; fi
    numinsub=`mediainfo "$input" '--Inform=Text;%StreamCount%'$'\t'|cut -f1`
    numoutsub=`mediainfo "$output" '--Inform=Text;%StreamCount%'$'\t'|cut -f1`
    cc=0
    ffprobe "$input" |& grep "Closed Captions" || cc=$?
    if (( cc == 0  )) ; then
        let numinsub=numinsub+1
    fi
    if (( numinsub > 0 && numoutsub == 0 )) ; then
        echo Extract Closed captions
        srtfile="$output_dname/$output_bname.srt.tmp"
        ccextractor "$input" -o $srtfile
        srtleng=`ls -l "$srtfile" | cut -d' ' -f5`
        if (( srtleng > 1000 )) ; then
            # subtitle_parm="--srt-file $srtfile --srt-codeset UTF-8"
            mkvmerge -o "$output".tmp2 "$output" --default-track 0:0 $srtfile
            mv -f "$output" "$output".tmp
            mv -f "$output".tmp2 "$output"
        fi
    fi
    if [[ "$tomp4" == y ]] ; then
        outdir=`dirname "$output"`
        outfile=`basename "$output"`
        outfilebase="${outfile%.*}"
        mp4outfile="$outdir/$outfilebase.mp4"
        ffmpeg -y -i "$output"  -acodec copy -vcodec copy -f mp4  "$mp4outfile"
    fi
    if [[ "$tomp4" == y  ]] ; then
        srtoutfile="$outdir/$outfilebase.srt"
        mkvextract tracks "$output" 2:"$srtoutfile" || echo "Subtitle extract failed"
    fi

fi
