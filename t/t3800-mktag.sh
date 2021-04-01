#!/bin/sh
#
#

test_description='git mktag: tag object verify test'

. ./test-lib.sh

###########################################################
# check the tag.sig file, expecting verify_tag() to fail,
# and checking that the error message matches the pattern
# given in the expect.pat file.

check_verify_failure () {
	subject=$1 &&
	message=$2 &&
	shift 2 &&

	bad_fsck_no_refs_ok=
	bad_fsck_refs_err_is_empty=
	bad_fsck_refs_err_is_custom=
	bad_fsck_refs_out_is_broken_link=
	no_strict=
	while test $# != 0
	do
		case "$1" in
		--no-strict)
			no_strict=yes
			;;
		--bad-fsck-no-refs-ok)
			bad_fsck_no_refs_ok=yes
			;;
		--bad-fsck-refs-err-is-empty)
			bad_fsck_refs_err_is_empty=yes
			;;
		--bad-fsck-refs-err-is-custom)
			bad_fsck_refs_err_is_custom=yes
			;;
		--bad-fsck-refs-out-is-broken-link)
			bad_fsck_refs_out_is_broken_link=yes
			;;
		esac
		shift
	done &&

	test_expect_success "$subject" "
		test_must_fail git mktag <tag.sig 2>message &&
		grep '$message' message
	"

	if test -n "$no_strict"
	then
		test_expect_success "$subject suceeeds with --no-strict" "
			git mktag --no-strict <tag.sig
		"
	fi

	test_expect_success "setup: create the bad object for '$subject'" "
		# Not test_when_finished, used in later tests
		rm -rf bad-tag &&

		test_create_repo bad-tag &&
		# fsck below should not complain about unborn branches
		test_commit -C bad-tag A &&

		git -C bad-tag hash-object -t tag -w --stdin --literally <tag.sig >bad-obj
	"

	if test -n "$bad_fsck_no_refs_ok"
	then
		test_expect_success "fsck OK with bad object for '$subject'" '
			git -C bad-tag fsck --strict
		'
	else
		test_expect_success "fsck NOT OK with bad object for '$subject'" '
			test_must_fail git -C bad-tag fsck --strict
		'
	fi

	test_expect_success "$subject -> create ref" '
		bad_obj=$(cat bad-obj) &&

		# Not using update-ref here for the actual work since
		# it might fail, and we are not that interested in its
		# failure. But test that it does fail.
		test_must_fail git -C bad-tag update-ref $bad_obj &&

		cp bad-obj bad-tag/.git/refs/tags/bad-tag
	'

	test_expect_success "fsck ALWAYS NOT OK with bad object+ref for '$subject'" '
		test_must_fail git -c fsck.missingTaggerEntry=error -c fsck.badTagName=error -C bad-tag fsck >out 2>err
	'

	if test -n "$bad_fsck_refs_out_is_broken_link"
	then
		test_expect_success "fsck broken link output for '$subject' --> err is 'broken link'" '
			grep "broken link" out &&
			test_line_count = 3 out &&
			grep "^broken link from" out &&
			grep "^ *to *\\(commit\\|tree\\|blob\\|tag\\)" out &&
			grep "^missing \\(commit\\|tree\\|blob\\|tag\\)" out
		'
	else
		test_expect_success "fsck ALWAYS NOT OK with bad object+ref for '$subject' --> out is empty" '
			test_must_be_empty out
		'
	fi

	if test -n "$bad_fsck_refs_err_is_empty"
	then
		test_expect_success "fsck ALWAYS NOT OK with bad object+ref for '$subject' --> err is empty" '
			test_must_be_empty err
		'
	elif test -n "$bad_fsck_refs_err_is_custom"
	then
		test_expect_success "fsck ALWAYS NOT OK with bad object+ref for '$subject' --> err is checked below" '
			true
		'
	elif grep "$message" err
	then
		test_expect_success "fsck output for '$subject' --> err was checked above" '
			test_line_count = 1 err
		'
	else
		test_expect_success "fsck output for '$subject' --> err was checked above" '
			grep "object could not be parsed" err
		'
	fi

	test_expect_success "for-each-ref with bad object+ref for '$subject'" '
		test_must_fail git -C bad-tag for-each-ref --format="%(*objectname)"
	'
}

test_expect_mktag_success() {
	test_expect_success "$1" '
		git hash-object -t tag -w --stdin <tag.sig >expected &&
		git fsck --strict &&

		git mktag <tag.sig >hash &&
		test_cmp expected hash &&
		test_when_finished "git update-ref -d refs/tags/mytag $(cat hash)" &&
		git update-ref refs/tags/mytag $(cat hash) $(test_oid zero) &&
		git fsck --strict
	'
}

###########################################################
# first create a commit, so we have a valid object/type
# for the tag.
test_expect_success 'setup' '
	test_commit A &&
	test_commit B &&
	head=$(git rev-parse --verify HEAD) &&
	head_parent=$(git rev-parse --verify HEAD~) &&
	tree=$(git rev-parse HEAD^{tree}) &&
	blob=$(git rev-parse --verify HEAD:B.t)
'

test_expect_success 'basic usage' '
	cat >tag.sig <<-EOF &&
	object $head
	type commit
	tag mytag
	tagger T A Gger <tagger@example.com> 1206478233 -0500
	EOF
	git mktag <tag.sig &&
	git mktag --end-of-options <tag.sig &&
	test_expect_code 129 git mktag --unknown-option
'

############################################################
#  1. length check

cat >tag.sig <<EOF
too short for a tag
EOF

check_verify_failure 'Tag object length check' \
	'^error:.* missingObject:' 'strict'

############################################################
#  2. object line label check

cat >tag.sig <<EOF
xxxxxx $head
type tag
tag mytag
tagger . <> 0 +0000

EOF

check_verify_failure '"object" line label check' '^error:.* missingObject:'

############################################################
#  3. object line hash check

cat >tag.sig <<EOF
object $(echo $head | tr 0-9a-f z)
type tag
tag mytag
tagger . <> 0 +0000

EOF

check_verify_failure '"object" line check' '^error:.* badObjectSha1:'

############################################################
#  4. type line label check

cat >tag.sig <<EOF
object $head
xxxx tag
tag mytag
tagger . <> 0 +0000

EOF

check_verify_failure '"type" line label check' '^error:.* missingTypeEntry:'

############################################################
#  5. type line eol check

echo "object $head" >tag.sig
printf "type tagsssssssssssssssssssssssssssssss" >>tag.sig

check_verify_failure '"type" line eol check' '^error:.* unterminatedHeader:'

############################################################
#  6. tag line label check #1

cat >tag.sig <<EOF
object $head
type tag
xxx mytag
tagger . <> 0 +0000

EOF

check_verify_failure '"tag" line label check #1' \
	'^error:.* missingTagEntry:'

############################################################
#  7. tag line label check #2

cat >tag.sig <<EOF
object $head
type taggggggggggggggggggggggggggggggg
tag
EOF

check_verify_failure '"tag" line label check #2' \
	'^error:.* badType:'

############################################################
#  8. type line type-name length check

cat >tag.sig <<EOF
object $head
type taggggggggggggggggggggggggggggggg
tag mytag
EOF

check_verify_failure '"type" line type-name length check' \
	'^error:.* badType:'

############################################################
#  9. verify object (hash/type) check

cat >tag.sig <<EOF
object $(test_oid deadbeef)
type tag
tag mytag
tagger . <> 0 +0000

EOF

check_verify_failure 'verify object (hash/type) check -- correct type, nonexisting object' \
	'^fatal: could not read tagged object' \
	--bad-fsck-no-refs-ok \
	--bad-fsck-refs-err-is-empty \
	--bad-fsck-refs-out-is-broken-link

cat >tag.sig <<EOF
object $head
type tagggg
tag mytag
tagger . <> 0 +0000

EOF

check_verify_failure 'verify object (hash/type) check -- made-up type, valid object' \
	'^error:.* badType:' \
	--bad-fsck-refs-err-is-custom

test_expect_success 'check it' '
	grep "unknown tag type" err &&
	grep "object could not be parsed" err
'
test_expect_failure 'check it' '
	test_line_count = 4 err
'

cat >tag.sig <<EOF
object $(test_oid deadbeef)
type tagggg
tag mytag
tagger . <> 0 +0000

EOF

check_verify_failure 'verify object (hash/type) check -- made-up type, nonexisting object' \
	'^error:.* badType:' \
	--bad-fsck-refs-err-is-custom

test_expect_success 'check it' '
	grep "unknown tag type" err &&
	grep "object could not be parsed" err
'
test_expect_failure 'check it' '
	test_line_count = 4 err
'

cat >tag.sig <<EOF
object $head
type tree
tag mytag
tagger . <> 0 +0000

EOF

check_verify_failure 'verify object (hash/type) check -- mismatched type, valid object' \
	'^fatal: object.*tagged as.*tree.*but is.*commit' \
	--bad-fsck-no-refs-ok \
	--bad-fsck-refs-err-is-empty \
	--bad-fsck-refs-out-is-broken-link

############################################################
#  9.5. verify object (hash/type) check -- replacement

test_expect_success 'setup replacement of commit -> commit and tree -> blob' '
	git replace $head_parent $head &&
	git replace -f $tree $blob
'

cat >tag.sig <<EOF
object $head_parent
type commit
tag mytag
tagger . <> 0 +0000

EOF

test_expect_mktag_success 'tag to a commit replaced by another commit'

cat >tag.sig <<EOF
object $tree
type tree
tag mytag
tagger . <> 0 +0000

EOF

check_verify_failure 'verify object (hash/type) check -- mismatched type, valid object' \
	'^fatal: object.*tagged as.*tree.*but is.*blob' \
	--bad-fsck-no-refs-ok \
	--bad-fsck-refs-err-is-empty \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 10. verify tag-name check

cat >tag.sig <<EOF
object $head
type commit
tag my	tag
tagger . <> 0 +0000

EOF

check_verify_failure 'verify tag-name check' \
	'^error.*: badTagName:' \
	--no-strict \
	--bad-fsck-no-refs-ok \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 11. tagger line label check #1

cat >tag.sig <<EOF
object $head
type commit
tag mytag

This is filler
EOF

check_verify_failure '"tagger" line label check #1' \
	'^error.* :missingTaggerEntry:' \
	--no-strict \
	--bad-fsck-no-refs-ok \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 12. tagger line label check #2

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger

This is filler
EOF

check_verify_failure '"tagger" line label check #2' \
	'^error.*: missingTaggerEntry:' \
	--no-strict \
	--bad-fsck-no-refs-ok \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 13. allow missing tag author name like fsck

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger  <> 0 +0000

This is filler
EOF

test_expect_mktag_success 'allow missing tag author name'

############################################################
# 14. disallow missing tag author name

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <
 > 0 +0000

EOF

check_verify_failure 'disallow malformed tagger' \
	'^error:.* badEmail:' \
	--no-strict \
	--bad-fsck-no-refs-ok \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 15. allow empty tag email

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <> 0 +0000

EOF

test_expect_mktag_success 'allow empty tag email'

############################################################
# 16. allow spaces in tag email like fsck

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tag ger@example.com> 0 +0000

EOF

test_expect_mktag_success 'allow spaces in tag email like fsck'

############################################################
# 17. disallow missing tag timestamp

tr '_' ' ' >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com>__

EOF

check_verify_failure 'disallow missing tag timestamp' \
	'^error:.* badDate:' \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 18. detect invalid tag timestamp1

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> Tue Mar 25 15:47:44 2008

EOF

check_verify_failure 'detect invalid tag timestamp1' \
	'^error:.* badDate:' \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 19. detect invalid tag timestamp2

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 2008-03-31T12:20:15-0500

EOF

check_verify_failure 'detect invalid tag timestamp2' \
	'^error:.* badDate:' \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 20. detect invalid tag timezone1

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 1206478233 GMT

EOF

check_verify_failure 'detect invalid tag timezone1' \
	'^error:.* badTimezone:' \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 21. detect invalid tag timezone2

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 1206478233 +  30

EOF

check_verify_failure 'detect invalid tag timezone2' \
	'^error:.* badTimezone:' \
	--bad-fsck-refs-out-is-broken-link

############################################################
# 22. allow invalid tag timezone3 (the maximum is -1200/+1400)

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 1206478233 -1430

EOF

test_expect_mktag_success 'allow invalid tag timezone'

############################################################
# 23. detect invalid header entry

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 1206478233 -0500
this line should not be here

EOF

check_verify_failure 'detect invalid header entry' \
	'^error:.* extraHeaderEntry:' \
	--no-strict \
	--bad-fsck-no-refs-ok \
	--bad-fsck-refs-err-is-empty \
	--bad-fsck-refs-out-is-broken-link

test_expect_success 'invalid header entry config & fsck' '
	test_must_fail git mktag <tag.sig &&
	git mktag --no-strict <tag.sig &&

	test_must_fail git -c fsck.extraHeaderEntry=error mktag <tag.sig &&
	test_must_fail git -c fsck.extraHeaderEntry=error mktag --no-strict <tag.sig &&

	test_must_fail git -c fsck.extraHeaderEntry=warn mktag <tag.sig &&
	git -c fsck.extraHeaderEntry=warn mktag --no-strict <tag.sig &&

	git -c fsck.extraHeaderEntry=ignore mktag <tag.sig &&
	git -c fsck.extraHeaderEntry=ignore mktag --no-strict <tag.sig &&

	git fsck &&
	git -c fsck.extraHeaderEntry=warn fsck 2>err &&
	grep "warning .*extraHeaderEntry:" err &&
	test_must_fail git -c fsck.extraHeaderEntry=error 2>err fsck &&
	grep "error .* extraHeaderEntry:" err
'

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 1206478233 -0500


this line comes after an extra newline
EOF

test_expect_mktag_success 'allow extra newlines at start of body'

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 1206478233 -0500

EOF

test_expect_mktag_success 'allow a blank line before an empty body (1)'

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 1206478233 -0500
EOF

test_expect_mktag_success 'allow no blank line before an empty body (2)'

############################################################
# 24. create valid tag

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 1206478233 -0500
EOF

test_expect_mktag_success 'create valid tag object'

test_done
