#!/bin/bash
# Prepare source for build
set -e
rc=0
gitbasedir=`git rev-parse --show-toplevel`
mkdir -p $gitbasedir/../patch/ 2>/dev/null || true
if [[ `arch` == arm* ]] ; then
    mount /srv/ahome || true
    git checkout $gitbasedir
    git clean -f
    if [[ -s $gitbasedir/../patch/build.patch ]] ; then
        git apply -v $gitbasedir/../patch/build.patch
    fi
else
    gitdiff.sh build > $gitbasedir/../patch/build.patch || rc=$?
#    for file in $gitbasedir/../patch/Peter/*.patch ; do
#        echo git apply -v $file
#        git apply -v $file
#    done
    if [[ "$rc" != 0 ]] ; then
        echo ERROR - type Y to ignore the error. >&2
        read xxxx
        if [[ "$xxxx" == Y ]] ; then
            rc=0
        fi
    fi
fi
exit $rc
