#!/bin/bash
# Prepare source for build
set -e
rc=0
gitbasedir=`git rev-parse --show-toplevel`
if [[ `arch` == arm* ]] ; then
    mount /srv/ahome || true
    git checkout $gitbasedir
    git clean -f
    rm -f $gitbasedir/../testing.patch
    if [[ -s $gitbasedir/../patch/testing.patch ]] ; then
        cp $gitbasedir/../patch/testing.patch $gitbasedir/../
        git apply -v $gitbasedir/../testing.patch
    fi
else
    gitdiff.sh build > $gitbasedir/../patch/testing.patch || rc=$?
    if [[ "$rc" != 0 ]] ; then
        echo ERROR - type Y to ignore the error. >&2
        read xxxx
        if [[ "$xxxx" == Y ]] ; then
            rc=0
        fi
    fi
fi
exit $rc
