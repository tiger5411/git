#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'dts: labels' \
	8<<\EOF_HUNK 9<<\EOF_TEST
label2: RIGHT {
EOF_HUNK
/ {
	label_1: node1@ff00 {
		label2: RIGHT {
			vendor,some-property;

			ChangeMe = <0x45-30>;
		};
	};
};
EOF_TEST

test_diff_funcname 'dts: node unitless' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT {
EOF_HUNK
/ {
	label_1: node1 {
		RIGHT {
			prop-array = <1>, <4>;
			ChangeMe = <0xffeedd00>;
		};
	};
};
EOF_TEST

test_diff_funcname 'dts: nodes' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT@deadf00,4000 {
EOF_HUNK
/ {
	label_1: node1@ff00 {
		RIGHT@deadf00,4000 {
			#size-cells = <1>;
			ChangeMe = <0xffeedd00>;
		};
	};
};
EOF_TEST

test_diff_funcname 'dts: nodes boolean prop' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT@deadf00,4000 {
EOF_HUNK
/ {
	label_1: node1@ff00 {
		RIGHT@deadf00,4000 {
			boolean-prop1;

			ChangeMe;
		};
	};
};
EOF_TEST

test_diff_funcname 'dts: nodes comment1' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT@deadf00,4000 /* &a comment */ {
EOF_HUNK
/ {
	label_1: node1@ff00 {
		RIGHT@deadf00,4000 /* &a comment */ {
			#size-cells = <1>;
			ChangeMe = <0xffeedd00>;
		};
	};
};
EOF_TEST

test_diff_funcname 'dts: nodes comment2' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT@deadf00,4000 { /* a trailing comment */
EOF_HUNK
/ {
	label_1: node1@ff00 {
		RIGHT@deadf00,4000 { /* a trailing comment */ 
			#size-cells = <1>;
			ChangeMe = <0xffeedd00>;
		};
	};
};
EOF_TEST

test_diff_funcname 'dts: nodes multiline prop' \
	8<<\EOF_HUNK 9<<\EOF_TEST
RIGHT@deadf00,4000 {
EOF_HUNK
/ {
	label_1: node1@ff00 {
		RIGHT@deadf00,4000 {
			multilineprop = <3>,
					<4>,
					<5>,
					<6>,
					<7>;

			ChangeMe = <0xffeedd00>;
		};
	};
};
EOF_TEST

test_diff_funcname 'dts: reference' \
	8<<\EOF_HUNK 9<<\EOF_TEST
&RIGHT {
EOF_HUNK
&label_1 {
	TEST = <455>;
};

&RIGHT {
	vendor,some-property;

	ChangeMe = <0x45-30>;
};
EOF_TEST

test_diff_funcname 'dts: root' \
	8<<\EOF_HUNK 9<<\EOF_TEST
/ { RIGHT /* Technically just supposed to be a slash and brace */
EOF_HUNK
/ { RIGHT /* Technically just supposed to be a slash and brace */
	#size-cells = <1>;

	ChangeMe = <0xffeedd00>;
};
EOF_TEST

test_diff_funcname 'dts: root comment' \
	8<<\EOF_HUNK 9<<\EOF_TEST
/ { RIGHT /* Technically just supposed to be a slash and brace */
EOF_HUNK
/ { RIGHT /* Technically just supposed to be a slash and brace */
	#size-cells = <1>;

	/* This comment should be ignored */

	some-property = <40+2>;
	ChangeMe = <0xffeedd00>;
};
EOF_TEST
