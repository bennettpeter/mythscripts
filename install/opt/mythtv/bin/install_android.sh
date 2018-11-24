#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

opt="$1"
gitbasedir=`git rev-parse --show-toplevel`

projname=`basename $PWD`

if [[ "$projname" == android ]] ; then
    ARM64=0
    $HOME/android/setenv.sh
    source ./make.inc
    if [[ "$opt" == "--oldarm" ]] ; then
        apk_file=`ls -1tr mythfrontend-*-armold-*.apk | tail -1`
    elif [[ "$ARM64" == 1 ]] ; then
        apk_file=`ls -1tr mythfrontend-*-arm64-*.apk | tail -1`
    else
        apk_file=`ls -1tr mythfrontend-*-arm-*.apk | tail -1`
    fi
    if [[ "$apk_file" == "" ]] ; then
        echo "ERROR - No apk file found"
        exit 2
    fi
    echo "Installing $apk_file"
    ./installapk.sh "$apk_file" 2>&1 | tee install.log
    echo "results in install.log"
    exit
fi
