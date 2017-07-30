#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

gitbasedir=`git rev-parse --show-toplevel`
projname=`basename $PWD`

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
