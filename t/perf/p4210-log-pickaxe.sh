#!/bin/sh

test_description="Comparison of git-log's pickaxe -G"

. ./perf-lib.sh

test_perf_default_repo

for pattern in \
	'a.*b.*c' \
	'how.to' \
	'^how to' \
	'[how] to' \
	'\(e.t[^ ]*\|v.ry\) rare' \
	'm\(ú\|u\)lt.b\(æ\|y\)te'
do
	test_perf "log -G'$pattern'" "
		git log --pretty=format:%h -G'$pattern' >'out.G.$engine' || :
	"
done

test_done
