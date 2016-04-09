#!/bin/bash

# Build programs
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
set -e
set -x
export LIRC_VER=0.9.0
export IGUANA_VER=1.0.2

cd $scriptpath

. /etc/lsb-release
ARCH=`arch`
ver=${DISTRIB_ID}_${DISTRIB_RELEASE}_${ARCH}

cd firewire_tester
./compile.sh

cd ../scte65scan-0.2.1
make clean || echo error
make

cd ../stbpower
make clean || echo error
make
cd ..

cd lirc
./build.sh
cd ..

mkdir -p install/opt/mythtv/bin/$ver


cp -p firewire_tester/firewire_tester install/opt/mythtv/bin/$ver/
cp -p scte65scan-0.2.1/scte65scan install/opt/mythtv/bin/$ver/
cp -p stbpower/stbpower install/opt/mythtv/bin/$ver/
rm -f install/opt/mythtv/bin/firewire_tester
rm -f install/opt/mythlirc-tv/bin/scte65scan
rm -f install/opt/mythtv/bin/stbpower
echo install/opt/mythtv/bin/$ver
ls -l install/opt/mythtv/bin/$ver

mkdir -p packages/$ver
cp -p lirc/iguanaIR-$IGUANA_VER/packaging/iguanair*.deb packages/$ver/
cp -p lirc/lirc-$LIRC_VER/lirc-mod*.deb packages/$ver/



