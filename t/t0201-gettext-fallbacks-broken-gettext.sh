#!/bin/sh
#
# Copyright (c) 2012 Ævar Arnfjörð Bjarmason
#

test_description='Gettext Shell fallbacks with broken gettext'

. ./test-lib.sh

test_expect_success 'set up a fake broken gettext(1)' '
	cat >gettext <<-\EOF &&
	#!/bin/sh
	exit 1
	EOF
	chmod +x gettext &&
    ! ./gettext
'

PATH=.:$PATH
. "$TEST_DIRECTORY"/lib-gettext.sh

test_expect_success C_LOCALE_OUTPUT '$GIT_INTERNAL_GETTEXT_SH_SCHEME" is fallthrough with broken gettext(1)' '
    echo fallthrough >expect &&
    echo $GIT_INTERNAL_GETTEXT_SH_SCHEME >actual &&
    test_cmp expect actual
'

test_done
