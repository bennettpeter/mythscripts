#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

gitbasedir=`git rev-parse --show-toplevel`
projname=`basename $PWD`

git clean -xfd
if [[ -x "$scriptpath/prepare_source.sh" ]] ; then
    "$scriptpath/prepare_source.sh"
fi
branch=`git branch | grep '*'| cut -f2 -d' '`
echo "chroot: $SCHROOT_CHROOT_NAME" > $gitbasedir/../config_${projname}.out
echo "branch: $branch" >> $gitbasedir/../config_${projname}.out
echo "$branch" > $gitbasedir/../config_${projname}.branch

case $projname in
    mythtv)
        config_opt=
        if [[ `arch` == arm* ]] ; then
            if echo "$branch" | grep "0.28" ; then
                omx_option="--enable-openmax"
            else
                omx_option="--enable-omx-rpi"
            fi
            config_opt="$omx_option --disable-vdpau \
              --disable-opengl-video --enable-opengl --disable-opengl-themepainter \
              --disable-vaapi"
        fi
        set -x
        ./configure --prefix=/usr $config_opt |& tee -a $gitbasedir/../config_${projname}.out
        set -
        ;;
    mythplugins)
        . "$scriptpath/getdestdir.source"
        mkdir -p $destdir
        sourcedir=`echo $destdir|sed s/mythplugins/mythtv/`
        gitver=`git describe --dirty|cut -c2-`
        packagever=`env LD_LIBRARY_PATH=$sourcedir/usr/lib $sourcedir/usr/bin/mythutil --version |grep "MythTV Version"|cut -d ' ' -f 4|cut -c2-`
        if [[ "$packagever" != "$gitver" ]] ; then
            echo ERROR Package version $packagever does not match git version $gitver
            exit 2
        fi
        cd ../mythtv
        git clean -xfd
        config_opt=
        if [[ `arch` == arm* ]] ; then
            if echo "$branch" | grep "0.28" ; then
                omx_option="--enable-openmax"
            else
                omx_option="--enable-omx-rpi"
            fi
            config_opt="$omx_option --disable-vdpau \
              --disable-opengl-video --enable-opengl --disable-opengl-themepainter \
              --disable-vaapi"
        fi
        set -x
        ./configure --prefix=$destdir/usr \
          --runprefix=/usr $config_opt | tee -a  $gitbasedir/../config_${projname}.out
        rm -rf $destdir
        cp -a $sourcedir/ $destdir/
        cp libs/libmythbase/mythconfig.h libs/libmythbase/mythconfig.mak \
         $destdir/usr/include/mythtv/
        cd ../mythplugins
        git clean -xfd
        basedir=$destdir/usr
        export PYTHONPATH=$basedir/local/lib/python2.7/dist-packages
        config_opt=
        if [[ `arch` == arm* ]] ; then
            config_opt="--disable-mythgallery"
        fi
        ./configure --prefix=$destdir/usr \
         $config_opt | tee -a  $gitbasedir/../config_${projname}.out
         set -
        ;;
esac
echo Completed configure
