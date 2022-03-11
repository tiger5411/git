# Included from t573*-protocol-v2-bundle-uri-*.sh

T5730_PARENT=
T5730_URI=
T5730_BUNDLE_URI=
case "$T5730_PROTOCOL" in
file)
	T5730_PARENT=file_parent
	T5730_URI="file://$PWD/file_parent"
	T5730_BUNDLE_URI="$T5730_URI/fake.bdl"
	test_set_prereq T5730_FILE
	;;
git)
	. "$TEST_DIRECTORY"/lib-git-daemon.sh
	start_git_daemon --export-all --enable=receive-pack
	T5730_PARENT="$GIT_DAEMON_DOCUMENT_ROOT_PATH/parent"
	T5730_URI="$GIT_DAEMON_URL/parent"
	T5730_BUNDLE_URI="https://example.com/fake.bdl"
	test_set_prereq T5730_GIT
	;;
http)
	. "$TEST_DIRECTORY"/lib-httpd.sh
	start_httpd
	T5730_PARENT="$HTTPD_DOCUMENT_ROOT_PATH/http_parent"
	T5730_URI="$HTTPD_URL/smart/http_parent"
	T5730_BUNDLE_URI="https://example.com/fake.bdl"
	test_set_prereq T5730_HTTP
	;;
*)
	BUG "Need to pass valid T5730_PROTOCOL (was $T5730_PROTOCOL)"
	;;
esac

test_expect_success "setup protocol v2 $T5730_PROTOCOL:// tests" '
	git init "$T5730_PARENT" &&
	test_commit -C "$T5730_PARENT" one
'

# Poor man's URI escaping. Good enough for the test suite whose trash
# directory has a space in it. See 93c3fcbe4d4 (git-svn: attempt to
# mimic SVN 1.7 URL canonicalization, 2012-07-28) for prior art.
test_uri_escape() {
	sed 's/ /%20/g'
}

case "$T5730_PROTOCOL" in
http)
	test_expect_success "setup config for $T5730_PROTOCOL:// tests" '
		git -C "$T5730_PARENT" config http.receivepack true
	'
	;;
*)
	;;
esac
T5730_BUNDLE_URI_ESCAPED=$(echo "$T5730_BUNDLE_URI" | test_uri_escape)

test_expect_success "connect with $T5730_PROTOCOL:// using protocol v2: no bundle-uri" '
	test_when_finished "rm -f log" &&

	GIT_TRACE_PACKET="$PWD/log" \
	git \
		-c protocol.version=2 \
		ls-remote --symref "$T5730_URI" \
		>actual 2>err &&

	# Server responded using protocol v2
	grep "< version 2" log &&

	! grep bundle-uri log
'

test_expect_success "connect with $T5730_PROTOCOL:// using protocol v2: have bundle-uri" '
	test_when_finished "rm -f log" &&

	test_config -C "$T5730_PARENT" \
		uploadpack.bundleURI "$T5730_BUNDLE_URI_ESCAPED" &&

	GIT_TRACE_PACKET="$PWD/log" \
	git \
		-c protocol.version=2 \
		ls-remote --symref "$T5730_URI" \
		>actual 2>err &&

	# Server responded using protocol v2
	grep "< version 2" log &&

	# Server advertised bundle-uri capability
	grep bundle-uri log
'

test_expect_success !T5730_HTTP "bad client with $T5730_PROTOCOL:// using protocol v2" '
	test_when_finished "rm -f log" &&

	test_config -C "$T5730_PARENT" uploadpack.bundleURI \
		"$T5730_BUNDLE_URI_ESCAPED" &&

	cat >err.expect <<-\EOF &&
	Cloning into '"'"'child'"'"'...
	EOF
	case "$T5730_PROTOCOL" in
	file)
		cat >fatal-bundle-uri.expect <<-\EOF
		fatal: bundle-uri: unexpected argument: '"'"'test-bad-client'"'"'
		EOF
		;;
	*)
		cat >fatal.expect <<-\EOF
		fatal: read error: Connection reset by peer
		EOF
		;;
	esac &&

	test_when_finished "rm -rf child" &&
	test_must_fail ok=sigpipe env \
		GIT_TRACE_PACKET="$PWD/log" \
		GIT_TEST_PROTOCOL_BAD_BUNDLE_URI=true \
		git -c protocol.version=2 \
		clone "$T5730_URI" child \
		>out 2>err &&
	test_must_be_empty out &&

	grep -v -e ^fatal: -e ^error: err >err.actual &&
	test_cmp err.expect err.actual &&

	case "$T5730_PROTOCOL" in
	file)
		# Due to general race conditions with client/server replies we
		# may or may not get "fatal: the remote end hung up
		# expectedly" here
		grep "^fatal: bundle-uri:" err >fatal-bundle-uri.actual &&
		test_cmp fatal-bundle-uri.expect fatal-bundle-uri.actual
		;;
	*)
		grep "^fatal:" err >fatal.actual &&
		test_cmp fatal.expect fatal.actual
		;;
	esac &&

	grep "clone> test-bad-client$" log >sent-bad-request &&
	test_file_not_empty sent-bad-request
'

test_expect_success "ls-remote-bundle-uri with $T5730_PROTOCOL:// using protocol v2" '
	test_when_finished "rm -f log" &&

	test_config -C "$T5730_PARENT" uploadpack.bundleURI \
		"$T5730_BUNDLE_URI_ESCAPED" &&

	# All data about bundle URIs
	cat >expect <<-EOF &&
	$T5730_BUNDLE_URI_ESCAPED
	EOF
	GIT_TRACE_PACKET="$PWD/log" \
	git \
		-c protocol.version=2 \
		ls-remote-bundle-uri \
		"$T5730_URI" \
		>actual &&
	test_cmp expect actual &&

	# Only the URIs
	git \
		-c protocol.version=2 \
		ls-remote-bundle-uri --uri \
		"$T5730_URI" \
		>actual2 &&
	test_cmp actual actual2
'

test_expect_success "ls-remote-bundle-uri with $T5730_PROTOCOL:// using protocol v2" '
	test_when_finished "rm -f log" &&

	ATTR="foo bar=baz" &&
	test_config -C "$T5730_PARENT" uploadpack.bundleURI \
		"$T5730_BUNDLE_URI_ESCAPED $ATTR" &&

	# All data about bundle URIs
	cat >expect <<-EOF &&
	$T5730_BUNDLE_URI_ESCAPED $ATTR
	EOF
	GIT_TRACE_PACKET="$PWD/log" \
	git \
		-c protocol.version=2 \
		ls-remote-bundle-uri \
		"$T5730_URI" \
		>actual &&
	test_cmp expect actual
'

test_expect_success "ls-remote-bundle-uri with $T5730_PROTOCOL:// using protocol v2: --uri" '
	test_when_finished "rm -f log" &&

	ATTR="foo bar=baz" &&
	test_config -C "$T5730_PARENT" uploadpack.bundleURI \
		"$T5730_BUNDLE_URI_ESCAPED $ATTR" &&

	# All data about bundle URIs
	cat >expect <<-EOF &&
	$T5730_BUNDLE_URI_ESCAPED
	EOF
	GIT_TRACE_PACKET="$PWD/log" \
	git \
		-c protocol.version=2 \
		ls-remote-bundle-uri \
		--uri \
		"$T5730_URI" \
		>actual &&
	test_cmp expect actual
'

test_expect_success "ls-remote-bundle-uri --[no-]quiet with $T5730_PROTOCOL:// using protocol v2" '
	test_when_finished "rm -f log" &&

	cat >err.expect <<-\EOF &&
	Cloning into '"'"'child'"'"'...
	EOF

	test_when_finished "rm -rf child" &&
	GIT_TRACE_PACKET="$PWD/log" \
	git \
		-c protocol.version=2 \
		 clone "$T5730_URI" child \
		 >out 2>err.actual &&
	test_cmp err.expect err.actual &&
	test_must_be_empty out &&

	test_config -C "$T5730_PARENT" uploadpack.bundleURI \
		"$T5730_BUNDLE_URI_ESCAPED" &&

	# Without --[no-]quiet
	cat >out.expect <<-EOF &&
	$T5730_BUNDLE_URI_ESCAPED
	EOF
	cat >err.expect <<-EOF &&
	From $T5730_URI
	EOF
	git \
		-C child \
		 -c protocol.version=2 \
		ls-remote-bundle-uri \
		>out.actual 2>err.actual &&
	test_cmp err.expect err.actual &&
	test_cmp out.expect out.actual &&

	# --no-quiet is the default
	git \
		-C child \
		-c protocol.version=2 \
		ls-remote-bundle-uri \
		--no-quiet \
		>out.actual 2>err.actual &&
	test_cmp err.expect err.actual &&
	test_cmp out.expect out.actual &&

	# --quiet quiets the "From" line
	git \
		-C child \
		-c protocol.version=2 \
		ls-remote-bundle-uri \
		--quiet \
		>out.actual 2>err &&
	test_must_be_empty err &&
	test_cmp out.expect out.actual &&

	# --quiet is implicit if the remote is not implicit
	git \
		-c protocol.version=2 \
		ls-remote-bundle-uri \
		"$T5730_URI" \
		>out.actual 2>err &&
	test_must_be_empty err &&
	test_cmp out.expect out.actual
'
