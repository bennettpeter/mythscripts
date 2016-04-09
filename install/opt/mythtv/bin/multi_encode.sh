#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

shopt -s extglob
set -e

# Defaults
pattern="*"
dest=encode
default_ext=mkv
followlinks=N
encodeoptions=N
script="$scriptpath/encode_video.sh"

while (( "$#" >= 1 )) ; do
    case $1 in
        -i)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -i." ; error=y
            else 
                pattern="$2"
                shift||rc=$?
            fi
            ;;
        -o)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -o." ; error=y 
            else 
                dest="$2"
                shift||rc=$?
            fi
            ;;
        -s)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -s." ; error=y 
            else 
                script="$2"
                shift||rc=$?
            fi
            ;;
        -f)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -f." ; error=y 
            else 
                default_ext="$2"
                shift||rc=$?
            fi
            ;;
        -l)
            followlinks=Y
            ;;
        -x)
            encodeoptions=Y
            ;;
        --help)
            error=y
            ;;
        *)
            echo "Invalid option $1"
            error=y
            ;;
    esac
    shift||rc=$?
    if [[ "$encodeoptions" == Y ]] ; then break ; fi
done

if ! ls $pattern >/dev/null 2>&1; then
    echo "No files to process"
    error=y
fi

if [[ "$error" == y ]]; then
    echo "Encode video using script specified for all mpg files in current directory"
    echo "Options"
    echo "-i  filepattern - input file pattern - default * (enclose in quotes)"
    echo "-o  dirname - output directory name - default encode"
    echo "-s  script name - default encode_video.sh"
    echo "-f  output file format - mkv, avi, mp4 - defaults to mkv"
    echo "-l  If there are file links it follows the link"
    echo "    and stores the result in a directory off the source directory of the file."
    echo "-x  Any options following this are to be passed straight to the script"
    echo "Any text in a file named filename.options where filename matches a video file"
    echo "    will be sourced and any value marked ENCODER_OPTIONS[0] will be appended as" 
    echo "    additional options."
    echo "    If there are also values for ENCODER_OPTIONS[1]. ENCODER_OPTIONS[2], etc"
    echo "    second and third, etc. encodings of the same file will be done."
    echo "--help Display this help text"
    echo "This should be run with nohup and &"
    exit 2
fi

maindir="$PWD"

for file in $pattern ; do
    if [[ "$file" == "nohup.out" || "$file" == *.log || \
          "$file" == *_failed || "$file" == *_done || \
          "$file" == *.options ]] ; then
        continue
    fi
    if [[ ! -f "$file" ]] ; then
        continue
    fi
    sleep 5
    bname="${file%.*}"
    optionsfile="$bname.options"
    unset ENCODER_OPTIONS
    unset OUTPUT_FORMAT
    if [[ -f "$optionsfile" ]] ; then
        . "$optionsfile" 
    fi
    echo running > "$maindir/${file}.x.busy"
    echo Created "$maindir/${file}.x.busy"
    for (( counter=0 ; counter<10 ; counter++ )) ; do
        if [[ ! -f "$file" ]] ; then
            break
        fi
        if (( counter>0 )) ; then 
            if [[ "${ENCODER_OPTIONS[counter]}" == "" ]] ; then
                continue
            fi
        fi
        ext=$default_ext
        if [[ "${OUTPUT_FORMAT[counter]}" != "" ]] ; then
            ext="${OUTPUT_FORMAT[counter]}"
        fi
        sleep 10
        canrun=1
        idle=$(mpstat 1 1|grep Average:|sed 's/.* //')
        canrun=`echo "$idle > 20"|bc`
        while [[ "$canrun" == 0 ]] ; do
            sleep 20
            idle=$(mpstat 1 1|grep Average:|sed 's/.* //')
            canrun=`echo "$idle > 20"|bc`
            if [[ "$canrun" == 1 ]] ; then 
                numprocs=`pidof HandBrakeCLI|wc -w`
                if (( numprocs > 4 )) ; then
                    canrun=0
                fi
            fi
        done
        if [[ -L "$file" && "$followlinks" == Y ]] ; then
            realfilepath=`readlink -e "$file"`
            realfile=`basename "$realfilepath"`
            realdir=`dirname "$realfilepath"`
        else
            realfile="$file"
            realdir="$maindir"
        fi
        cd "$realdir"
        if (( counter==0 )) ; then
            outdir="$dest"
        else
            outdir="${dest}$counter"
        fi
        mkdir -p "$outdir/"
        rbname="${realfile%.*}"
        if [[ -f "${outdir}/$rbname.$ext" ]]; then
            echo "$file already done ***"
            # mv -f "$maindir/$file" "$maindir/${file}_done"
            cd "$maindir"
            continue
        fi
        if [[ ! -f "${realfile}" ]]; then
            echo "$realfile not found ***"
            cd "$maindir"
            continue
        fi
        # Set a semaphore file
        echo running > "$maindir/${file}.$counter.busy"
        echo Created "$maindir/${file}.$counter.busy"
        (
            # currentfile="${bname}_$counter.$ext"
            # ln -fv "$realfile" "${bname}_$counter.$ext"
            
            echo "Encoding $realfile" "${outdir}/$rbname.${ext}_incomplete"
            rc=0
            "$script" -i "$realfile" -o "${outdir}/$rbname.${ext}_incomplete" -f "$ext" "$@" ${ENCODER_OPTIONS[counter]} \
                >> "${outdir}/$rbname.log" 2>&1 || rc=$?
            sleep 0.2
            if [[ "$rc" == 0 ]] ; then
                mv -fv "${outdir}/$rbname.${ext}_incomplete" "${outdir}/$rbname.$ext"
                if [[ "$realdir" != "$maindir" ]] ; then
                    mkdir -p "$maindir/$outdir/"
                    ln -s -v "$realdir/$outdir/$rbname.$ext" "$maindir/$outdir/$rbname.$ext"
                fi
                rm -fv "$maindir/${file}.$counter.busy"
                if ! ls "$maindir/${file}".*.busy ; then
                    # mv -fv "$realfile" "${realfile}_done"
                    mv -fv "$maindir/${file}" "$maindir/${file}_done"
                fi
            else
                echo "Encoding $file failed"
                # mv -fv "$realfile" "${realfile}_failed"
                mv -fv "$maindir/${file}" "$maindir/${file}_failed"
                break
            fi
        ) &
        cd "$maindir"
    done
    rm -fv "$maindir/${file}.x.busy"
done
wait
echo done
rm -fv mustrun_tcencode

