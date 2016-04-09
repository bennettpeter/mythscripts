#!/bin/bash

# Build programs
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
set -e
export LIRC_VER=0.9.0
export IGUANA_VER=1.0.2

cd $scriptpath

cd firewire_tester
./clean.sh
cd ..

cd scte65scan-0.2.1
make clean || echo error

cd ../stbpower
make clean || echo error
cd ..

cd lirc
./clean.sh
cd ..

