#!/bin/bash
# put this in $HOME/bin as install.sh
scriptpath=$HOME/proj/github.com/MythTV/packaging/deb-light
set -e

projname=`basename $PWD`

case $projname in
    android)
        install_android.sh "$@"
        ;;
    *)
        "$scriptpath/install.sh" "$@"
        ;;
esac
