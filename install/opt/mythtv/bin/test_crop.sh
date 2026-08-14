#!/bin/bash
file="$1"

exten=jpg
vidwidth=1280
vidheight=720
tempdir=.
NEGATE='-channel RGB -negate +channel'
con=$6
if [[ $con == "" ]] ; then
    con=0x90
fi
CONTRAST="-brightness-contrast $con"

function setcrop {
    let cwidth=${1}*vidwidth/1280
    let cheight=${2}*vidheight/720
    let xoff=${3}*vidwidth/1280
    let yoff=${4}*vidheight/720
    CROP="-crop ${cwidth}x${cheight}+${xoff}+${yoff}"
}
setcrop $2 $3 $4 $5
set -x
convert "$file" $CROP $NEGATE $CONTRAST "$tempdir"/temp.$exten
tesseract "$tempdir"/temp.$exten -
gocr "$tempdir"/temp.$exten
