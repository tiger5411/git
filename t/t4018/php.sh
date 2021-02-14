#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'php: abstract class' \
	8<<\EOF_HUNK 9<<\EOF_TEST
abstract class RIGHT
EOF_HUNK
abstract class RIGHT
{
    const FOO = 'ChangeMe';
}
EOF_TEST

test_diff_funcname 'php: abstract method' \
	8<<\EOF_HUNK 9<<\EOF_TEST
abstract public function RIGHT(): ?string
EOF_HUNK
abstract class Klass
{
    abstract public function RIGHT(): ?string
    {
        return 'ChangeMe';
    }
}
EOF_TEST

test_diff_funcname 'php: class' \
	8<<\EOF_HUNK 9<<\EOF_TEST
class RIGHT
EOF_HUNK
class RIGHT
{
    const FOO = 'ChangeMe';
}
EOF_TEST

test_diff_funcname 'php: final class' \
	8<<\EOF_HUNK 9<<\EOF_TEST
final class RIGHT
EOF_HUNK
final class RIGHT
{
    const FOO = 'ChangeMe';
}
EOF_TEST

test_diff_funcname 'php: final method' \
	8<<\EOF_HUNK 9<<\EOF_TEST
final public function RIGHT(): string
EOF_HUNK
class Klass
{
    final public function RIGHT(): string
    {
        return 'ChangeMe';
    }
}
EOF_TEST

test_diff_funcname 'php: function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
function RIGHT()
EOF_HUNK
function RIGHT()
{
    return 'ChangeMe';
}
EOF_TEST

test_diff_funcname 'php: interface' \
	8<<\EOF_HUNK 9<<\EOF_TEST
interface RIGHT
EOF_HUNK
interface RIGHT
{
    public function foo($ChangeMe);
}
EOF_TEST

test_diff_funcname 'php: method' \
	8<<\EOF_HUNK 9<<\EOF_TEST
public static function RIGHT()
EOF_HUNK
class Klass
{
    public static function RIGHT()
    {
        return 'ChangeMe';
    }
}
EOF_TEST

test_diff_funcname 'php: trait' \
	8<<\EOF_HUNK 9<<\EOF_TEST
trait RIGHT
EOF_HUNK
trait RIGHT
{
    public function foo($ChangeMe)
    {
        return 'foo';
    }
}
EOF_TEST
