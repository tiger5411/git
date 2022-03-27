#!/bin/sh

test_description='"make check-builtins" with introspection'

. ./test-lib.sh

if test -z "$GIT_TEST_MAKE_CHECK_BUILTINS"
then
	skip_all="the '$test_description' tests are run from the top-level 'make check-builtins'"
	test_done
fi

symlink_test_manpath () {
	local doc="$GIT_BUILD_DIR"/Documentation &&
	test_path_exists "$doc"/git-add.1 &&
	test_when_finished "rm -f man1" &&
	ln -s "$doc" man1
}

# Use "git-add" as a guinea pig, and check the basic sanity of the
# output. We *should* be run via "make check-builtins", but can also
# be run after "make man" if GIT_TEST_MAKE_CHECK_BUILTINS is set.
#
# The reason for the "skip_all" even if we have a manual page here is
# that even if we have *a* manual page, we don't know if it's
# out-of-date (i.e. leftover build asset), which "make check-builtins"
# ensures won't be the case.
test_lazy_prereq HAVE_BUILT_DOCS '
	symlink_test_manpath &&
	test_when_finished "rm -f man.txt" &&
	GIT_TEST_MANPATH="$PWD" git add --help >man.txt &&
	grep GIT-ADD man.txt &&
	grep ^SYNOPSIS man.txt
'

is_documented () {
	cat >undocumented <<-\EOF
	add--interactive
	bisect--helper
	checkout--worker
	difftool--helper
	env--helper
	merge-octopus
	merge-ours
	merge-recursive
	merge-recursive-ours
	merge-recursive-theirs
	merge-resolve
	merge-subtree
	pickaxe
	remote-ftp
	remote-ftps
	remote-http
	remote-https
	submodule--helper
	upload-archive--writer
	EOF
	! grep -q "^$1$" undocumented
}

test_undocumented () {
	cmd=$1 &&
	test_expect_success HAVE_BUILT_DOCS "$cmd does not have --help documentation" '
		symlink_test_manpath &&
		test_when_finished "rm -f man.txt" &&
		test_must_fail env GIT_TEST_MANPATH="$PWD" git $cmd --help >man.txt
	'
}

test_documented () {
	cmd=$1 &&
	test_expect_success HAVE_BUILT_DOCS "$cmd can handle --help" '
		symlink_test_manpath &&
		test_when_finished "rm -f man.txt" &&
		GIT_TEST_MANPATH="$PWD" git $cmd --help >man.txt &&
		grep "git-$cmd" man.txt
	'
}

test_expect_success 'generate main list' '
	mkdir -p sub &&
	git --list-cmds=main >main
'

while read cmd
do
	case "$cmd" in
	*.sh|*.perl|*.py)
		    continue
		    ;;
	esac &&
	if is_documented "$cmd"
	then
		test_documented "$cmd"
	else
		test_undocumented "$cmd"
	fi
done <main

test_done
