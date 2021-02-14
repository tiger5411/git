#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'java: class member function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
public static void main(String RIGHT[])
EOF_HUNK
public class Beer
{
	int special;
	public static void main(String RIGHT[])
	{
		System.out.print("ChangeMe");
	}
}
EOF_TEST
