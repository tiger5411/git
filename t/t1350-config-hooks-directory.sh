#!/bin/sh

test_description='Test the core.hooksDirectory configuration variable'

. ./test-lib.sh

test_expect_success 'set up a pre-commit hook in core.hooksDirectory' '
	mkdir -p .git/custom-hooks .git/hooks &&
	cat >.git/custom-hooks/pre-commit <<EOF &&
#!$SHELL_PATH
printf "%s" "." >>.git/PRE-COMMIT-HOOK-WAS-CALLED
EOF
	cat >.git/hooks/pre-commit <<EOF &&
	chmod +x .git/hooks/pre-commit
#!$SHELL_PATH
printf "%s" "SHOULD NOT BE CALLED" >>.git/PRE-COMMIT-HOOK-WAS-CALLED
EOF
	chmod +x .git/custom-hooks/pre-commit
'

test_expect_success 'Check that various forms of specifying core.hooksDirectory work' '
	test_commit no_custom_hook &&
	git config core.hooksDirectory .git/custom-hooks &&
	test_commit have_custom_hook &&
	git config core.hooksDirectory .git/custom-hooks/ &&
	test_commit have_custom_hook_trailing_slash &&
	git config core.hooksDirectory "$PWD/.git/custom-hooks" &&
	test_commit have_custom_hook_abs_path &&
	git config core.hooksDirectory "$PWD/.git/custom-hooks/" &&
	test_commit have_custom_hook_abs_path_trailing_slash &&
    printf "%s" "...." >.git/PRE-COMMIT-HOOK-WAS-CALLED.expect &&
    test_cmp .git/PRE-COMMIT-HOOK-WAS-CALLED.expect .git/PRE-COMMIT-HOOK-WAS-CALLED
'

test_done
