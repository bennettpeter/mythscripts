#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

if [[ -f $HOME/.buildrc ]] ; then
    . $HOME/.buildrc
fi

if [[ "$BUILD_PREPARE" != "" ]] ; then
    pushd ../../mythtv/mythtv/
    $BUILD_PREPARE
    popd
fi
./mythbuild.sh "$@" release 2>&1 | tee mythbuild.log
echo "results in mythbuild.log"
if [[ "$BUILD_DONE" != "" ]] ; then
    pushd ../../mythtv/mythtv/
    $BUILD_DONE
    dirty=`git status --porcelain|grep -v "^??"|wc -l`
    popd
    if [[ "$dirty" == 0 ]] ; then
        apkfile=`ls -t *.apk | head -1`
        newname=`echo $apkfile | sed s/-dirty/-clean/`
        if [[ "$apkfile" != "$newname" ]] ; then
            mv -v "$apkfile" "$newname"
        fi
    fi
fi

