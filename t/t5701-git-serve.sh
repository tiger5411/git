#!/bin/sh

test_description='test protocol v2 server commands'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

GIT_TEST_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'test capability advertisement' '
	test_oid_cache <<-EOF &&
	wrong_algo sha1:sha256
	wrong_algo sha256:sha1
	EOF
	cat >expect.base <<-EOF &&
	version 2
	agent=git/$(git version | cut -d" " -f3)
	ls-refs=unborn
	fetch=shallow wait-for-done
	server-option
	object-format=$(test_oid algo)
	object-info
	EOF
	cat >expect.trailer <<-EOF &&
	0000
	EOF
	cat expect.base expect.trailer >expect &&

	GIT_TEST_SIDEBAND_ALL=0 test-tool serve-v2 \
		--advertise-capabilities >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'test capability advertisement with uploadpack.packfileURI' '
	test_config uploadpack.blobPackfileUri FAKE &&

	sed "s/\\(fetch=shallow.*\\)/\\1 packfile-uris/" <expect >expect.packfileURI &&

	GIT_TEST_SIDEBAND_ALL=0 test-tool serve-v2 \
		--advertise-capabilities >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect.packfileURI actual
'

test_expect_success 'test capability advertisement with uploadpack.bundleURI' '
	test_config uploadpack.bundleURI FAKE &&

	cat >expect.extra <<-EOF &&
	bundle-uri
	EOF
	cat expect.base \
	    expect.extra \
	    expect.trailer >expect &&

	GIT_TEST_SIDEBAND_ALL=0 test-tool serve-v2 \
		--advertise-capabilities >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'stateless-rpc flag does not list capabilities' '
	# Empty request
	test-tool pkt-line pack >in <<-EOF &&
	0000
	EOF
	test-tool serve-v2 --stateless-rpc >out <in &&
	test_must_be_empty out &&

	# EOF
	test-tool serve-v2 --stateless-rpc >out &&
	test_must_be_empty out
'

test_expect_success 'request invalid capability' '
	test-tool pkt-line pack >in <<-EOF &&
	foobar
	0000
	EOF

	cat >expect <<-\EOF &&
	ERR serve: unknown capability '"'"'foobar'"'"'
	EOF

	test_must_fail test-tool serve-v2 --stateless-rpc <in >out 2>err &&
	test-tool pkt-line unpack <out >actual &&

	test_must_be_empty err &&
	test_cmp expect actual
'

test_expect_success 'request with no command' '
	test-tool pkt-line pack >in <<-EOF &&
	agent=git/test
	object-format=$(test_oid algo)
	0000
	EOF

	cat >expect <<-\EOF &&
	ERR serve: no command requested
	EOF

	test_must_fail test-tool serve-v2 --stateless-rpc <in >out 2>err &&
	test-tool pkt-line unpack <out >actual &&

	test_must_be_empty err &&
	test_cmp expect actual
'

test_expect_success 'request invalid command' '
	test-tool pkt-line pack >in <<-EOF &&
	command=foo
	object-format=$(test_oid algo)
	agent=git/test
	0000
	EOF

	cat >expect <<-\EOF &&
	ERR serve: invalid command '"'"'foo'"'"'
	EOF

	test_must_fail test-tool serve-v2 --stateless-rpc <in >out 2>err &&
	test-tool pkt-line unpack <out >actual &&

	test_must_be_empty err &&
	test_cmp expect actual
'

test_expect_success 'request more than one command' '
	test-tool pkt-line pack >in <<-EOF &&
	command=ls-refs
	command=fetch
	object-format=$(test_oid algo)
	agent=git/test
	0000
	EOF

	cat >expect <<-\EOF &&
	ERR serve: command '"'"'fetch'"'"' requested after already requesting command '"'"'ls-refs'"'"'
	EOF

	test_must_fail test-tool serve-v2 --stateless-rpc <in >out 2>err &&
	test-tool pkt-line unpack <out >actual &&

	test_must_be_empty err &&
	test_cmp expect actual
'

# Test the basics of fetch
#
test_expect_success 'wrong object-format' '
	test-tool pkt-line pack >in <<-EOF &&
	command=fetch
	agent=git/test
	object-format=$(test_oid wrong_algo)
	0000
	EOF

	cat >expect <<-EOF &&
	ERR serve: mismatched object format: server '"'"'$(test_oid algo)'"'"'; client '"'"'$(test_oid wrong_algo)'"'"'
	EOF

	test_must_fail test-tool serve-v2 --stateless-rpc <in >out 2>err &&
	test-tool pkt-line unpack <out >actual &&

	test_must_be_empty err &&
	test_cmp expect actual
'

test_expect_success 'fetch with unknown features' '
	test-tool pkt-line pack >in <<-EOF &&
	command=fetch
	object-format=$(test_oid algo)
	0001
	we-do-not
	know-about=this
	0000
	EOF

	cat >expect <<-EOF &&
	ERR fetch: unexpected argument: '"'"'we-do-not'"'"'
	EOF

	test_must_fail test-tool serve-v2 --stateless-rpc <in >out 2>err &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual &&
	test_must_be_empty err
'

# Test the basics of ls-refs
#
test_expect_success 'setup some refs and tags' '
	test_commit one &&
	git branch dev main &&
	test_commit two &&
	git symbolic-ref refs/heads/release refs/heads/main &&
	git tag -a -m "annotated tag" annotated-tag
'

test_expect_success 'basics of ls-refs' '
	test-tool pkt-line pack >in <<-EOF &&
	command=ls-refs
	object-format=$(test_oid algo)
	0000
	EOF

	cat >expect <<-EOF &&
	$(git rev-parse HEAD) HEAD
	$(git rev-parse refs/heads/dev) refs/heads/dev
	$(git rev-parse refs/heads/main) refs/heads/main
	$(git rev-parse refs/heads/release) refs/heads/release
	$(git rev-parse refs/tags/annotated-tag) refs/tags/annotated-tag
	$(git rev-parse refs/tags/one) refs/tags/one
	$(git rev-parse refs/tags/two) refs/tags/two
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'basic ref-prefixes' '
	test-tool pkt-line pack >in <<-EOF &&
	command=ls-refs
	object-format=$(test_oid algo)
	0001
	ref-prefix refs/heads/main
	ref-prefix refs/tags/one
	0000
	EOF

	cat >expect <<-EOF &&
	$(git rev-parse refs/heads/main) refs/heads/main
	$(git rev-parse refs/tags/one) refs/tags/one
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'refs/heads prefix' '
	test-tool pkt-line pack >in <<-EOF &&
	command=ls-refs
	object-format=$(test_oid algo)
	0001
	ref-prefix refs/heads/
	0000
	EOF

	cat >expect <<-EOF &&
	$(git rev-parse refs/heads/dev) refs/heads/dev
	$(git rev-parse refs/heads/main) refs/heads/main
	$(git rev-parse refs/heads/release) refs/heads/release
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'peel parameter' '
	test-tool pkt-line pack >in <<-EOF &&
	command=ls-refs
	object-format=$(test_oid algo)
	0001
	peel
	ref-prefix refs/tags/
	0000
	EOF

	cat >expect <<-EOF &&
	$(git rev-parse refs/tags/annotated-tag) refs/tags/annotated-tag peeled:$(git rev-parse refs/tags/annotated-tag^{})
	$(git rev-parse refs/tags/one) refs/tags/one
	$(git rev-parse refs/tags/two) refs/tags/two
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'symrefs parameter' '
	test-tool pkt-line pack >in <<-EOF &&
	command=ls-refs
	object-format=$(test_oid algo)
	0001
	symrefs
	ref-prefix refs/heads/
	0000
	EOF

	cat >expect <<-EOF &&
	$(git rev-parse refs/heads/dev) refs/heads/dev
	$(git rev-parse refs/heads/main) refs/heads/main
	$(git rev-parse refs/heads/release) refs/heads/release symref-target:refs/heads/main
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'sending server-options' '
	test-tool pkt-line pack >in <<-EOF &&
	command=ls-refs
	object-format=$(test_oid algo)
	server-option=hello
	server-option=world
	0001
	ref-prefix HEAD
	0000
	EOF

	cat >expect <<-EOF &&
	$(git rev-parse HEAD) HEAD
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

# Test the basics of object-info
#
test_expect_success !SANITIZE_LEAK 'basics of object-info' '
	test-tool pkt-line pack >in <<-EOF &&
	command=object-info
	object-format=$(test_oid algo)
	0001
	size
	oid $(git rev-parse two:two.t)
	oid $(git rev-parse two:two.t)
	0000
	EOF

	cat >expect <<-EOF &&
	size
	$(git rev-parse two:two.t) $(wc -c <two.t | xargs)
	$(git rev-parse two:two.t) $(wc -c <two.t | xargs)
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'object-info with unknown arguments' '
	test-tool pkt-line pack >in <<-EOF &&
	command=object-info
	object-format=$(test_oid algo)
	0001
	we-do-not
	know-about=this
	0000
	EOF

	cat >expect <<-EOF &&
	ERR object-info: unexpected argument: '"'"'we-do-not'"'"'
	EOF

	test_must_fail test-tool serve-v2 --stateless-rpc <in >out 2>err &&
	test-tool pkt-line unpack <out >actual &&
	test_must_be_empty err &&
	test_cmp expect actual
'

test_expect_success 'basics of bundle-uri: dies if not enabled' '
	test-tool pkt-line pack >in <<-EOF &&
	command=bundle-uri
	0000
	EOF

	cat >expect <<-\EOF &&
	ERR serve: invalid command '"'"'bundle-uri'"'"'
	EOF

	test_must_fail test-tool serve-v2 --stateless-rpc <in >out 2>err &&
	test-tool pkt-line unpack <out >actual &&

	test_must_be_empty err &&
	test_cmp expect actual
'


test_expect_success 'basics of bundle-uri: enabled with single URI' '
	test_config uploadpack.bundleURI https://cdn.example.com/repo.bdl &&

	test-tool pkt-line pack >in <<-EOF &&
	command=bundle-uri
	object-format=$(test_oid algo)
	0000
	EOF

	cat >expect <<-EOF &&
	https://cdn.example.com/repo.bdl
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'basics of bundle-uri: enabled with single URI' '
	test_config uploadpack.bundleURI https://cdn.example.com/repo.bdl &&

	test-tool pkt-line pack >in <<-EOF &&
	command=bundle-uri
	object-format=$(test_oid algo)
	0000
	EOF

	cat >expect <<-EOF &&
	https://cdn.example.com/repo.bdl
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'basics of bundle-uri: enabled with two URIs' '
	test_config uploadpack.bundleURI https://cdn.example.com/repo.bdl &&
	test_config uploadpack.bundleURI https://cdn.example.com/recent.bdl --add &&

	test-tool pkt-line pack >in <<-EOF &&
	command=bundle-uri
	object-format=$(test_oid algo)
	0000
	EOF

	cat >expect <<-EOF &&
	https://cdn.example.com/repo.bdl
	https://cdn.example.com/recent.bdl
	0000
	EOF

	test-tool serve-v2 --stateless-rpc <in >out &&
	test-tool pkt-line unpack <out >actual &&
	test_cmp expect actual
'

test_expect_success 'basics of bundle-uri: unknown future feature(s)' '
	test_config uploadpack.bundleURI https://cdn.example.com/fake.bdl &&

	test-tool pkt-line pack >in <<-EOF &&
	command=bundle-uri
	object-format=$(test_oid algo)
	0001
	some-feature
	we-do-not
	know=about
	0000
	EOF

	cat >expect <<-\EOF &&
	ERR bundle-uri: unexpected argument: '"'"'some-feature'"'"'
	EOF

	test_must_fail test-tool serve-v2 --stateless-rpc <in >out 2>err &&
	test-tool pkt-line unpack <out >actual &&
	test_must_be_empty err &&
	test_cmp expect actual
'

test_done
