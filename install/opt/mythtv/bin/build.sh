#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

gitbasedir=`git rev-parse --show-toplevel`
projname=`basename $PWD`

if [[ -x "$scriptpath/prepare_source.sh" ]] ; then
    "$scriptpath/prepare_source.sh"
fi

branch=`git branch | grep '*'| cut -f2 -d' '`
echo "chroot: $SCHROOT_CHROOT_NAME" > $gitbasedir/../build_${projname}.out
echo "branch: $branch" >> $gitbasedir/../build_${projname}.out
numjobs=5
if [[ `arch` == arm* ]] ; then
    numjobs=3
fi
setsid make -j $numjobs |& tee -a $gitbasedir/../build_${projname}.out
echo Completed build
