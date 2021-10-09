@@
expression E;
expression A;
expression B;
expression C;
@@
- if (E) {
-    error(A);
-    usage_with_options(B, C);
- }
+ if (E)
+    usage_with_optionsf(B, C, A);

