#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'matlab: class definition' \
	8<<\EOF_HUNK 9<<\EOF_TEST
classdef RIGHT
EOF_HUNK
classdef RIGHT
    properties
        ChangeMe
    end
end
EOF_TEST

test_diff_funcname 'matlab: function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
function y = RIGHT()
EOF_HUNK
function y = RIGHT()
x = 5;
y = ChangeMe + x;
end
EOF_TEST

test_diff_funcname 'matlab: octave section 1' \
	8<<\EOF_HUNK 9<<\EOF_TEST
%%% RIGHT section
EOF_HUNK
%%% RIGHT section
# this is octave script
ChangeMe = 1;
EOF_TEST

test_diff_funcname 'matlab: octave section 2' \
	8<<\EOF_HUNK 9<<\EOF_TEST
## RIGHT section
EOF_HUNK
## RIGHT section
# this is octave script
ChangeMe = 1;
EOF_TEST

test_diff_funcname 'matlab: section' \
	8<<\EOF_HUNK 9<<\EOF_TEST
%% RIGHT section
EOF_HUNK
%% RIGHT section
% this is understood by both matlab and octave
ChangeMe = 1;
EOF_TEST
