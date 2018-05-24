#!/bin/bash
# put this in $HOME/bin as install.sh
scriptpath=$HOME/proj/github.com/MythTV/packaging/deb-light
set -e

# This will get projname and destdir
. "$scriptpath/getdestdir.source"

case $projname in
    android)
        install_android.sh "$@"
        ;;
    mythtv)
        "$scriptpath/install.sh" "$@"
        gitbasedir=`git rev-parse --show-toplevel`
        if [[ -s $gitbasedir/../patch/build.patch ]] ; then
            set -x
            cp -a $gitbasedir/../patch/build.patch $destdir/usr/share/mythtv/build.patch
        fi
        ;;
    *)
        "$scriptpath/install.sh" "$@"
        ;;
esac
