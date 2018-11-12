#!/bin/sh

test_description="Tests performance of index-pack with loose objects"

. ./perf-lib.sh

test_perf_fresh_repo

test_expect_success 'setup tests' '
	for count in 1 10 100 1000
	do
		if test -d /mnt/ontap_githackers/repo-$count.git
		then
			rm -rf /mnt/ontap_githackers/repo-$count.git/objects/pack
		else
			git init --bare /mnt/ontap_githackers/repo-$count.git &&
			(
				cd /mnt/ontap_githackers/repo-$count.git &&
				for i in $(seq 0 255)
				do
					i=$(printf %02x $i) &&
					mkdir objects/$i &&
					for j in $(seq --format=%038g $count)
					do
						>objects/$i/$j
					done
				done
			)
		fi
	done
'

echo 3 | sudo tee /proc/sys/vm/drop_caches
for count in 1 10 100 1000
do
	test_perf "index-pack with 256*$count loose objects" "
		(
			cd /mnt/ontap_githackers/repo-$count.git &&
			rm -fv objects/pack/*;
			git -c core.checkCollisions=false index-pack -v --stdin </home/aearnfjord/g/sha1collisiondetection/.git/objects/pack/pack-*.pack
		)
	"
done

test_done
