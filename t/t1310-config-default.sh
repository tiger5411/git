#!/bin/sh

test_description='Test git config in different settings (with --default)'

. ./test-lib.sh

test_expect_success 'uses --default when missing entry' '
	echo quux >expect &&
	git config -f config --default quux core.foo >actual &&
	test_cmp expect actual
'

test_expect_success 'canonicalizes --default with appropriate type' '
	echo true >expect &&
	git config -f config --default=true --bool core.foo >actual &&
	test_cmp expect actual
'

test_expect_success 'uses entry when available' '
	echo bar >expect &&
	git config --add core.foo bar &&
	git config --default baz core.foo >actual &&
	git config --unset core.foo &&
	test_cmp expect actual
'

test_expect_success 'dies when --default cannot be parsed' '
	test_must_fail git config -f config --type=int --default=x --get \
		not.a.section 2>error &&
	test_i18ngrep "invalid unit" error
'

test_expect_success 'does not allow --default without --get' '
	test_must_fail git config --default quux --unset a >output 2>&1 &&
	test_i18ngrep "\-\-default is only applicable to" output
'

test_done
