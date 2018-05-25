#!/bin/bash
# put this in $HOME/bin as build.sh
scriptpath=$HOME/proj/github.com/MythTV/packaging/deb-light
set -e

projname=`basename $PWD`

case $projname in
    android)
        build_android.sh "$@"
        ;;
    *)
        exec "$scriptpath/build.sh" "$@"
        ;;
esac