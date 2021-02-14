#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'fountain: scene' \
	8<<\EOF_HUNK 9<<\EOF_TEST
EXT. STREET RIGHT OUTSIDE - DAY
EOF_HUNK
EXT. STREET RIGHT OUTSIDE - DAY

CHARACTER
You didn't say the magic phrase, "ChangeMe".
EOF_TEST
