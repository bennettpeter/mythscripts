#!/bin/bash
set -e
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
#scriptname=`basename "$scriptname" .sh`
gitpath="$PWD"
# cd $scriptpath
sourcedir=$1
subrelease=$2
if [[ "$sourcedir" == "" ]] ; then
    echo Before running this the latest version must be built
    echo with --prefix=/usr --runprefix=/usr and installed
    echo Parameter 1 = install dir
    echo Parameter 2 = subrelease number
    echo Run this from the git source directory
    exit 2
fi
sourcedir=`readlink -f "$sourcedir"`
if [[ "$subrelease" == "" ]] ; then subrelease=0 ; fi
packagever=`git -C "$gitpath" describe --dirty|cut -c2-|sed  's/-pre/~pre/'`-$subrelease
installdir=`git -C "$gitpath" rev-parse --show-toplevel`
installdir=`dirname "$installdir"`
arch=`dpkg-architecture -q DEB_TARGET_ARCH`
codename=`lsb_release -c|cut -f 2`
packagename=mythtv-light_${packagever}_${arch}_$codename
echo Package $packagename
if [[ -f $installdir/$packagename.deb ]] ; then
    echo $installdir/$packagename.deb already exists - run with a subrelease number
    exit 2
fi
rm -rf $installdir/$packagename $installdir/$packagename.deb
cp -a "$sourcedir/" "$installdir/$packagename/"
mkdir -p $installdir/$packagename/DEBIAN
strip -g `find $installdir/$packagename/usr/bin/ -type f -executable`
strip -g `find $installdir/$packagename/usr/lib/ -type f -executable -name '*.so*'`
cat >$installdir/$packagename/DEBIAN/control <<FINISH
Package: mythtv-light
Version: $packagever
Section: graphics
Priority: optional
Architecture: $arch
Essential: no
Installed-Size: `du -B1024 -d0 $installdir/$packagename | cut  -f1`
Maintainer: Peter Bennett <pgbennett@comcast.net>
Depends: libavahi-compat-libdnssd1, libqt5widgets5, libqt5script5, libqt5sql5-mysql, libqt5xml5, libqt5network5, libqt5webkit5, libexiv2-13 | libexiv2-14, pciutils, libva-x11-1, libva-glx1, libqt5opengl5, libdbi-perl,  libdbd-mysql-perl, libnet-upnp-perl, python-lxml, python-mysqldb
Conflicts: mythtv-common, mythtv-frontend, mythtv-backend
Homepage: http://www.mythtv.org
Description: MythTV Light
 Lightweight package that installs MythTV in one package, front end
 and backend. Does not install database or services.
FINISH

if [[ "$arch" == armhf && "$codename" == xenial ]] ; then
    environ="env LD_LIBRARY_PATH=/usr/lib/arm-linux-gnueabihf/mesa-egl "
else
    environ=
fi

mkdir -p $installdir/$packagename/usr/share/applications/
sed -e "s~@env@~$environ~" < $scriptpath/lightpackage/mythtv.desktop > $installdir/$packagename/usr/share/applications/mythtv.desktop
sed -e "s~@env@~$environ~" < $scriptpath/lightpackage/mythtv-setup.desktop > $installdir/$packagename/usr/share/applications/mythtv-setup.desktop

mkdir -p $installdir/$packagename/usr/share/pixmaps/
cp -f $scriptpath/lightpackage/mythtv.png $installdir/$packagename/usr/share/pixmaps/

mkdir -p $installdir/$packagename/usr/share/menu/
sed -e "s~@env@~$environ~" < $scriptpath/lightpackage/mythtv-frontend > $installdir/$packagename/usr/share/menu/mythtv-frontend

cd $installdir
fakeroot dpkg-deb --build $packagename
rm -rf $packagename
echo $PWD
ls -ld ${packagename}*
