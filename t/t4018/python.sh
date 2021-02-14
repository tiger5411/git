#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'python: async def' \
	8<<\EOF_HUNK 9<<\EOF_TEST
async def RIGHT(pi: int = 3.14):
EOF_HUNK
async def RIGHT(pi: int = 3.14):
    while True:
        break
    return ChangeMe()
EOF_TEST

test_diff_funcname 'python: class' \
	8<<\EOF_HUNK 9<<\EOF_TEST
class RIGHT(int, str):
EOF_HUNK
class RIGHT(int, str):
    # comment
    # another comment
    # ChangeMe
EOF_TEST

test_diff_funcname 'python: def' \
	8<<\EOF_HUNK 9<<\EOF_TEST
def RIGHT(pi: int = 3.14):
EOF_HUNK
def RIGHT(pi: int = 3.14):
    while True:
        break
    return ChangeMe()
EOF_TEST

test_diff_funcname 'python: indented async def' \
	8<<\EOF_HUNK 9<<\EOF_TEST
async def RIGHT(self, x: int):
EOF_HUNK
class Foo:
    async def RIGHT(self, x: int):
        return [
            1,
            2,
            ChangeMe,
        ]
EOF_TEST

test_diff_funcname 'python: indented class' \
	8<<\EOF_HUNK 9<<\EOF_TEST
class RIGHT:
EOF_HUNK
if TYPE_CHECKING:
    class RIGHT:
        # comment
        # another comment
        # ChangeMe
EOF_TEST

test_diff_funcname 'python: indented def' \
	8<<\EOF_HUNK 9<<\EOF_TEST
def RIGHT(self, x: int):
EOF_HUNK
class Foo:
    def RIGHT(self, x: int):
        return [
            1,
            2,
            ChangeMe,
        ]
EOF_TEST
