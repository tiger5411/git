#!/bin/sh

test_description="Tests performance of index-pack with loose objects"

. ./perf-lib.sh

test_perf_fresh_repo

test_expect_success 'setup tests' '
	for count in 1 10
	do
		rm -rf /mnt/ontap_githackers/repo-$count.git &&
		git init --bare /mnt/ontap_githackers/repo-$count.git &&
		(
			cd /mnt/ontap_githackers/repo-$count.git &&
			for i in $(seq 256); do
				i=$(printf %02x $i) &&
				mkdir objects/$i &&
				for j in $(seq --format=%038g $count)
				do
					>objects/$i/$j
				done
			done
		)
	done
'

for count in 1 10
do
	test_perf "index-pack with 256*$count loose objects" "
		(
			cd /mnt/ontap_githackers/repo-$count.git &&
			git -c core.checkCollisions=false index-pack -v --stdin </home/aearnfjord/g/git/.git/objects/pack/pack-080126d635c9749fc1ab6049050c51f85c62e2e3.pack
		)
	"
done
'

test_done
