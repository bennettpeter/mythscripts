#!/bin/bash
# Prepare source for build
set -e
gitbasedir=`git rev-parse --show-toplevel`
if [[ `arch` == arm* ]] ; then
    mount /srv/ahome || true
    git checkout .
    rm -f $gitbasedir/../testing.patch
    if [[ -f $gitbasedir/../patch/testing.patch ]] ; then
        cp $gitbasedir/../patch/testing.patch $gitbasedir/../
        git apply $gitbasedir/../testing.patch
    fi
else
    git diff > $gitbasedir/../patch/testing.patch
fi
