#!/bin/bash
# put this in $HOME/bin as install.sh
scriptpath=$HOME/proj/github.com/MythTV/packaging/deb-light
set -e

projname=`basename $PWD`

case $projname in
    android)
#        rm -vf build64/mythtv/stamp_configure_android
        ./mythbuild.sh "$@" fresh
        ;;
    *)
        "$scriptpath/config.sh" "$@"
        ;;
esac
