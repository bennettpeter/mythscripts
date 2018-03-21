#!/bin/bash
# put this in $HOME/bin as build.sh
scriptpath=/opt/mythtv/bin
set -e

projname=`basename $PWD`

case $projname in
    android)
        exec "$scriptpath/build_android.sh" "$@"
        ;;
    *)
        exec "$scriptpath/build.sh" "$@"
        ;;
esac
