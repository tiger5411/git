#!/bin/bash

for i in $(seq 50 5000); do
    echo "$i ($(date)):"
    git rev-list origin/master|perl -0777 -nE "srand($i); my @r = sort { rand() <=> rand() } split /\n/, \$_; for (0..8) { say qq[\$r\[\$_\]:\$r\[-\$_\]] }" >/tmp/commit-list
    #cat /tmp/commit-list

    echo ".. doing faster ($(date)):"
    parallel -k -j 8 '
        A=$(echo {} | cut -d: -f1)
        B=$(echo {} | cut -d: -f2)
        ./git tag --contains $A --merged $B
        ./git tag --contains $B --merged $A

        ./git tag --contains $A --no-merged $B
        ./git tag --contains $B --no-merged $A

        ./git tag --contains $A --merged $B --no-merged $A
        ./git tag --contains $A --merged $B --no-merged $B
        ./git tag --contains $A --merged $A --no-merged $A
        ./git tag --contains $A --merged $A --no-merged $B

        ./git tag --contains $B --merged $B --no-merged $A
        ./git tag --contains $B --merged $B --no-merged $B
        ./git tag --contains $B --merged $A --no-merged $A
        ./git tag --contains $B --merged $A --no-merged $B
    ' ::: $(cat /tmp/commit-list) >/tmp/faster

    echo ".. doing slower ($(date)):"
    parallel -k -j 8 '
        A=$(echo {} | cut -d: -f1)
        B=$(echo {} | cut -d: -f2)
        GIT_NO_TAG_ALGO=1 ./git tag --contains $A --merged $B
        GIT_NO_TAG_ALGO=1 ./git tag --contains $B --merged $A

        GIT_NO_TAG_ALGO=1 ./git tag --contains $A --no-merged $B
        GIT_NO_TAG_ALGO=1 ./git tag --contains $B --no-merged $A

        GIT_NO_TAG_ALGO=1 ./git tag --contains $A --merged $B --no-merged $A
        GIT_NO_TAG_ALGO=1 ./git tag --contains $A --merged $B --no-merged $B
        GIT_NO_TAG_ALGO=1 ./git tag --contains $A --merged $A --no-merged $A
        GIT_NO_TAG_ALGO=1 ./git tag --contains $A --merged $A --no-merged $B

        GIT_NO_TAG_ALGO=1 ./git tag --contains $B --merged $B --no-merged $A
        GIT_NO_TAG_ALGO=1 ./git tag --contains $B --merged $B --no-merged $B
        GIT_NO_TAG_ALGO=1 ./git tag --contains $B --merged $A --no-merged $A
        GIT_NO_TAG_ALGO=1 ./git tag --contains $B --merged $A --no-merged $B
    ' ::: $(cat /tmp/commit-list) >/tmp/slower

    diff -ru /tmp/faster /tmp/slower | tee /tmp/diff
    if test -s /tmp/diff
    then
	echo "ZOMG Run $i has diffs" | tee -a /tmp/bad-runs
    fi
done
