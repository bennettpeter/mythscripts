#!/bin/bash
file="$1"

exten=jpg
vidwidth=1280
vidheight=720
tempdir=.
NEGATE='-channel RGB -negate +channel'
CONTRAST="-brightness-contrast 0x40"

function setcrop {
    let cwidth=${1}*vidwidth/1280
    let cheight=${2}*vidheight/720
    let xoff=${3}*vidwidth/1280
    let yoff=${4}*vidheight/720
    CROP="-crop ${cwidth}x${cheight}+${xoff}+${yoff}"
}
set -x
setcrop $2 $3 $4 $5
convert "$file" $CROP $NEGATE $CONTRAST "$tempdir"/temp.$exten
