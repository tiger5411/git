#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'cpp: c++ function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
Item RIGHT::DoSomething( Args with_spaces )
EOF_HUNK
Item RIGHT::DoSomething( Args with_spaces )
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: class constructor' \
	8<<\EOF_HUNK 9<<\EOF_TEST
Item::Item(int RIGHT)
EOF_HUNK
Item::Item(int RIGHT)
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: class constructor mem init' \
	8<<\EOF_HUNK 9<<\EOF_TEST
Item::Item(int RIGHT) :
EOF_HUNK
Item::Item(int RIGHT) :
	member(0)
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: class definition' \
	8<<\EOF_HUNK 9<<\EOF_TEST
class RIGHT
EOF_HUNK
class RIGHT
{
	int ChangeMe;
};
EOF_TEST

test_diff_funcname 'cpp: class definition derived' \
	8<<\EOF_HUNK 9<<\EOF_TEST
class RIGHT :
EOF_HUNK
class RIGHT :
	public Baseclass
{
	int ChangeMe;
};
EOF_TEST

test_diff_funcname 'cpp: class destructor' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT::~RIGHT()
EOF_HUNK
RIGHT::~RIGHT()
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: function returning global type' \
	8<<\EOF_HUNK 9<<\EOF_TEST
::Item get::it::RIGHT()
EOF_HUNK
::Item get::it::RIGHT()
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: function returning nested' \
	8<<\EOF_HUNK 9<<\EOF_TEST
get::Item get::it::RIGHT()
EOF_HUNK
get::Item get::it::RIGHT()
{
	ChangeMe;
}

EOF_TEST

test_diff_funcname 'cpp: function returning pointer' \
	8<<\EOF_HUNK 9<<\EOF_TEST
const char *get_it_RIGHT(char *ptr)
EOF_HUNK
const char *get_it_RIGHT(char *ptr)
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: function returning reference' \
	8<<\EOF_HUNK 9<<\EOF_TEST
string& get::it::RIGHT(char *ptr)
EOF_HUNK
string& get::it::RIGHT(char *ptr)
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: gnu style function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT(int arg)
EOF_HUNK
const char *
RIGHT(int arg)
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: namespace definition' \
	8<<\EOF_HUNK 9<<\EOF_TEST
namespace RIGHT
EOF_HUNK
namespace RIGHT
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: operator definition' \
	8<<\EOF_HUNK 9<<\EOF_TEST
Value operator+(Value LEFT, Value RIGHT)
EOF_HUNK
Value operator+(Value LEFT, Value RIGHT)
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: skip access specifiers' \
	8<<\EOF_HUNK 9<<\EOF_TEST
class RIGHT : public Baseclass
EOF_HUNK
class RIGHT : public Baseclass
{
public:
protected:
private:
	void DoSomething();
	int ChangeMe;
};
EOF_TEST

test_diff_funcname 'cpp: skip comment block' \
	8<<\EOF_HUNK 9<<\EOF_TEST
struct item RIGHT(int i)
EOF_HUNK
struct item RIGHT(int i)
// Do not
// pick up
/* these
** comments.
*/
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: skip labels' \
	8<<\EOF_HUNK 9<<\EOF_TEST
void RIGHT (void)
EOF_HUNK
void RIGHT (void)
{
repeat:		// C++ comment
next:		/* C comment */
	do_something();

	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: struct definition' \
	8<<\EOF_HUNK 9<<\EOF_TEST
struct RIGHT {
EOF_HUNK
struct RIGHT {
	unsigned
	/* this bit field looks like a label and should not be picked up */
		decoy_bitfield: 2,
		more : 1;
	int filler;

	int ChangeMe;
};
EOF_TEST

test_diff_funcname 'cpp: struct single line' \
	8<<\EOF_HUNK 9<<\EOF_TEST
struct RIGHT_iterator_tag {};
EOF_HUNK
void wrong()
{
}

struct RIGHT_iterator_tag {};

int ChangeMe;
EOF_TEST

test_diff_funcname 'cpp: template function definition' \
	8<<\EOF_HUNK 9<<\EOF_TEST
template<class T> int RIGHT(T arg)
EOF_HUNK
template<class T> int RIGHT(T arg)
{
	ChangeMe;
}
EOF_TEST

test_diff_funcname 'cpp: union definition' \
	8<<\EOF_HUNK 9<<\EOF_TEST
union RIGHT {
EOF_HUNK
union RIGHT {
	double v;
	int ChangeMe;
};
EOF_TEST

test_diff_funcname 'cpp: void c function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
void RIGHT (void)
EOF_HUNK
void RIGHT (void)
{
	ChangeMe;
}
EOF_TEST
