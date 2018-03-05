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

# This will get projname and destdir
. "$scriptpath/getdestdir.source"

echo destination is  $destdir. Press enter to continue.
read xx

echo "chroot: $SCHROOT_CHROOT_NAME" > $gitbasedir/../install_${projname}.out
echo "branch: $branch" >> $gitbasedir/../install_${projname}.out
echo "dest: $destdir" >> $gitbasedir/../install_${projname}.out
case $projname in
    mythtv)
        rm -rf $destdir
        mkdir -p $destdir
        export INSTALL_ROOT=$destdir
        ;;
    jampal)
        rm -rf $destdir
        mkdir -p $destdir
        export DESTDIR=$destdir
        ;;
esac
make install |& tee -a $gitbasedir/../install_${projname}.out
echo Install Complete
