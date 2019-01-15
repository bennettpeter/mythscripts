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
            cp -av $gitbasedir/../patch/build.patch $destdir/usr/share/mythtv/build.patch
        fi
        for file in $gitbasedir/../patch/Peter/${projname}_*.patch ; do
            if [[ -s "$file" ]] ; then
                cp -av "$file" $destdir/usr/share/mythtv/
            fi
        done

        ;;
    *)
        "$scriptpath/install.sh" "$@"
        ;;
esac
