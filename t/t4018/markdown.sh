#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'markdown: heading indented' \
	8<<\EOF_HUNK 9<<\EOF_TEST
   ### RIGHT
EOF_HUNK
Indented headings are allowed, as long as the indent is no more than 3 spaces.

   ### RIGHT

- something
- ChangeMe
EOF_TEST

test_diff_funcname 'markdown: heading non headings' \
	8<<\EOF_HUNK 9<<\EOF_TEST
# RIGHT
EOF_HUNK
Headings can be right next to other lines of the file:
# RIGHT
Indents of four or more spaces make a code block:

    # code comment, not heading

If there's no space after the final hash, it's not a heading:

#hashtag

Sequences of more than 6 hashes don't make a heading:

####### over-enthusiastic heading

So the detected heading should be right up at the start of this file.

ChangeMe
EOF_TEST
