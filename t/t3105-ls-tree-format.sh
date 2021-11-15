#!/bin/sh

test_description='ls-tree --format'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'ls-tree --format usage' '
	test_expect_code 129 git ls-tree --format=fmt -l &&
	test_expect_code 129 git ls-tree --format=fmt --name-only &&
	test_expect_code 129 git ls-tree --format=fmt --name-status
'

test_expect_success 'setup' '
	mkdir dir &&
	test_commit dir/sub-file &&
	test_commit top-file
'

test_ls_tree_format () {
	format=$1 &&
	opts=$2 &&
	shift 2 &&
	git ls-tree $opts -r HEAD >expect.raw &&
	sed "s/^/> /" >expect <expect.raw &&
	git ls-tree --format="> $format" -r HEAD >actual &&
	test_cmp expect actual
}

test_expect_success 'ls-tree --format=<default-like>' '
	test_ls_tree_format \
		"%(objectmode) %(objecttype) %(objectname)%x09%(path)" \
		""
'

test_expect_success 'ls-tree --format=<long-like>' '
	test_ls_tree_format \
		"%(objectmode) %(objecttype) %(objectname) %(objectsize:padded)%x09%(path)" \
		"--long"
'

test_expect_success 'ls-tree --format=<name-only-like>' '
	test_ls_tree_format \
		"%(path)" \
		"--name-only"

'

test_done
