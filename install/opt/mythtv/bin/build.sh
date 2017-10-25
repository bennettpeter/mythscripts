#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

gitbasedir=`git rev-parse --show-toplevel`
projname=`basename $PWD`

if [[ -x "$scriptpath/prepare_source.sh" ]] ; then
    "$scriptpath/prepare_source.sh"
fi

. "$scriptpath/setccache.source"

branch=`git branch | grep '*'| cut -f2 -d' '`
if [[ "$branch" == '(HEAD' ]] ; then
    branch=`git branch | grep '*'| cut -f3 -d' '`
fi
echo "chroot: $SCHROOT_CHROOT_NAME" > $gitbasedir/../build_${projname}.out
echo "arch: $arch codename: $codename branch: $branch" >> $gitbasedir/../build_${projname}.out
config_branch=`cat $gitbasedir/../config_${projname}.branch` || true
if [[ "$arch/$codename/$branch" != "$config_branch" ]] ; then
    echo "Need to run config again. Now=$arch/$codename/$branch Config=$config_branch"
    exit 2
fi

numjobs=5
if [[ `arch` == arm* ]] ; then
    numjobs=3
fi
setsid make -j $numjobs |& tee -a $gitbasedir/../build_${projname}.out
echo Completed build
