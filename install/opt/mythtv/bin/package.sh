#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

gitbasedir=`git rev-parse --show-toplevel`

# This will get projname and destdir
. "$scriptpath/getdestdir.source"

gitpath="$PWD"

sourcedir=$destdir
subrelease=$1

if [[ "$sourcedir" == "" ]] ; then
    echo Before running this the latest version must be built
    echo with --prefix=/usr --runprefix=/usr and installed
    echo Parameter 1 = subrelease number
    echo Run this from the git source directory
    exit 2
fi
sourcedir=`readlink -f "$sourcedir"`
if [[ "$subrelease" == "" ]] ; then subrelease=0 ; fi
gitver=`git -C "$gitpath" describe --dirty|cut -c2-`
gitbranch=`git branch|grep "^\* "|cut -b3-`
packagever=`env LD_LIBRARY_PATH=$sourcedir/usr/lib $sourcedir/usr/bin/mythutil --version |grep "MythTV Version"|cut -d ' ' -f 4|cut -c2-`
packagebranch=`env LD_LIBRARY_PATH=$sourcedir/usr/lib $sourcedir/usr/bin/mythutil --version |grep "MythTV Branch"|cut -d ' ' -f 4`
echo Package branch: $packagebranch, git branch: $gitbranch
if [[ "$packagever" != "$gitver" ]] ; then
    echo ERROR Package version $packagever does not match git version $gitver
    exit 2
fi
packagever=`echo $packagever|sed  's/-pre/~pre/'`
packagever=`echo $packagever|sed  's/-rc/~rc/'`
packagerel=$packagever-$subrelease
gitbasedir=`git -C "$gitpath" rev-parse --show-toplevel`
installdir=`dirname "$gitbasedir"`
arch=`dpkg-architecture -q DEB_TARGET_ARCH`
codename=`lsb_release -c|cut -f 2`
source=
# This expects that remote tracking branches for official
# repositories start with "mythtv"
if [[ "$packagebranch" != mythtv* && "$packagebranch" != fixes* ]] ; then
    source="test_"
fi
case $projname in
    mythtv)
        packagename=mythtv-light_${source}${packagerel}_${arch}_$codename
        echo Package $packagename
        if [[ -f $installdir/$packagename.deb ]] ; then
            echo $installdir/$packagename.deb already exists - run with a subrelease number
            exit 2
        fi
        rm -rf $installdir/$packagename $installdir/$packagename.deb
        cp -a "$sourcedir/" "$installdir/$packagename/"
        if [[ ! -d $installdir/$packagename/usr/share/doc/mythtv-backend/contrib ]] ; then
            if [[ -d $gitbasedir/mythtv/contrib ]] ; then
                mkdir -p $installdir/$packagename/usr/share/doc/mythtv-backend/contrib
                cp -a $gitbasedir/mythtv/contrib/*  \
                    $installdir/$packagename/usr/share/doc/mythtv-backend/contrib/
            else
                echo ERROR Running from wrong directory, $gitbasedir/mythtv/contrib not found
                exit 2
            fi
        fi
        mkdir -p $installdir/$packagename/DEBIAN
        strip -g `find $installdir/$packagename/usr/bin/ -type f -executable`
        strip -g `find $installdir/$packagename/usr/lib/ -type f -executable -name '*.so*'`
        deps="libtag1v5,"
        if [[ "$arch" == armhf ]] ; then
            deps="libtag1c2a,"
        fi
        cat >$installdir/$packagename/DEBIAN/control <<FINISH
Package: mythtv-light
Version: $packagerel
Section: graphics
Priority: optional
Architecture: $arch
Essential: no
Installed-Size: `du -B1024 -d0 $installdir/$packagename | cut  -f1`
Maintainer: Peter Bennett <pbennett@mythtv.org>
Depends: $deps libavahi-compat-libdnssd1, libqt5widgets5, libqt5script5, libqt5sql5-mysql, libqt5xml5, libqt5network5, libqt5webkit5, libexiv2-13 | libexiv2-14, pciutils, libva-x11-1, libva-glx1, libqt5opengl5, libdbi-perl,  libdbd-mysql-perl, libnet-upnp-perl, python-lxml, python-mysqldb, python-urlgrabber, libcec3, libfftw3-double3, libfftw3-single3, libass5, libfftw3-3, libraw1394-11, libiec61883-0, libavc1394-0, fonts-liberation
Conflicts: mythtv-common, mythtv-frontend, mythtv-backend
Homepage: http://www.mythtv.org
Description: MythTV Light
 Lightweight package that installs MythTV in one package, front end
 and backend. Does not install database or services.
FINISH
        mkdir -p $installdir/$packagename/usr/share/applications/
        cat >$installdir/$packagename/usr/share/applications/mythtv.desktop \
        <<FINISH
[Desktop Entry]
Name=MythTV Frontend
Comment=A frontend for all content on a mythtv-backend
GenericName=MythTV Viewer
Exec=/usr/bin/mythfrontend --logpath /tmp
Type=Application
Encoding=UTF-8
Icon=/usr/share/pixmaps/mythtv.png
Categories=GNOME;Application;AudioVideo;Audio;Video
FINISH
        cat >$installdir/$packagename/usr/share/applications/mythtv-setup.desktop \
        <<FINISH
[Desktop Entry]
Name=MythTV Backend Setup
Comment=Used to configure a backend
GenericName=mythtv-setup
Exec=@env@/usr/bin/mythtv-setup --logpath /tmp
Type=Application
Encoding=UTF-8
Icon=/usr/share/pixmaps/mythtv.png
Categories=GTK;System;Settings
X-AppInstall-Package=mythtv
FINISH
        mkdir -p $installdir/$packagename/usr/share/pixmaps/
        cp -f $scriptpath/mythtv.png $installdir/$packagename/usr/share/pixmaps/

        mkdir -p $installdir/$packagename/usr/share/menu/
        cat >$installdir/$packagename/usr/share/menu/mythtv-frontend \
        <<FINISH
?package(mythtv-frontend):needs="X11" section="Applications/Graphics" \
  title="MythTV" command="/usr/bin/mythfrontend"
FINISH

        cd $installdir
        chmod -R  g-w,o-w $packagename
        fakeroot dpkg-deb --build $packagename
        # Do not rm $packagename because it is needed for plugins build
        echo $PWD
        ls -ld ${packagename}*
        ;;
    mythplugins)
        mythtvpackagename=mythtv-light_${source}${packagerel}_${arch}_$codename
        packagename=mythplugins-light_${source}${packagerel}_${arch}_$codename
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
Version: $packagerel
Section: graphics
Priority: optional
Architecture: $arch
Essential: no
Installed-Size: `du -B1024 -d0 $installdir/$packagename | cut  -f1`
Maintainer: Peter Bennett <pbennett@mythtv.org>
Depends: mythtv-light, python, perl, libimage-size-perl, perlmagick, libxml-parser-perl, libxml-sax-perl, libcarp-clan-perl, libsoap-lite-perl, libdate-manip-perl, libdate-calc-perl, libwww-perl, libxml-simple-perl, libdatetime-format-iso8601-perl, libjson-perl, libxml-xpath-perl, mjpegtools, dvdauthor, genisoimage, dvd+rw-tools, python, python-imaging, python-mysqldb, pmount, python-feedparser, python-pycurl
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
        chmod -R  g-w,o-w $packagename
        fakeroot dpkg-deb --build $packagename

        echo $PWD
        ls -ld ${packagename}*
        ;;
esac