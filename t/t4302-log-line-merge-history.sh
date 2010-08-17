#!/bin/sh
#
# Copyright (c) 2010 Bo Yang
#

test_description='Test git log -L with merge commit

'
. ./test-lib.sh
. "$TEST_DIRECTORY"/diff-lib.sh

echo >path0 'void func(){
	printf("hello");
}
'

test_expect_success \
    'Add path0 and commit.' \
    'git add path0 &&
     git commit -m "Base commit"'

echo >path0 'void func(){
	printf("hello earth");
}
'

test_expect_success \
    'Change path0 in master.' \
    'git add path0 &&
     git commit -m "Change path0 in master"'

test_expect_success \
	'Make a new branch from the base commit' \
	'git checkout -b feature master^'

echo >path0 'void func(){
	print("hello moon");
}
'

test_expect_success \
    'Change path0 in feature.' \
    'git add path0 &&
     git commit -m "Change path0 in feature"'

test_expect_success \
	'Merge the master to feature' \
	'! git merge master'

echo >path0 'void func(){
	printf("hello earth and moon");
}
'

test_expect_success \
	'Resolve the conflict' \
	'git add path0 &&
	 git commit -m "Merge two branches"'

test_expect_success \
    'Show the line level log of path0' \
    'git log --pretty=format:%s%n%b -L /func/,/^}/ path0 > current'

cat >expected <<\EOF
Merge two branches

nontrivial merge found
path0
@@ 2,1 @@
 	printf("hello earth and moon");


Change path0 in master

diff --git a/path0 b/path0
index f628dea..bef7fa3 100644
--- a/path0
+++ b/path0
@@ -1,3 +1,3 @@
 void func(){
-	printf("hello");
+	printf("hello earth");
 }

Change path0 in feature

diff --git a/path0 b/path0
index f628dea..a940ef6 100644
--- a/path0
+++ b/path0
@@ -1,3 +1,3 @@
 void func(){
-	printf("hello");
+	print("hello moon");
 }

Base commit

diff --git a/path0 b/path0
new file mode 100644
index 0000000..f628dea
--- /dev/null
+++ b/path0
@@ -0,0 +1,3 @@
+void func(){
+	printf("hello");
+}
EOF

cat > expected-graph <<\EOF
*   Merge two branches
|\  
| | 
| | nontrivial merge found
| | path0
| | @@ 2,1 @@
| |  	printf("hello earth and moon");
| | 
| |   
| * Change path0 in master
| | 
| | diff --git a/path0 b/path0
| | index f628dea..bef7fa3 100644
| | --- a/path0
| | +++ b/path0
| | @@ -2,1 +2,1 @@
| | -	printf("hello");
| | +	printf("hello earth");
| |   
* | Change path0 in feature
|/  
|   
|   diff --git a/path0 b/path0
|   index f628dea..a940ef6 100644
|   --- a/path0
|   +++ b/path0
|   @@ -2,1 +2,1 @@
|   -	printf("hello");
|   +	print("hello moon");
|  
* Base commit
  
  diff --git a/path0 b/path0
  new file mode 100644
  index 0000000..f628dea
  --- /dev/null
  +++ b/path0
  @@ -0,0 +2,1 @@
  +	printf("hello");
EOF

test_expect_success \
    'Show the line log of the 2 line of path0 with graph' \
    'git log --pretty=format:%s%n%b --graph -L 2,+1 path0 > current-graph'

test_expect_success \
    'validate the output.' \
    'test_cmp current expected'
test_expect_success \
    'validate the graph output.' \
    'test_cmp current-graph expected-graph'

test_done
