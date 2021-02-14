#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'rust: fn' \
	8<<\EOF_HUNK 9<<\EOF_TEST
pub(self) fn RIGHT<T>(x: &[T]) where T: Debug {
EOF_HUNK
pub(self) fn RIGHT<T>(x: &[T]) where T: Debug {
    let _ = x;
    // a comment
    let a = ChangeMe;
}
EOF_TEST

test_diff_funcname 'rust: impl' \
	8<<\EOF_HUNK 9<<\EOF_TEST
impl<'a, T: AsRef<[u8]>>  std::RIGHT for Git<'a> {
EOF_HUNK
impl<'a, T: AsRef<[u8]>>  std::RIGHT for Git<'a> {

    pub fn ChangeMe(&self) -> () {
    }
}
EOF_TEST

test_diff_funcname 'rust: macro rules' \
	8<<\EOF_HUNK 9<<\EOF_TEST
macro_rules! RIGHT {
EOF_HUNK
macro_rules! RIGHT {
    () => {
        // a comment
        let x = ChangeMe;
    };
}
EOF_TEST

test_diff_funcname 'rust: struct' \
	8<<\EOF_HUNK 9<<\EOF_TEST
pub(super) struct RIGHT<'a> {
EOF_HUNK
#[derive(Debug)]
pub(super) struct RIGHT<'a> {
    name: &'a str,
    age: ChangeMe,
}
EOF_TEST

test_diff_funcname 'rust: trait' \
	8<<\EOF_HUNK 9<<\EOF_TEST
unsafe trait RIGHT<T> {
EOF_HUNK
unsafe trait RIGHT<T> {
    fn len(&self) -> u32;
    fn ChangeMe(&self, n: u32) -> T;
    fn iter<F>(&self, f: F) where F: Fn(T);
}
EOF_TEST
