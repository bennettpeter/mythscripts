#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

projname=`basename $PWD`

if [[ -f $HOME/.buildrc ]] ; then
    . $HOME/.buildrc
fi

if [[ "$projname" == android ]] ; then
    pushd ../../mythtv/mythtv/
    if which $BUILD_PREPARE ; then
        $BUILD_PREPARE
    fi
    popd
    # these paths are now in .bashrc so that adb etc can be found.
    # export PATH=$HOME/android/android-sdk-linux/platform-tools:$HOME/android/android-sdk-linux/build-tools/`ls $HOME/android/android-sdk-linux/build-tools/ | tail -1`:$PATH
    ./mythbuild.sh "$@" 2>&1 | tee mythbuild.log
    echo "results in mythbuild.log"
fi

