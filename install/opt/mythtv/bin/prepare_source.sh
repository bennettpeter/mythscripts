#!/bin/bash
# Prepare source for build
set -e
if [[ `arch` == arm* ]] ; then
    gitbasedir=`git rev-parse --show-toplevel`
    cd "$gitbasedir"
    mount /srv/ahome || true
    rm -f ../testing.patch
    if [[ -f ../../abennettpeter/testing.patch ]] ; then
        cp ../../abennettpeter/testing.patch ../
    fi
    git checkout .
    patch -p1 < ../testing.patch
fi
