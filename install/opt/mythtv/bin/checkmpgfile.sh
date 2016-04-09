#!/bin/bash
# check if an mpg file is valid
testfile="$1"
Duration=
Height=
eval `mediainfo '--Inform=General;Duration=%Duration%' $testfile`
Duration=${Duration%.*}
eval `mediainfo '--Inform=Video;Height=%Height%' $testfile`
if (( Duration < 100 || Height < 480 )) ; then
    echo "File $testfile is not valid: Duration $Duration Height $Height"
    exit 2
else
    echo "File $testfile is valid: Duration $Duration Height $Height"
fi
