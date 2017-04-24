#!/bin/sh

test_description='messages from rebase operation'

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit O fileO &&
	test_commit X fileX &&
	test_commit A fileA &&
	test_commit B fileB &&
	test_commit Y fileY &&

	git checkout -b topic O &&
	git cherry-pick A B &&
	test_commit Z fileZ &&
	git tag start
'

cat >expect <<\EOF
Already applied: 0001 A
Already applied: 0002 B
Committed: 0003 Z
EOF

test_expect_success 'rebase -m' '
	git rebase -m master >report &&
	sed -n -e "/^Already applied: /p" \
		-e "/^Committed: /p" report >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase against master twice' '
	git rebase master >out &&
	grep "Current branch topic is up to date" out
'

test_expect_success 'rebase against master twice with --force' '
	git rebase --force-rebase master >out &&
	grep "Current branch topic is up to date, rebase forced" out
'

test_expect_success 'rebase against master twice from another branch' '
	git checkout topic^ &&
	git rebase master topic >out &&
	grep "Current branch topic is up to date" out
'

test_expect_success 'rebase fast-forward to master' '
	git checkout topic^ &&
	git rebase topic >out &&
	grep "Fast-forwarded HEAD to topic" out
'

test_expect_success 'rebase --stat' '
	git reset --hard start &&
        git rebase --stat master >diffstat.txt &&
        grep "^ fileX |  *1 +$" diffstat.txt
'

test_expect_success 'rebase w/config rebase.stat' '
	git reset --hard start &&
        git config rebase.stat true &&
        git rebase master >diffstat.txt &&
        grep "^ fileX |  *1 +$" diffstat.txt
'

test_expect_success 'rebase -n overrides config rebase.stat config' '
	git reset --hard start &&
        git config rebase.stat true &&
        git rebase -n master >diffstat.txt &&
        ! grep "^ fileX |  *1 +$" diffstat.txt
'

test_expect_success 'rebase --onto outputs the invalid ref' '
	test_must_fail git rebase --onto invalid-ref HEAD HEAD 2>err &&
	grep "invalid-ref" err
'

test_done
