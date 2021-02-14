#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'bash: arithmetic function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT()
EOF_HUNK
RIGHT() ((

    ChangeMe = "$x" + "$y"
))
EOF_TEST

test_diff_funcname 'bash: bashism style compact' \
	8<<\EOF_HUNK 9<<\EOF_TEST
function RIGHT {
EOF_HUNK
function RIGHT {
    function InvalidSyntax{
        :
        echo 'ChangeMe'
    }
}
EOF_TEST

test_diff_funcname 'bash: bashism style function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
function RIGHT {
EOF_HUNK
function RIGHT {
    :
    echo 'ChangeMe'
}
EOF_TEST

test_diff_funcname 'bash: bashism style whitespace' \
	8<<\EOF_HUNK 9<<\EOF_TEST
function 	RIGHT 	( 	) 	{
EOF_HUNK
	 function 	RIGHT 	( 	) 	{

	    ChangeMe
	 }
EOF_TEST

test_diff_funcname 'bash: conditional function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT()
EOF_HUNK
RIGHT() [[ \

    "$a" > "$ChangeMe"
]]
EOF_TEST

test_diff_funcname 'bash: missing parentheses' \
	8<<\EOF_HUNK 9<<\EOF_TEST
function RIGHT {
EOF_HUNK
function RIGHT {
    functionInvalidSyntax {
        :
        echo 'ChangeMe'
    }
}
EOF_TEST

test_diff_funcname 'bash: mixed style compact' \
	8<<\EOF_HUNK 9<<\EOF_TEST
function RIGHT(){
EOF_HUNK
function RIGHT(){
    :
    echo 'ChangeMe'
}
EOF_TEST

test_diff_funcname 'bash: mixed style function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
function RIGHT() {
EOF_HUNK
function RIGHT() {

    ChangeMe
}
EOF_TEST

test_diff_funcname 'bash: nested functions' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT()
EOF_HUNK
outer() {
    RIGHT() {
        :
        echo 'ChangeMe'
    }
}
EOF_TEST

test_diff_funcname 'bash: other characters' \
	8<<\EOF_HUNK 9<<\EOF_TEST
_RIGHT_0n()
EOF_HUNK
_RIGHT_0n() {

    ChangeMe
}
EOF_TEST

test_diff_funcname 'bash: posix style compact' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT()
EOF_HUNK
RIGHT(){

    ChangeMe
}
EOF_TEST

test_diff_funcname 'bash: posix style function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT()
EOF_HUNK
RIGHT() {

    ChangeMe
}
EOF_TEST

test_diff_funcname 'bash: posix style whitespace' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT 	( 	)
EOF_HUNK
	 RIGHT 	( 	) 	{

	    ChangeMe
	 }
EOF_TEST

test_diff_funcname 'bash: subshell function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT()
EOF_HUNK
RIGHT() (

    ChangeMe=2
)
EOF_TEST

test_diff_funcname 'bash: trailing comment' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT()
EOF_HUNK
RIGHT() { # Comment

    ChangeMe
}
EOF_TEST
