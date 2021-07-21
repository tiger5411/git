#!/bin/sh
set -e

gitdir="$1"
url="$2"
bdl="$3"
tip="$4"

curl --output "$bdl" "$url"
#git --git-dir="$gitdir" bundle verify "$bdl"
git --git-dir="$gitdir" bundle unbundle "$bdl" >"$tip"
find "$gitdir" -type f
cut -d ' ' -f 1 <"$tip" >"$tip.tmp"
mv "$tip.tmp" "$tip"
