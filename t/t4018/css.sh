#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'css: attribute value selector' \
	8<<\EOF_HUNK 9<<\EOF_TEST
[class*="RIGHT"] {
EOF_HUNK
[class*="RIGHT"] {
    background : #000;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: block level @ statements' \
	8<<\EOF_HUNK 9<<\EOF_TEST
@keyframes RIGHT {
EOF_HUNK
@keyframes RIGHT {
    from {
        background : #000;
        border : 10px ChangeMe #C6C6C6;
    }
    to {
        background : #fff;
        border : 10px solid #C6C6C6;
    }
}
EOF_TEST

test_diff_funcname 'css: brace in col 1' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT label.control-label
EOF_HUNK
RIGHT label.control-label
{
    margin-top: 10px!important;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: class selector' \
	8<<\EOF_HUNK 9<<\EOF_TEST
.RIGHT {
EOF_HUNK
.RIGHT {
    background : #000;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: colon eol' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT h1 {
EOF_HUNK
RIGHT h1 {
color:
ChangeMe;
}
EOF_TEST

test_diff_funcname 'css: colon selector' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT a:hover {
EOF_HUNK
RIGHT a:hover {
    margin-top:
    10px!important;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: common' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT label.control-label {
EOF_HUNK
RIGHT label.control-label {
    margin-top: 10px!important;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: id selector' \
	8<<\EOF_HUNK 9<<\EOF_TEST
#RIGHT {
EOF_HUNK
#RIGHT {
    background : #000;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: long selector list' \
	8<<\EOF_HUNK 9<<\EOF_TEST
div ul#RIGHT {
EOF_HUNK
p.header,
label.control-label,
div ul#RIGHT {
    margin-top: 10px!important;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: prop sans indent' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT, label.control-label {
EOF_HUNK
RIGHT, label.control-label {
margin-top: 10px!important;
padding: 0;
border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: root selector' \
	8<<\EOF_HUNK 9<<\EOF_TEST
:RIGHT {
EOF_HUNK
:RIGHT {
    background : #000;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: short selector list' \
	8<<\EOF_HUNK 9<<\EOF_TEST
label.control, div ul#RIGHT {
EOF_HUNK
label.control, div ul#RIGHT {
    margin-top: 10px!important;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST

test_diff_funcname 'css: trailing space' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT label.control-label {
EOF_HUNK
RIGHT label.control-label {
    margin:10px;   
    padding:10px;
    border : 10px ChangeMe #C6C6C6;
}
EOF_TEST
