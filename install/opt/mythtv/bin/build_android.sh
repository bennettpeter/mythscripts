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
    # add  --no-plugins for non plugin build in future.
    ./mythbuild.sh "$@" 2>&1 | tee mythbuild.log
    echo "results in mythbuild.log"
fi

