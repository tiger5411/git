#!/bin/sh

test_description='Test the packfile-uri protocol v2 extension'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

configure_exclusion () {
	git -C "$1" hash-object "$2" >objh &&
	git -C "$1" pack-objects "$HTTPD_DOCUMENT_ROOT_PATH/mypack" <objh >packh &&
	git -C "$1" config --add \
		"uploadpack.blobpackfileuri" \
		"$(cat objh) $(cat packh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" &&
	cat objh
}

test_expect_success 'part of packfile response provided as URI' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&

	test_when_finished "rm -rf \"$P\"" &&
	git init "$P" &&
	git -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	git -C "$P" add my-blob &&
	echo other-blob >"$P/other-blob" &&
	git -C "$P" add other-blob &&
	git -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&
	configure_exclusion "$P" other-blob >h2 &&

	test_when_finished "rm -rf http_child log" &&
	GIT_TRACE=1 GIT_TRACE_PACKET="$(pwd)/log" GIT_TEST_SIDEBAND_ALL=1 \
	git -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	# Ensure that my-blob and other-blob are in separate packfiles.
	for idx in http_child/.git/objects/pack/*.idx
	do
		git verify-pack --object-format=$(test_oid algo) --verbose $idx >out &&
		{
			grep "^[0-9a-f]\{16,\} " out || :
		} >out.objectlist &&
		if test_line_count = 1 out.objectlist
		then
			if grep $(cat h) out
			then
				>hfound
			fi &&
			if grep $(cat h2) out
			then
				>h2found
			fi
		fi || return 1
	done &&
	test -f hfound &&
	test -f h2found &&

	# Ensure that there are exactly 3 packfiles with associated .idx
	ls http_child/.git/objects/pack/*.pack \
	    http_child/.git/objects/pack/*.idx >filelist &&
	test_line_count = 6 filelist
'

test_expect_success 'packfile URIs with fetch instead of clone' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&

	test_when_finished "rm -rf \"$P\"" &&
	git init "$P" &&
	git -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	git -C "$P" add my-blob &&
	git -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&

	test_when_finished "rm -rf http_child" &&
	git init http_child &&

	GIT_TEST_SIDEBAND_ALL=1 \
	git -C http_child -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		fetch "$HTTPD_URL/smart/http_parent"
'

test_expect_success 'fetching with valid packfile URI but invalid hash fails' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&

	test_when_finished "rm -rf \"$P\"" &&
	git init "$P" &&
	git -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	git -C "$P" add my-blob &&
	echo other-blob >"$P/other-blob" &&
	git -C "$P" add other-blob &&
	git -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&
	# Configure a URL for other-blob. Just reuse the hash of the object as
	# the hash of the packfile, since the hash does not matter for this
	# test as long as it is not the hash of the pack, and it is of the
	# expected length.
	git -C "$P" hash-object other-blob >objh &&
	git -C "$P" pack-objects "$HTTPD_DOCUMENT_ROOT_PATH/mypack" <objh >packh &&
	git -C "$P" config --add \
		"uploadpack.blobpackfileuri" \
		"$(cat objh) $(cat objh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" &&

	test_when_finished "rm -rf http_child" &&
	test_must_fail env GIT_TEST_SIDEBAND_ALL=1 \
		git -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child 2>err &&
	test_i18ngrep "pack downloaded from.*does not match expected hash" err
'

test_expect_success 'packfile-uri with transfer.fsckobjects' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&

	test_when_finished "rm -rf \"$P\"" &&
	git init "$P" &&
	git -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	git -C "$P" add my-blob &&
	git -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&

	sane_unset GIT_TEST_SIDEBAND_ALL &&
	test_when_finished "rm -rf http_child" &&
	git -c protocol.version=2 -c transfer.fsckobjects=1 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	# Ensure that there are exactly 2 packfiles with associated .idx
	ls http_child/.git/objects/pack/*.pack \
	    http_child/.git/objects/pack/*.idx >filelist &&
	test_line_count = 4 filelist
'

test_expect_success 'packfile-uri with transfer.fsckobjects fails on bad object' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&

	test_when_finished "rm -rf \"$P\"" &&
	git init "$P" &&
	git -C "$P" config "uploadpack.allowsidebandall" "true" &&

	cat >bogus-commit <<-EOF &&
	tree $EMPTY_TREE
	author Bugs Bunny 1234567890 +0000
	committer Bugs Bunny <bugs@bun.ni> 1234567890 +0000

	This commit object intentionally broken
	EOF
	BOGUS=$(git -C "$P" hash-object -t commit -w --stdin <bogus-commit) &&
	git -C "$P" branch bogus-branch "$BOGUS" &&

	echo my-blob >"$P/my-blob" &&
	git -C "$P" add my-blob &&
	git -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&

	sane_unset GIT_TEST_SIDEBAND_ALL &&
	test_when_finished "rm -rf http_child" &&
	test_must_fail git -c protocol.version=2 -c transfer.fsckobjects=1 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child 2>error &&
	test_i18ngrep "invalid author/committer line - missing email" error
'

test_expect_success 'packfile-uri with transfer.fsckobjects succeeds when .gitmodules is separate from tree' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&

	test_when_finished "rm -rf \"$P\"" &&
	git init "$P" &&
	git -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo "[submodule libfoo]" >"$P/.gitmodules" &&
	echo "path = include/foo" >>"$P/.gitmodules" &&
	echo "url = git://example.com/git/lib.git" >>"$P/.gitmodules" &&
	git -C "$P" add .gitmodules &&
	git -C "$P" commit -m x &&

	configure_exclusion "$P" .gitmodules >h &&

	sane_unset GIT_TEST_SIDEBAND_ALL &&
	test_when_finished "rm -rf http_child" &&
	git -c protocol.version=2 -c transfer.fsckobjects=1 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	# Ensure that there are exactly 2 packfiles with associated .idx
	ls http_child/.git/objects/pack/*.pack \
	    http_child/.git/objects/pack/*.idx >filelist &&
	test_line_count = 4 filelist
'

test_expect_success 'packfile-uri with transfer.fsckobjects fails when .gitmodules separate from tree is invalid' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&

	test_when_finished "rm -rf \"$P\"" &&
	git init "$P" &&
	git -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo "[submodule \"..\"]" >"$P/.gitmodules" &&
	echo "path = include/foo" >>"$P/.gitmodules" &&
	echo "url = git://example.com/git/lib.git" >>"$P/.gitmodules" &&
	git -C "$P" add .gitmodules &&
	git -C "$P" commit -m x &&

	bad_oid=$(configure_exclusion "$P" .gitmodules) &&

	cat >err.expect <<-EOF &&
	Cloning into '"'"'http_child'"'"'...
	error: object $bad_oid: gitmodulesName: disallowed submodule name: ..
	error: object $bad_oid: gitmodulesName: disallowed submodule name: ..
	fatal: fsck failed
	EOF
	sane_unset GIT_TEST_SIDEBAND_ALL &&
	test_when_finished "rm -rf http_child" &&
	test_must_fail git -c protocol.version=2 -c transfer.fsckobjects=1 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child >out 2>err.actual &&

	test_must_be_empty out &&
	test_cmp err.expect err.actual
'

test_expect_success 'packfile-uri path redacted in trace' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child log &&

	git init "$P" &&
	git -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	git -C "$P" add my-blob &&
	git -C "$P" commit -m x &&

	git -C "$P" hash-object my-blob >objh &&
	git -C "$P" pack-objects "$HTTPD_DOCUMENT_ROOT_PATH/mypack" <objh >packh &&
	git -C "$P" config --add \
		"uploadpack.blobpackfileuri" \
		"$(cat objh) $(cat packh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" &&

	GIT_TRACE_PACKET="$(pwd)/log" \
	git -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	grep -F "clone< \\1$(cat packh) $HTTPD_URL/<redacted>" log
'

test_expect_success 'packfile-uri path not redacted in trace when GIT_TRACE_REDACT=0' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child log &&

	git init "$P" &&
	git -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	git -C "$P" add my-blob &&
	git -C "$P" commit -m x &&

	git -C "$P" hash-object my-blob >objh &&
	git -C "$P" pack-objects "$HTTPD_DOCUMENT_ROOT_PATH/mypack" <objh >packh &&
	git -C "$P" config --add \
		"uploadpack.blobpackfileuri" \
		"$(cat objh) $(cat packh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" &&

	GIT_TRACE_PACKET="$(pwd)/log" \
	GIT_TRACE_REDACT=0 \
	git -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	grep -F "clone< \\1$(cat packh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" log
'

test_done
