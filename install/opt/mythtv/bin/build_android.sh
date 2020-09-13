#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

branch=`git branch|grep "^\* "|sed  "s/^\* //"`
echo branch $branch

if [[ -f $HOME/.buildrc ]] ; then
    . $HOME/.buildrc
fi

echo ndk version: > mythbuild.log
ls -l $HOME/Android/android-ndk >> mythbuild.log

if [[ "$BUILD_PREPARE" != "" ]] ; then
    pushd ../../mythtv/mythtv/
    $BUILD_PREPARE
    popd
fi

if [[ "$branch" == fixes/30 ]] ; then
    ./mythbuild.sh "$@" release 2>&1 | tee -a mythbuild.log
else
    make apk "$@" |& tee -a mythbuild.log
fi
echo "results in mythbuild.log"
if [[ "$BUILD_DONE" != "" ]] ; then
    pushd ../../mythtv/mythtv/
    $BUILD_DONE
    popd
fi

