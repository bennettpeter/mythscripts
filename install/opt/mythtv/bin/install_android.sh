#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

gitbasedir=`git rev-parse --show-toplevel`

projname=`basename $PWD`

if [[ "$projname" == android ]] ; then
    apk_file=`ls -1tr mythfrontend-*.apk | tail -1`
    if [[ "$apk_file" == "" ]] ; then
        echo "ERROR - No apk file found"
        exit 2
    fi
    echo "Installing $apk_file"
    ./installapk.sh "$apk_file" 2>&1 | tee install.log
    echo "results in install.log"
    exit
fi
