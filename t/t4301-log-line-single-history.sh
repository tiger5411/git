#!/bin/sh
#
# Copyright (c) 2010 Bo Yang
#

test_description='Test git log -L with single line of history

'
. ./test-lib.sh
. "$TEST_DIRECTORY"/diff-lib.sh

echo >path0 'void func(){
	int a = 0;
	int b = 1;
	int c;
	c = a + b;
}
'

echo >path1 'void output(){
	printf("hello world");
}
'

test_expect_success \
    'add path0/path1 and commit.' \
    'git add path0 path1 &&
     git commit -m "Base commit"'

echo >path0 'void func(){
	int a = 10;
	int b = 11;
	int c;
	c = a + b;
}
'

echo >path1 'void output(){
	const char *str = "hello world!";
	printf("%s", str);
}
'

test_expect_success \
    'Change the 2,3 lines of path0 and path1.' \
    'git add path0 path1 &&
     git commit -m "Change 2,3 lines of path0 and path1"'

echo >path0 'void func(){
	int a = 10;
	int b = 11;
	int c;
	c = 10 * (a + b);
}
'

test_expect_success \
	'Change the 5th line of path0.' \
	'git add path0 &&
	 git commit -m "Change the 5th line of path0"'

echo >path0 'void func(){
	int a = 10;
	int b = 11;
	printf("%d", a - b);
}
'

test_expect_success \
	'Final change of path0.' \
	'git add path0 &&
	 git commit -m "Final change of path0"'

cat >expected-path0 <<\EOF
Final change of path0

diff --git a/path0 b/path0
index 44db133..1518c15 100644
--- a/path0
+++ b/path0
@@ -1,6 +1,5 @@
 void func(){
 	int a = 10;
 	int b = 11;
-	int c;
-	c = 10 * (a + b);
+	printf("%d", a - b);
 }

Change the 5th line of path0

diff --git a/path0 b/path0
index 9ef1692..44db133 100644
--- a/path0
+++ b/path0
@@ -1,6 +1,6 @@
 void func(){
 	int a = 10;
 	int b = 11;
 	int c;
-	c = a + b;
+	c = 10 * (a + b);
 }

Change 2,3 lines of path0 and path1

diff --git a/path0 b/path0
index aabffdf..9ef1692 100644
--- a/path0
+++ b/path0
@@ -1,6 +1,6 @@
 void func(){
-	int a = 0;
-	int b = 1;
+	int a = 10;
+	int b = 11;
 	int c;
 	c = a + b;
 }

Base commit

diff --git a/path0 b/path0
new file mode 100644
index 0000000..aabffdf
--- /dev/null
+++ b/path0
@@ -0,0 +1,6 @@
+void func(){
+	int a = 0;
+	int b = 1;
+	int c;
+	c = a + b;
+}
EOF

cat >expected-path1 <<\EOF
Change 2,3 lines of path0 and path1

diff --git a/path1 b/path1
index 997d841..1d711b5 100644
--- a/path1
+++ b/path1
@@ -1,3 +1,4 @@
 void output(){
-	printf("hello world");
+	const char *str = "hello world!";
+	printf("%s", str);
 }

Base commit

diff --git a/path1 b/path1
new file mode 100644
index 0000000..997d841
--- /dev/null
+++ b/path1
@@ -0,0 +1,3 @@
+void output(){
+	printf("hello world");
+}
EOF

cat >expected-pathall <<\EOF
Final change of path0

diff --git a/path0 b/path0
index 44db133..1518c15 100644
--- a/path0
+++ b/path0
@@ -1,6 +1,5 @@
 void func(){
 	int a = 10;
 	int b = 11;
-	int c;
-	c = 10 * (a + b);
+	printf("%d", a - b);
 }

Change the 5th line of path0

diff --git a/path0 b/path0
index 9ef1692..44db133 100644
--- a/path0
+++ b/path0
@@ -1,6 +1,6 @@
 void func(){
 	int a = 10;
 	int b = 11;
 	int c;
-	c = a + b;
+	c = 10 * (a + b);
 }

Change 2,3 lines of path0 and path1

diff --git a/path0 b/path0
index aabffdf..9ef1692 100644
--- a/path0
+++ b/path0
@@ -1,6 +1,6 @@
 void func(){
-	int a = 0;
-	int b = 1;
+	int a = 10;
+	int b = 11;
 	int c;
 	c = a + b;
 }
diff --git a/path1 b/path1
index 997d841..1d711b5 100644
--- a/path1
+++ b/path1
@@ -1,3 +1,4 @@
 void output(){
-	printf("hello world");
+	const char *str = "hello world!";
+	printf("%s", str);
 }

Base commit

diff --git a/path0 b/path0
new file mode 100644
index 0000000..aabffdf
--- /dev/null
+++ b/path0
@@ -0,0 +1,6 @@
+void func(){
+	int a = 0;
+	int b = 1;
+	int c;
+	c = a + b;
+}
diff --git a/path1 b/path1
new file mode 100644
index 0000000..997d841
--- /dev/null
+++ b/path1
@@ -0,0 +1,3 @@
+void output(){
+	printf("hello world");
+}
EOF

cat >expected-linenum <<\EOF
Change 2,3 lines of path0 and path1

diff --git a/path0 b/path0
index aabffdf..9ef1692 100644
--- a/path0
+++ b/path0
@@ -1,2 +1,2 @@
 void func(){
-	int a = 0;
+	int a = 10;

Base commit

diff --git a/path0 b/path0
new file mode 100644
index 0000000..aabffdf
--- /dev/null
+++ b/path0
@@ -0,0 +1,2 @@
+void func(){
+	int a = 0;
EOF

cat >expected-always <<\EOF
Final change of path0

diff --git a/path0 b/path0
index 44db133..1518c15 100644
--- a/path0
+++ b/path0
@@ -1,2 +1,2 @@
 void func(){
 	int a = 10;

Change the 5th line of path0

diff --git a/path0 b/path0
index 9ef1692..44db133 100644
--- a/path0
+++ b/path0
@@ -1,2 +1,2 @@
 void func(){
 	int a = 10;

Change 2,3 lines of path0 and path1

diff --git a/path0 b/path0
index aabffdf..9ef1692 100644
--- a/path0
+++ b/path0
@@ -1,2 +1,2 @@
 void func(){
-	int a = 0;
+	int a = 10;

Base commit

diff --git a/path0 b/path0
new file mode 100644
index 0000000..aabffdf
--- /dev/null
+++ b/path0
@@ -0,0 +1,2 @@
+void func(){
+	int a = 0;
EOF

test_expect_success \
    'Show the line level log of path0' \
    'git log --pretty=format:%s%n%b -L /func/,/^}/ path0 > current-path0'

test_expect_success 'validate the path0 output.' '
    test_cmp current-path0 expected-path0
'
test_expect_success \
    'Show the line level log of path1' \
    'git log --pretty=format:%s%n%b -L /output/,/^}/ path1 > current-path1'

test_expect_success 'validate the path1 output.' '
    test_cmp current-path1 expected-path1
'
test_expect_success \
	'Show the line level log of two files' \
    'git log --pretty=format:%s%n%b -L /func/,/^}/ path0 -L /output/,/^}/ path1 > current-pathall'

test_expect_success 'validate the all path output.' '
    test_cmp current-pathall expected-pathall
'
test_expect_success \
	'Test the line number argument' \
	'git log --pretty=format:%s%n%b -L 1,2 path0 > current-linenum'

test_expect_success 'validate the line number output.' '
    test_cmp current-linenum expected-linenum
'
test_expect_success \
	'Test the --full-line-diff option' \
	'git log --pretty=format:%s%n%b --full-line-diff -L 1,2 path0 > current-always'

test_expect_success 'validate the --full-line-diff output.' '
    test_cmp current-always expected-always
'

# Rerun all log with graph
test_expect_success \
    'Show the line level log of path0 with --graph' \
    'git log --pretty=format:%s%n%b --graph -L /func/,/^}/ path0 > current-path0-graph'

test_expect_success \
    'Show the line level log of path1 with --graph' \
    'git log --pretty=format:%s%n%b --graph -L /output/,/^}/ path1 > current-path1-graph'

test_expect_success \
    'Show the line level log of two files with --graph' \
    'git log --pretty=format:%s%n%b --graph -L /func/,/^}/ path0 --graph -L /output/,/^}/ path1 > current-pathall-graph'

test_expect_success \
    'Test the line number argument with --graph' \
    'git log --pretty=format:%s%n%b --graph -L 1,2 path0 > current-linenum-graph'

test_expect_success \
	'Test the --full-line-diff option with --graph option' \
	'git log --pretty=format:%s%n%b --full-line-diff --graph -L 1,2 path0 > current-always-graph'

cat > expected-path0-graph <<\EOF
* Final change of path0
| 
| diff --git a/path0 b/path0
| index 44db133..1518c15 100644
| --- a/path0
| +++ b/path0
| @@ -1,6 +1,5 @@
|  void func(){
|  	int a = 10;
|  	int b = 11;
| -	int c;
| -	c = 10 * (a + b);
| +	printf("%d", a - b);
|  }
|  
* Change the 5th line of path0
| 
| diff --git a/path0 b/path0
| index 9ef1692..44db133 100644
| --- a/path0
| +++ b/path0
| @@ -1,6 +1,6 @@
|  void func(){
|  	int a = 10;
|  	int b = 11;
|  	int c;
| -	c = a + b;
| +	c = 10 * (a + b);
|  }
|  
* Change 2,3 lines of path0 and path1
| 
| diff --git a/path0 b/path0
| index aabffdf..9ef1692 100644
| --- a/path0
| +++ b/path0
| @@ -1,6 +1,6 @@
|  void func(){
| -	int a = 0;
| -	int b = 1;
| +	int a = 10;
| +	int b = 11;
|  	int c;
|  	c = a + b;
|  }
|  
* Base commit
  
  diff --git a/path0 b/path0
  new file mode 100644
  index 0000000..aabffdf
  --- /dev/null
  +++ b/path0
  @@ -0,0 +1,6 @@
  +void func(){
  +	int a = 0;
  +	int b = 1;
  +	int c;
  +	c = a + b;
  +}
EOF

cat > expected-path1-graph <<\EOF
* Change 2,3 lines of path0 and path1
| 
| diff --git a/path1 b/path1
| index 997d841..1d711b5 100644
| --- a/path1
| +++ b/path1
| @@ -1,3 +1,4 @@
|  void output(){
| -	printf("hello world");
| +	const char *str = "hello world!";
| +	printf("%s", str);
|  }
|  
* Base commit
  
  diff --git a/path1 b/path1
  new file mode 100644
  index 0000000..997d841
  --- /dev/null
  +++ b/path1
  @@ -0,0 +1,3 @@
  +void output(){
  +	printf("hello world");
  +}
EOF

cat > expected-pathall-graph <<\EOF
* Final change of path0
| 
| diff --git a/path0 b/path0
| index 44db133..1518c15 100644
| --- a/path0
| +++ b/path0
| @@ -1,6 +1,5 @@
|  void func(){
|  	int a = 10;
|  	int b = 11;
| -	int c;
| -	c = 10 * (a + b);
| +	printf("%d", a - b);
|  }
|  
* Change the 5th line of path0
| 
| diff --git a/path0 b/path0
| index 9ef1692..44db133 100644
| --- a/path0
| +++ b/path0
| @@ -1,6 +1,6 @@
|  void func(){
|  	int a = 10;
|  	int b = 11;
|  	int c;
| -	c = a + b;
| +	c = 10 * (a + b);
|  }
|  
* Change 2,3 lines of path0 and path1
| 
| diff --git a/path0 b/path0
| index aabffdf..9ef1692 100644
| --- a/path0
| +++ b/path0
| @@ -1,6 +1,6 @@
|  void func(){
| -	int a = 0;
| -	int b = 1;
| +	int a = 10;
| +	int b = 11;
|  	int c;
|  	c = a + b;
|  }
| diff --git a/path1 b/path1
| index 997d841..1d711b5 100644
| --- a/path1
| +++ b/path1
| @@ -1,3 +1,4 @@
|  void output(){
| -	printf("hello world");
| +	const char *str = "hello world!";
| +	printf("%s", str);
|  }
|  
* Base commit
  
  diff --git a/path0 b/path0
  new file mode 100644
  index 0000000..aabffdf
  --- /dev/null
  +++ b/path0
  @@ -0,0 +1,6 @@
  +void func(){
  +	int a = 0;
  +	int b = 1;
  +	int c;
  +	c = a + b;
  +}
  diff --git a/path1 b/path1
  new file mode 100644
  index 0000000..997d841
  --- /dev/null
  +++ b/path1
  @@ -0,0 +1,3 @@
  +void output(){
  +	printf("hello world");
  +}
EOF

cat > expected-linenum-graph <<\EOF
* Change 2,3 lines of path0 and path1
| 
| diff --git a/path0 b/path0
| index aabffdf..9ef1692 100644
| --- a/path0
| +++ b/path0
| @@ -1,2 +1,2 @@
|  void func(){
| -	int a = 0;
| +	int a = 10;
|  
* Base commit
  
  diff --git a/path0 b/path0
  new file mode 100644
  index 0000000..aabffdf
  --- /dev/null
  +++ b/path0
  @@ -0,0 +1,2 @@
  +void func(){
  +	int a = 0;
EOF

cat > expected-always-graph <<\EOF
* Final change of path0
| 
| diff --git a/path0 b/path0
| index 44db133..1518c15 100644
| --- a/path0
| +++ b/path0
| @@ -1,2 +1,2 @@
|  void func(){
|  	int a = 10;
|  
* Change the 5th line of path0
| 
| diff --git a/path0 b/path0
| index 9ef1692..44db133 100644
| --- a/path0
| +++ b/path0
| @@ -1,2 +1,2 @@
|  void func(){
|  	int a = 10;
|  
* Change 2,3 lines of path0 and path1
| 
| diff --git a/path0 b/path0
| index aabffdf..9ef1692 100644
| --- a/path0
| +++ b/path0
| @@ -1,2 +1,2 @@
|  void func(){
| -	int a = 0;
| +	int a = 10;
|  
* Base commit
  
  diff --git a/path0 b/path0
  new file mode 100644
  index 0000000..aabffdf
  --- /dev/null
  +++ b/path0
  @@ -0,0 +1,2 @@
  +void func(){
  +	int a = 0;
EOF

test_expect_success \
    'validate the path0 output.' \
    'test_cmp current-path0-graph expected-path0-graph'
test_expect_success \
	'validate the path1 output.' \
	'test_cmp current-path1-graph expected-path1-graph'
test_expect_success \
	'validate the all path output.' \
	'test_cmp current-pathall-graph expected-pathall-graph'
test_expect_success \
	'validate graph output' \
	'test_cmp current-linenum-graph expected-linenum-graph'
test_expect_success \
	'validate --full-line-diff output' \
	'test_cmp current-always-graph expected-always-graph'

test_done
