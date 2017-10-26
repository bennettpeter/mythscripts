#!/bin/bash
if git status --porcelain | grep "^A" ; then
    echo "Cannot do this - there are files in cache" >&2
    echo "Use git reset to clear them" >&2
    exit 2
fi
Tall=.
. $HOME/.buildrc
gitbasedir=`git rev-parse --show-toplevel`

sel="$1"
build=n
if [[ "$sel" == build ]] ; then
    build=y
    sel=all
fi
    
eval files="$(echo '$'T$sel)"
if [[ "$files" == "" ]] ; then
    echo Required: all curr or ticket number >&2
    echo $Tlist >&2
    exit 2
fi

shift
git status >&2
echo Files to diff: >&2
echo "$files" >&2
(cd "$gitbasedir"; git add $files >&2)
if [[ "$?" != 0 ]] ; then exit 2 ; fi
git diff --cached --check >&2
rc=$?
if [[ "$rc" != 0 ]] ; then
    echo ERROR - type Y to ignore the error. >&2
    read xxxx
    if [[ "$xxxx" == Y ]] ; then
        rc=0
    fi
fi
if [[ "$rc" == 0 ]] ; then
    git status >&2
    if [[ "$build" == n ]] ; then
        echo enter to continue >&2; read xxxx
    fi    
    git diff --cached "$@"
    rc=$?
    if [[ -t 1 ]] ; then rc=0 ; fi
fi
if [[ "$rc" != 0 ]] ; then
    echo ERROR ERROR ERROR ERROR ERROR >&2
fi
git reset >/dev/null
exit $rc
