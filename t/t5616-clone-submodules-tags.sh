#!/bin/sh

test_description='Test cloning of repos with submodules & the --[no-]tags option'

. ./test-lib.sh

pwd=$(pwd)

test_expect_success 'setup' '
	git checkout -b master &&
	test_commit commit1 &&
	test_commit commit2 &&
	mkdir sub &&
	(
		cd sub &&
		git init &&
		test_commit subcommit1 &&
		test_commit subcommit2 &&
		test_commit subcommit3
	) &&
	git submodule add "file://$pwd/sub" sub &&
	git commit -m "add submodule" &&
	git tag addsubcommit1
'

test_expect_success 'tags clone implies tags submodule' '
	test_when_finished "rm -rf super_clone" &&
	git clone --recurse-submodules "file://$pwd/." super_clone &&
	git -C super_clone for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags &&
	git -C super_clone/sub for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags
'

test_expect_success 'no-tags clone with no-tags submodule' '
	test_when_finished "rm -rf super_clone" &&
	git clone --recurse-submodules --no-tags --no-tags-submodules "file://$pwd/." super_clone &&
	git -C super_clone for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 0 tags &&
	git -C super_clone/sub for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 0 tags

'

test_expect_success 'no-tags clone does not imply no-tags submodule' '
	test_when_finished "rm -rf super_clone" &&
	git clone --recurse-submodules --no-tags "file://$pwd/." super_clone &&
	git -C super_clone for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 0 tags &&
	git -C super_clone/sub for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags
'

test_expect_success 'no-tags clone with tags submodule' '
	test_when_finished "rm -rf super_clone" &&
	git clone --recurse-submodules --no-tags --tags-submodules "file://$pwd/." super_clone &&
	git -C super_clone for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 0 tags &&
	git -C super_clone/sub for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags
'

test_expect_success 'tags clone with no-tags submodule' '
	test_when_finished "rm -rf super_clone" &&
	git clone --recurse-submodules --tags --no-tags-submodules "file://$pwd/." super_clone &&
	git -C super_clone for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags &&
	git -C super_clone/sub for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 0 tags
'

test_expect_success 'clone follows tags=false recommendation' '
	test_when_finished "rm -rf super_clone" &&
	git config -f .gitmodules submodule.sub.tags false &&
	git add .gitmodules &&
	git commit -m "recommed no-nags for sub" &&
	git clone --recurse-submodules --no-local "file://$pwd/." super_clone &&
	git -C super_clone for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags &&
	git -C super_clone/sub for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 0 tags
'

test_expect_success 'get tags recommended no-tags submodule' '
	test_when_finished "rm -rf super_clone" &&
	git clone --no-local "file://$pwd/." super_clone &&
	git -C super_clone submodule update --init --no-recommend-tags &&
	git -C super_clone for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags &&
	git -C super_clone/sub for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags
'

test_expect_success 'clone follows tags=true recommendation' '
	test_when_finished "rm -rf super_clone" &&
	git config -f .gitmodules submodule.sub.tags true &&
	git add .gitmodules &&
	git commit -m "recommed tags for sub" &&
	git clone --recurse-submodules --no-local "file://$pwd/." super_clone &&
	git -C super_clone for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags &&
	git -C super_clone/sub for-each-ref --format="%(refname:strip=2)" refs/tags/ >tags &&
	test_line_count = 3 tags
'

test_done
