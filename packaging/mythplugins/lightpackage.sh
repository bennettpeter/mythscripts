#!/bin/bash
set -e
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
#scriptname=`basename "$scriptname" .sh`
gitpath="$PWD"
cd $scriptpath
sourcedir=$1
subrelease=$2
if [[ "$sourcedir" == "" ]] ; then
    echo Before running this the latest version mythtv and plugins 
    echo must be built and mythtv lightpackage must be done.
    echo Parameter 1 = install dir
    echo Parameter 2 = subrelease number
    exit 2
fi
sourcedir=`readlink -f "$sourcedir"`
if [[ "$subrelease" == "" ]] ; then subrelease=0 ; fi
packagever=`git -C "$gitpath" describe --dirty|cut -c2-|sed  's/-pre/~pre/'`-$subrelease
installdir=`git -C "$gitpath" rev-parse --show-toplevel`
installdir=`dirname "$installdir"`
arch=`dpkg-architecture -q DEB_TARGET_ARCH`
codename=`lsb_release -c|cut -f 2`
mythtvpackagename=mythtv-light_${packagever}_${arch}_$codename
packagename=mythplugins-light_${packagever}_${arch}_$codename
echo Package $packagename
if [[ -f $installdir/$packagename.deb ]] ; then
    echo $installdir/$packagename.deb already exists - run with a subrelease number
    exit 2
fi
if [[ ! -d $installdir/$mythtvpackagename ]] ; then
    echo $installdir/$mythtvpackagename does not exist.
    echo Build mythtv package first
    exit 2
fi
rm -rf $installdir/$packagename $installdir/$packagename.deb
cp -a "$sourcedir/" "$installdir/$packagename/"
# Remove mythtv files so that only plugin files remain
cd $installdir/$packagename
(cd $installdir/$mythtvpackagename ; find . \( -type f -o -type l \) -print0) | xargs -0 rm -f
rc=0
while [[ "$rc" == 0 ]] ; do
    find . -type d -empty -print0 | xargs -0 rmdir -v || rc=$?
done
mkdir -p $installdir/$packagename/DEBIAN
strip -g -v `find $installdir/$packagename/usr/bin/ -type f -executable`
strip -g -v `find $installdir/$packagename/usr/lib/ -type f -executable`
cat >$installdir/$packagename/DEBIAN/control <<FINISH
Package: mythplugins-light
Version: $packagever
Section: graphics
Priority: optional
Architecture: $arch
Essential: no
Installed-Size: `du -B1024 -d0 $installdir/$packagename | cut  -f1`
Maintainer: Peter Bennett <pgbennett@comcast.net>
Depends: mythtv-light
Conflicts: mythtv-common, mythtv-frontend, mythtv-backend
Homepage: http://www.mythtv.org
Description: MythTV Plugins Light
 MythTV plugins for the MythTV Light package. MythTV Light must be installed
 before this package. The following plugins are included for Raspberry Pi:
  MythArchive 
  MythBrowser
  MythGame
  MythMusic
  MythNetvision
  MythNews
  MythWeather
  MythZoneMinder
 The MythGallery plugin is not included as it requires OpenGL
FINISH

cd $installdir
fakeroot dpkg-deb --build $packagename
rm -rf $packagename
echo $PWD
ls -ld ${packagename}*
