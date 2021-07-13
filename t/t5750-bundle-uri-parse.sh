#!/bin/sh

test_description="Test bundle-uri bundle_uri_parse_line()"

TEST_NO_CREATE_REPO=1
TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'bundle_uri_parse_line() just URIs' '
	cat >in <<-\EOF &&
	http://example.com/bundle.bdl
	https://example.com/bundle.bdl
	file:///usr/share/git/bundle.bdl
	EOF

	# For the simple case
	cp in expect &&

	test-tool bundle-uri parse <in >actual 2>err &&
	test_must_be_empty err &&
	test_cmp expect actual
'

test_expect_success 'bundle_uri_parse_line() with attributes' '
	cat >in <<-\EOF &&
	http://example.com/bundle1.bdl attr
	http://example.com/bundle2.bdl ibute
	EOF

	cat >expect <<-\EOF &&
	http://example.com/bundle1.bdl [attr: attr]
	http://example.com/bundle2.bdl [attr: ibute]
	EOF

	test-tool bundle-uri parse <in >actual 2>err &&
	test_must_be_empty err &&
	test_cmp expect actual
'

test_expect_success 'bundle_uri_parse_line() with attributes and key-value attributes' '
	cat >in <<-\EOF &&
	http://example.com/bundle1.bdl x a=b y c=d z e=f a=b
	EOF


	cat >expect <<-\EOF &&
	http://example.com/bundle1.bdl [attr: x] [kv: a => b] [attr: y] [kv: c => d] [attr: z] [kv: e => f] [kv: a => b]
	EOF

	test-tool bundle-uri parse <in >actual 2>err &&
	test_must_be_empty err &&
	test_cmp expect actual
'

test_expect_success 'bundle_uri_parse_line() parsing edge cases: extra SP' '
	cat >in <<-\EOF &&
	http://example.com/bundle1.bdl one-space
	http://example.com/bundle2.bdl  two-space
	http://example.com/bundle3.bdl   three-space
	EOF

	cat >err.expect <<-\EOF &&
	error: bundle-uri: column 1: got an empty attribute (full line was '\''http://example.com/bundle2.bdl  two-space'\'')
	error: bad line: '\''http://example.com/bundle2.bdl  two-space'\''
	error: bundle-uri: column 1: got an empty attribute (full line was '\''http://example.com/bundle3.bdl   three-space'\'')
	error: bad line: '\''http://example.com/bundle3.bdl   three-space'\''
	EOF

	cat >expect <<-\EOF &&
	http://example.com/bundle1.bdl [attr: one-space]
	EOF

	test_must_fail test-tool bundle-uri parse <in >actual 2>err.actual &&
	test_cmp err.expect err.actual &&
	test_cmp expect actual
'

test_expect_success 'bundle_uri_parse_line() parsing edge cases: empty lines' '
	cat >in <<-\EOF &&
	http://example.com/bundle1.bdl

	http://example.com/bundle2.bdl a=b

	http://example.com/bundle3.bdl
	EOF

	cat >err.expect <<-\EOF &&
	error: bundle-uri: got an empty line
	error: bad line: '\'''\''
	error: bundle-uri: got an empty line
	error: bad line: '\'''\''
	EOF

	# We fail, but try to continue parsing regardless
	cat >expect <<-\EOF &&
	http://example.com/bundle1.bdl
	http://example.com/bundle2.bdl [kv: a => b]
	http://example.com/bundle3.bdl
	EOF

	test_must_fail test-tool bundle-uri parse <in >actual 2>err.actual &&
	test_cmp err.expect err.actual &&
	test_cmp expect actual
'

test_expect_success 'bundle_uri_parse_line() parsing edge cases: empty URIs' '
	sed "s/> //" >in <<-\EOF &&
	http://example.com/bundle1.bdl
	>  a=b
	http://example.com/bundle3.bdl a=b
	EOF

	cat >err.expect <<-\EOF &&
	error: bundle-uri: got an empty URI component
	error: bad line: '\'' a=b'\''
	EOF

	# We fail, but try to continue parsing regardless
	cat >expect <<-\EOF &&
	http://example.com/bundle1.bdl
	http://example.com/bundle3.bdl [kv: a => b]
	EOF

	test_must_fail test-tool bundle-uri parse <in >actual 2>err.actual &&
	test_cmp err.expect err.actual &&
	test_cmp expect actual
'

test_expect_success 'bundle_uri_parse_line() parsing edge cases: multiple = in key-values' '
	cat >in <<-\EOF &&
	http://example.com/bundle1.bdl k=v=extra
	http://example.com/bundle2.bdl a=b k=v=extra c=d
	http://example.com/bundle3.bdl kv=ok
	EOF

	cat >err.expect <<-\EOF &&
	error: bundle-uri: column 1: '\''k=v=extra'\'' more than one '\''='\'' character (full line was '\''http://example.com/bundle1.bdl k=v=extra'\'')
	error: bad line: '\''http://example.com/bundle1.bdl k=v=extra'\''
	error: bundle-uri: column 2: '\''k=v=extra'\'' more than one '\''='\'' character (full line was '\''http://example.com/bundle2.bdl a=b k=v=extra c=d'\'')
	error: bad line: '\''http://example.com/bundle2.bdl a=b k=v=extra c=d'\''
	EOF

	# We fail, but try to continue parsing regardless
	cat >expect <<-\EOF &&
	http://example.com/bundle3.bdl [kv: kv => ok]
	EOF

	test_must_fail test-tool bundle-uri parse <in >actual 2>err.actual &&
	test_cmp err.expect err.actual &&
	test_cmp expect actual
'

test_done
