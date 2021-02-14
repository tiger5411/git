#!/bin/sh
#
# See ../t4018-diff-funcname.sh's test_diff_funcname()
#

test_diff_funcname 'fortran: block data' \
	8<<\EOF_HUNK 9<<\EOF_TEST
BLOCK DATA RIGHT
EOF_HUNK
       BLOCK DATA RIGHT
       
       COMMON /B/ C, ChangeMe
       DATA C, ChangeMe  / 2.0, 6.0 / 
       END 
EOF_TEST

test_diff_funcname 'fortran: comment' \
	8<<\EOF_HUNK 9<<\EOF_TEST
subroutine RIGHT
EOF_HUNK
      module a

      contains

      ! subroutine wrong
      subroutine RIGHT
      ! subroutine wrong

      real ChangeMe

      end subroutine RIGHT

      end module a
EOF_TEST

test_diff_funcname 'fortran: comment keyword' \
	8<<\EOF_HUNK 9<<\EOF_TEST
subroutine RIGHT (funcA, funcB)
EOF_HUNK
      module a

      contains

      subroutine RIGHT (funcA, funcB)

      real funcA  ! grid function a
      real funcB  ! grid function b

      real ChangeMe

      end subroutine RIGHT

      end module a
EOF_TEST

test_diff_funcname 'fortran: comment legacy' \
	8<<\EOF_HUNK 9<<\EOF_TEST
subroutine RIGHT
EOF_HUNK
      module a

      contains

C subroutine wrong
      subroutine RIGHT
C subroutine wrong

      real ChangeMe

      end subroutine RIGHT

      end module a
EOF_TEST

test_diff_funcname 'fortran: comment legacy star' \
	8<<\EOF_HUNK 9<<\EOF_TEST
subroutine RIGHT
EOF_HUNK
      module a

      contains

* subroutine wrong
      subroutine RIGHT
* subroutine wrong

      real ChangeMe

      end subroutine RIGHT

      end module a
EOF_TEST

test_diff_funcname 'fortran: external function' \
	8<<\EOF_HUNK 9<<\EOF_TEST
function RIGHT(a, b) result(c)
EOF_HUNK
function RIGHT(a, b) result(c)

integer, intent(in) :: ChangeMe
integer, intent(in) :: b
integer, intent(out) :: c

c = a+b

end function RIGHT
EOF_TEST

test_diff_funcname 'fortran: external subroutine' \
	8<<\EOF_HUNK 9<<\EOF_TEST
subroutine RIGHT
EOF_HUNK
subroutine RIGHT

real ChangeMe

end subroutine RIGHT
EOF_TEST

test_diff_funcname 'fortran: module' \
	8<<\EOF_HUNK 9<<\EOF_TEST
module RIGHT
EOF_HUNK
module RIGHT

use ChangeMe

end module RIGHT
EOF_TEST

test_diff_funcname 'fortran: module procedure' \
	8<<\EOF_HUNK 9<<\EOF_TEST
module RIGHT
EOF_HUNK
 module RIGHT

   implicit none
   private

   interface letters  ! generic interface
      module procedure aaaa, &
                       bbbb, &
                       ChangeMe, &
                       dddd
   end interface
   
end module RIGHT
EOF_TEST

test_diff_funcname 'fortran: program' \
	8<<\EOF_HUNK 9<<\EOF_TEST
program RIGHT
EOF_HUNK
program RIGHT

call ChangeMe

end program RIGHT
EOF_TEST
