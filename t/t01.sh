#!/bin/bash

die() { echo "$@" >&2; exit 1; }
set -e

export rr=$HOME/gitpod-remote-repos

# clean slate
cd $HOME
rm -rf $rr non-bare r[1234].git sub[1234] u .gitpod.rc

# assumptions: git-test and gitpod are in $PATH
which git-test  >/dev/null || die 'git-test  not in PATH'
which gitpod >/dev/null || die 'gitpod not in PATH'
# check login shell is also the same
[ `/usr/bin/which gitpod` = `grep ^$USER: /etc/passwd | cut -f7 -d:` ] || die login shell is not the right one
# check ssh setup
ssh -o preferredauthentications=publickey $USER@localhost info | grep hello,.this.is.gitpod >/dev/null || die ssh setup not complete

# create the "remote" repositories.  We use file:/// because it doesn't matter

mkdir -p $rr/r{1,2,3,4}
git config --get user.name &>/dev/null || {
    git config --global user.name 'git cephalopod'
    git config --global user.email 'git-cephalopod@example.com'
}

# make 4 "remote" repositories
for r in  r1 r2 r3 r4
do
    cd $rr/$r
    git init --bare &>/dev/null

    cd $HOME
    rm -rf non-bare
    git clone $rr/$r non-bare &>/dev/null
    cd non-bare

    printf "
        $r; m1; m2; branch AA; m3; m4
        checkout AA; a1; a2
        push --all origin
        /new.branch.*AA.*AA/
        /new.branch.*master.*master/
    " | git test
done

cd $HOME
mkdir sub2 sub4

# "clone" the first 2 repos using local commands
gitpod clone file:///$rr/r1 r1 &>/dev/null
gitpod clone file:///$rr/r2 sub2/r2 &>/dev/null

# now setup the other 2 using ssh
ssh $USER@localhost clone file:///$rr/r3 r3 &>/dev/null
ssh $USER@localhost clone file:///$rr/r4 sub4/r4 &>/dev/null

printf "
    git ls-remote r1.git
    /3ba846a/; /fc7a819/
    git ls-remote sub2/r2.git
    /c4c7d55/; /50d9881/

    git ls-remote r3.git
    /b499b19/; /e4cc88d/
    git ls-remote sub4/r4.git
    /af0f123/; /cd3734f/
" | git test

printf "
    sh ssh $USER@localhost info
    /r1/
    /r3/
    /sub2/r2/
    /sub4/r4/
" | git test

# empty fetch
git test "sh ssh $USER@localhost fetch r1; /fetching from/; !/From file/"

# cause a non-empty fetch
git test "cd r1.git; branch -D AA; /Deleted branch AA/; git gc --prune=now"
git test "sh ssh $USER@localhost fetch r1; /fetching from/; /From file/"

# do a userclone
mkdir u
git test "MSG=user clone; git clone $USER@localhost:r1 u/r1; cd u/r1; git ls-remote origin; ok; /3ba846a/; /fc7a819/ "

# test automatic fetch
git test "cd r1.git; branch -D AA; /Deleted branch AA/; git gc --prune=now"
git test "cd u/r1; git fetch; /new.branch.*AA.*AA/ autofetch 1"
# now it shouldn't
git test "cd u/r1; git fetch; !/new.branch.*AA.*AA/ autofetch 2"

# test lazy mode
echo LAZY = all > $HOME/.gitpod.rc

# test automatic fetch fail due to lazy mode
git test "cd r1.git; branch -D AA; /Deleted branch AA/; git gc --prune=now"
git test "cd u/r1; git fetch; !/new.branch.*AA.*AA/ autofetch 3"

# manual fetch via ssh
git test "sh ssh $USER@localhost fetch r1; /new.branch.*AA.*AA/ manual fetch via ssh"

# manual fetch from local shell
git test "cd r1.git; branch -D AA; /Deleted branch AA/; git gc --prune=now"
git test "sh gitpod fetch r1; /new.branch.*AA.*AA/ manual fetch local shell"

echo DONE
