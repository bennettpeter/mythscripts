#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

projname=`basename $PWD`

if [[ -f $HOME/.buildrc ]] ; then
    . $HOME/.buildrc
fi

if [[ "$projname" == android ]] ; then
    if [[ "$BUILD_PREPARE" != "" ]] ; then
        pushd ../../mythtv/mythtv/
        $BUILD_PREPARE
        popd
    fi
    # these paths are now in .bashrc so that adb etc can be found.
    # export PATH=$HOME/android/android-sdk-linux/platform-tools:$HOME/android/android-sdk-linux/build-tools/`ls $HOME/android/android-sdk-linux/build-tools/ | tail -1`:$PATH
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
            mv -v "$apkfile" "$newname"
        fi
    fi
fi

