#!/bin/sh

## This "pragma" (as in "perldoc perlpragma") declares that the test
## will pass under GIT_TEST_PASSING_SANITIZE_LEAK=true. Source this
## before sourcing test-lib.sh

TEST_PASSES_SANITIZE_LEAK=true
export TEST_PASSES_SANITIZE_LEAK
