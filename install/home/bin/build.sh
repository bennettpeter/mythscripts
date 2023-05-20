#!/bin/bash
# put this in $HOME/bin as build.sh
scriptpath=$HOME/proj/github.com/MythTV/packaging/deb-light
set -e

PROJNAME=`basename $PWD`
export PROJNAME

case $PROJNAME in
    android)
        build_android.sh "$@"
        ;;
    backend)
        npm run build
        ;;
    *)
        exec "$scriptpath/build.sh" "$@"
        ;;
esac
