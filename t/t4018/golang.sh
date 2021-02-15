#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'golang: package' \
	8<<\EOF_HUNK 9<<\EOF_TEST
package main
EOF_HUNK
package main

import "fmt"
// ChangeMe
EOF_TEST

test_diff_funcname 'golang: complex function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
func (t *Test) RIGHT(a Type) (Type, error) {
EOF_HUNK
type Test struct {
	a Type
}

func (t *Test) RIGHT(a Type) (Type, error) {
	t.a = a
	return ChangeMe, nil
}
EOF_TEST

test_diff_funcname 'golang: func' \
	8<<\EOF_HUNK 9<<\EOF_TEST
func RIGHT() {
EOF_HUNK
func RIGHT() {
	a := 5
	b := ChangeMe
}
EOF_TEST

test_diff_funcname 'golang: interface' \
	8<<\EOF_HUNK 9<<\EOF_TEST
type RIGHT interface {
EOF_HUNK
type RIGHT interface {
	a() Type
	b() ChangeMe
}
EOF_TEST

test_diff_funcname 'golang: long func' \
	8<<\EOF_HUNK 9<<\EOF_TEST
func RIGHT(aVeryVeryVeryLongVariableName AVeryVeryVeryLongType,
EOF_HUNK
func RIGHT(aVeryVeryVeryLongVariableName AVeryVeryVeryLongType,
	anotherLongVariableName AnotherLongType) {
	a := 5
	b := ChangeMe
}
EOF_TEST

test_diff_funcname 'golang: struct' \
	8<<\EOF_HUNK 9<<\EOF_TEST
type RIGHT struct {
EOF_HUNK
type RIGHT struct {
	a Type
	b ChangeMe
}
EOF_TEST
