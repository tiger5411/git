#!/bin/sh

test_description='git apply with weird postimage filenames'

. ./test-lib.sh

test_expect_success 'setup: empty commit' '
	test_tick &&
	git commit --allow-empty -m preimage &&
	git tag preimage
'

test_expect_success 'setup: clean-up functions' '
	reset_preimage() {
		git checkout -f preimage^0 &&
		git read-tree -u --reset HEAD &&
		git update-index --refresh
	} &&

	reset_subdirs() {
		rm -fr a b &&
		mkdir a b
	}
'

test_expect_success 'setup: test prerequisites' '
	echo one >1 &&
	echo one >2 &&
	if diff -u 1 2
	then
		test_set_prereq UNIDIFF
	fi &&

	if diff -pruN 1 2
	then
		test_set_prereq FULLDIFF
	fi &&

	echo "tab ->  ." >expected &&
	echo "tab ->	." >with-tab &&

	pr -tT -e8 with-tab >actual &&
	if test_cmp expected actual
	then
		test_set_prereq PR
	fi
'

try_filename() {
	desc=$1
	postimage=$2
	exp1=${3:-success}
	exp2=${4:-success}
	exp3=${5:-success}

	test_expect_$exp1 "$desc, git-style file creation patch" "
		reset_preimage &&
		echo postimage >'$postimage' &&
		git add -N '$postimage' &&
		git diff HEAD >'git-$desc.diff' &&

		git rm -f --cached '$postimage' &&
		mv '$postimage' postimage.saved &&
		git apply -v 'git-$desc.diff' &&

		test_cmp postimage.saved '$postimage'
	"

	test_expect_$exp2 UNIDIFF "$desc, traditional patch" "
		reset_preimage &&
		echo preimage >'$postimage.orig' &&
		echo postimage >'$postimage' &&
		! diff -u '$postimage.orig' '$postimage' >'diff-$desc.diff' &&

		mv '$postimage' postimage.saved &&
		mv '$postimage.orig' '$postimage' &&
		git apply -v 'diff-$desc.diff' &&

		test_cmp postimage.saved '$postimage'
	"

	test_expect_$exp3 FULLDIFF "$desc, traditional file creation patch" "
		reset_preimage &&
		reset_subdirs &&
		echo postimage >b/'$postimage' &&
		! diff -pruN a b >'add-$desc.diff' &&

		rm -f '$postimage' &&
		mv b/'$postimage' postimage.saved &&
		git apply -v 'add-$desc.diff' &&

		test_cmp postimage.saved '$postimage'
	"
}

try_filename 'plain'            'postimage.txt'
try_filename 'with spaces'      'post image.txt' success failure failure
try_filename 'with tab'         'post	image.txt' success failure failure
try_filename 'with backslash'   'post\image.txt'
try_filename 'with quote'       '"postimage".txt' success failure success

if test_have_prereq FULLDIFF && test_have_prereq PR
then
	test_set_prereq FULLDIFFPR
fi
test_expect_success FULLDIFFPR 'whitespace-damaged traditional patch' '
	reset_preimage &&
	reset_subdirs &&
	echo postimage >b/postimage.txt &&
	! diff -pruN a b >diff-plain.txt &&
	pr -tT -e8 diff-plain.txt >damaged.diff &&

	mv postimage.txt postimage.saved &&
	git apply -v damaged.diff &&

	test_cmp postimage.saved postimage.txt
'

test_done
