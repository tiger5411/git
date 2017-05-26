#!/bin/bash

parallel -k '
	printf "%s%s" \
		"$(printf \\$(printf %03o {1}))" \
		"$(printf \\$(printf %03o {2}))" \
	>/tmp/f-{1}-{2}
	./git --exec-path=$(pwd) -C ../pcre grep -G -I -f /tmp/f-{1}-{2} \
		 >/tmp/o-{1}-{2}.pcre \
		2>/tmp/e-{1}-{2}.pcre
	USE_REGCOMP=1 ./git --exec-path=$(pwd) -C ../pcre grep -G -I -f /tmp/f-{1}-{2} \
		 >/tmp/o-{1}-{2}.regcomp \
		2>/tmp/e-{1}-{2}.regcomp
	if ! diff -ru /tmp/o-{1}-{2}.regcomp /tmp/o-{1}-{2}.pcre >/tmp/d-{1}-{2}
	then
		printf "DIFF: %s+%s (%s)\n" {1} {2} $(cat /tmp/f-{1}-{2})
		head -n 10 /tmp/d-{1}-{2}
	else
		printf "SAME: %s+%s\n" {1} {2}
	fi
	rm /tmp/f-{1}-{2} /tmp/o-{1}-{2}.pcre /tmp/o-{1}-{2}.regcomp /tmp/d-{1}-{2}
' ::: {1..127} ::: {1..127}
