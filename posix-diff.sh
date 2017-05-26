#!/bin/bash

parallel -k '
	printf "%s%s" \
		"$(printf \\$(printf %03o {1}))" \
		"$(printf \\$(printf %03o {2}))" \
	>/tmp/f-{1}-{2}
	./git-grep               -G -I -f /tmp/f-{1}-{2} \
		 >/tmp/o-{1}-{2}.pcre.basic \
		2>/tmp/e-{1}-{2}.pcre.basic
	USE_REGCOMP=1 ./git-grep -G -I -f /tmp/f-{1}-{2} \
		 >/tmp/o-{1}-{2}.regcomp.basic \
		2>/tmp/e-{1}-{2}.regcomp.basic
	diff -ru /tmp/o-{1}-{2}.regcomp.basic /tmp/o-{1}-{2}.pcre.basic | head -n 10
	rm /tmp/f-{1}-{2} /tmp/o-{1}-{2}.pcre.basic /tmp/o-{1}-{2}.regcomp.basic
' ::: {33..58} ::: {33..58}
