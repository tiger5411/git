#!/bin/sh

test_description='ls-tree --format'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'ls-tree --format usage' '
	test_expect_code 129 git ls-tree --format=fmt -l HEAD &&
	test_expect_code 129 git ls-tree --format=fmt --name-only HEAD &&
	test_expect_code 129 git ls-tree --format=fmt --name-status HEAD
'

test_expect_success 'setup' '
	mkdir dir &&
	test_commit dir/sub-file &&
	test_commit top-file
'

test_ls_tree_format () {
	format=$1 &&
	opts=$2 &&
	fmtopts=$3 &&
	shift 2 &&

	cat >expect &&
	cat <&6 >expect.-d &&
	cat <&7 >expect.-r &&
	cat <&8 >expect.-t &&

	for opt in '' '-d' '-r' '-t'
	do
		test_expect_success "'ls-tree $opts${opt:+ $opt}' output" '
			git ls-tree ${opt:+$opt }$opts $opt HEAD >actual &&
			test_cmp expect${opt:+.$opt} actual
		'
	done

	test_expect_success "ls-tree '--format=<$format>' is like options '$opts $fmtopts'" '
		git ls-tree $opts -r HEAD >expect &&
		git ls-tree --format="$format" -r $fmtopts HEAD >actual &&
		test_cmp expect actual
	'

	test_expect_success "ls-tree '--format=<$format>' on optimized v.s. non-optimized path" '
		git ls-tree --format="$format" -r $fmtopts HEAD >expect &&
		git ls-tree --format="> $format" -r $fmtopts HEAD >actual.raw &&
		sed "s/^> //" >actual <actual.raw &&
		test_cmp expect actual
	'
}

test_ls_tree_format \
	"%(objectmode) %(objecttype) %(objectname)%x09%(path)" \
	"" \
	<<-OUT 6<<-OUT_D 7<<-OUT_R 8<<-OUT_T
	040000 tree $(git rev-parse HEAD:dir)	dir
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT
	040000 tree $(git rev-parse HEAD:dir)	dir
	OUT_D
	100644 blob $(git rev-parse HEAD:dir/sub-file.t)	dir/sub-file.t
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT_R
	040000 tree $(git rev-parse HEAD:dir)	dir
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT_T

test_ls_tree_format \
	"%(objectmode) %(objecttype) %(objectname) %(objectsize:padded)%x09%(path)" \
	"--long" \
	<<-OUT 6<<-OUT_D 7<<-OUT_R 8<<-OUT_T
	040000 tree $(git rev-parse HEAD:dir)       -	dir
	100644 blob $(git rev-parse HEAD:top-file.t)       9	top-file.t
	OUT
	040000 tree $(git rev-parse HEAD:dir)       -	dir
	OUT_D
	100644 blob $(git rev-parse HEAD:dir/sub-file.t)      13	dir/sub-file.t
	100644 blob $(git rev-parse HEAD:top-file.t)       9	top-file.t
	OUT_R
	040000 tree $(git rev-parse HEAD:dir)       -	dir
	100644 blob $(git rev-parse HEAD:top-file.t)       9	top-file.t
	OUT_T

test_ls_tree_format \
	"%(path)" \
	"--name-only" \
	<<-OUT 6<<-OUT_D 7<<-OUT_R 8<<-OUT_T
	dir
	top-file.t
	OUT
	dir
	OUT_D
	dir/sub-file.t
	top-file.t
	OUT_R
	dir
	top-file.t
	OUT_T

test_ls_tree_format \
	"%(objectname)" \
	"--object-only" \
	<<-OUT 6<<-OUT_D 7<<-OUT_R 8<<-OUT_T
	$(git rev-parse HEAD:dir)
	$(git rev-parse HEAD:top-file.t)
	OUT
	$(git rev-parse HEAD:dir)
	OUT_D
	$(git rev-parse HEAD:dir/sub-file.t)
	$(git rev-parse HEAD:top-file.t)
	OUT_R
	$(git rev-parse HEAD:dir)
	$(git rev-parse HEAD:top-file.t)
	OUT_T

test_ls_tree_format \
	"%(objectname)" \
	"--object-only --abbrev" \
	"--abbrev" \
	<<-OUT 6<<-OUT_D 7<<-OUT_R 8<<-OUT_T
	$(git rev-parse HEAD:dir | test_copy_bytes 7)
	$(git rev-parse HEAD:top-file.t| test_copy_bytes 7)
	OUT
	$(git rev-parse HEAD:dir | test_copy_bytes 7)
	OUT_D
	$(git rev-parse HEAD:dir/sub-file.t | test_copy_bytes 7)
	$(git rev-parse HEAD:top-file.t | test_copy_bytes 7)
	OUT_R
	$(git rev-parse HEAD:dir | test_copy_bytes 7)
	$(git rev-parse HEAD:top-file.t | test_copy_bytes 7)
	OUT_T

test_ls_tree_format \
	"%(objectmode) %(objecttype) %(objectname)%x09%(path)" \
	"-t" \
	"-t" \
	<<-OUT 6<<-OUT_D 7<<-OUT_R 8<<-OUT_T
	040000 tree $(git rev-parse HEAD:dir)	dir
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT
	040000 tree $(git rev-parse HEAD:dir)	dir
	OUT_D
	040000 tree $(git rev-parse HEAD:dir)	dir
	100644 blob $(git rev-parse HEAD:dir/sub-file.t)	dir/sub-file.t
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT_R
	040000 tree $(git rev-parse HEAD:dir)	dir
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT_T

test_ls_tree_format \
	"%(objectmode) %(objecttype) %(objectname)%x09%(path)" \
	"--full-name" \
	"--full-name" \
	<<-OUT 6<<-OUT_D 7<<-OUT_R 8<<-OUT_T
	040000 tree $(git rev-parse HEAD:dir)	dir
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT
	040000 tree $(git rev-parse HEAD:dir)	dir
	OUT_D
	100644 blob $(git rev-parse HEAD:dir/sub-file.t)	dir/sub-file.t
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT_R
	040000 tree $(git rev-parse HEAD:dir)	dir
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT_T

test_ls_tree_format \
	"%(objectmode) %(objecttype) %(objectname)%x09%(path)" \
	"--full-tree" \
	"--full-tree" \
	<<-OUT 6<<-OUT_D 7<<-OUT_R 8<<-OUT_T
	040000 tree $(git rev-parse HEAD:dir)	dir
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT
	040000 tree $(git rev-parse HEAD:dir)	dir
	OUT_D
	100644 blob $(git rev-parse HEAD:dir/sub-file.t)	dir/sub-file.t
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT_R
	040000 tree $(git rev-parse HEAD:dir)	dir
	100644 blob $(git rev-parse HEAD:top-file.t)	top-file.t
	OUT_T

test_done
