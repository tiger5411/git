#!/bin/sh

test_description='the git-annex test suite'
. ./test-lib.sh

if test -z "$EXTERNAL_TESTS"
then
	skip_all='skipping tests of external tools. EXTERNAL_TESTS not defined'
	test_done
fi

if test -n "$NO_CURL"
then
	skip_all='skipping test, git built without http support'
	test_done
fi

test_expect_success 'clone git-annex' '
	git clone https://git.joeyh.name/git/git-annex.git
'

if test -n "$GIT_TEST_GIT_ANNEX_REVISION"
then
	test_expect_success "plan to test git-annex $GIT_TEST_GIT_ANNEX_REVISION" "
		echo '$GIT_TEST_GIT_ANNEX_REVISION' >revision-to-test
	"
else
	test_expect_success "plan to test git-annex's latest release tag" '
		git -C git-annex tag --sort=version:refname -l "[0-9]*.[0-9]*" |
			tail -n 1 >revision-to-test
	'
fi

test_expect_success 'checkout $(cat revision-to-test) for testing' '
	git -C git-annex checkout $(cat revision-to-test)
'

test_expect_success 'build git-annex (if this fails, you are likely missing its Haskell dependencies' '
	(
		cd git-annex &&
		make
	)
'

test_expect_success 'test git-annex' '
	(
		cd git-annex &&
		make test
	)
'

test_done
