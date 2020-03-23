#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

branch=`git branch|grep "^\* "|sed  "s/^\* //"`
echo branch $branch

if [[ -f $HOME/.buildrc ]] ; then
    . $HOME/.buildrc
fi

if [[ "$BUILD_PREPARE" != "" ]] ; then
    pushd ../../mythtv/mythtv/
    $BUILD_PREPARE
    popd
fi

if [[ "$branch" == fixes/30 ]] ; then
    ./mythbuild.sh "$@" release 2>&1 | tee mythbuild.log
else
    make apk "$@" |& tee mythbuild.log
fi
echo "results in mythbuild.log"
if [[ "$BUILD_DONE" != "" ]] ; then
    pushd ../../mythtv/mythtv/
    $BUILD_DONE
    popd
fi

