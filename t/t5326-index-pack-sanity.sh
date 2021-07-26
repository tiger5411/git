#!/bin/sh

test_description='check that index-pack verifies its input data'
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit initial &&

	git rev-list --objects HEAD >obj-list &&
	pack1=$(git pack-objects <obj-list initial) &&

	test_commit second &&
	git rev-list --objects HEAD~..HEAD >obj-list2 &&
	pack2=$(git pack-objects <obj-list2 second) &&

	test_commit third &&
	test_commit fourth &&

	git rev-list --objects HEAD~1..HEAD >obj-list4 &&
	pack4=$(git pack-objects <obj-list4 fourth)
'

for strict in \
	"" \
	"--strict "
do
	for options in \
		"--stdin" \
		"--stdin --fix-thin" \
		"--stdin --fix-thin --check-self-contained-and-connected"
	do
		test_expect_success "index-pack initial with $strict$options" '
			test_when_finished "rm -rf unpack" &&

			git init --bare unpack &&
			git -C unpack index-pack $strict$options <initial-$pack1.pack
		'
	done
done

for strict in \
	"" \
	"--strict "
do
	for options in \
		"--stdin" \
		"--stdin --fix-thin"
	do
		test_expect_success "index-pack initial+second with $strict$options" '
			test_when_finished "rm -rf unpack" &&

			git init --bare unpack &&
			git -C unpack index-pack $strict$options <initial-$pack1.pack &&

			git -C unpack index-pack $strict$options <second-$pack2.pack
		'
	done

	for options in \
		"--stdin --check-self-contained-and-connected" \
		"--stdin --fix-thin --check-self-contained-and-connected"
	do
		test_expect_success "index-pack initial+second with $strict$options" '
			test_when_finished "rm -rf unpack" &&

			git init --bare unpack &&
			git -C unpack index-pack $strict$options <initial-$pack1.pack &&

			test_must_fail git -C unpack index-pack $strict$options <second-$pack2.pack
		'
	done
done

for options in \
	"--stdin" \
	"--stdin --fix-thin"
do
	test_expect_success "index-pack initial+second+fourth (no third!) with $options" '
		test_when_finished "rm -rf unpack" &&

		git init --bare unpack &&
		git -C unpack index-pack --stdin <initial-$pack1.pack &&
		git -C unpack index-pack --stdin --fix-thin <second-$pack2.pack &&
		git -C unpack index-pack $options <fourth-$pack4.pack
	'

	for more_options in \
		"--strict" \
		"--strict --check-self-contained-and-connected" \
		"--check-self-contained-and-connected"
	do
		test_expect_success "index-pack initial+second+fourth (no third!) with $options and $more_options" '
			test_when_finished "rm -rf unpack" &&

			git init --bare unpack &&
			git -C unpack index-pack --stdin <initial-$pack1.pack &&
			git -C unpack index-pack --stdin --fix-thin <second-$pack2.pack &&
			test_must_fail git -C unpack index-pack $options $more_options <fourth-$pack4.pack
		'
	done
done


test_done
