#!/bin/sh

test_lazy_prereq SUBMODULE_CACHE_SUPERPROJECT_DIR '
	test_bool_env GIT_TEST_SUBMODULE_CACHE_SUPERPROJECT_DIR true
'

test_cmp_submodule_superprojectgitdir () {
	if ! test_have_prereq SUBMODULE_CACHE_SUPERPROJECT_DIR
	then
		return 0
	fi

	git -C "$1" config submodule.superprojectGitDir >actual &&
	test_cmp expect actual
}

test_file_not_empty_superprojectgitdir () {
	if ! test_have_prereq SUBMODULE_CACHE_SUPERPROJECT_DIR
	then
		return 0
	fi

	test_file_not_empty "$(git -C $1 rev-parse --absolute-git-dir)/$2"
}
