@@
expression I;
expression E;
expression S;
expression O;
expression A;
@@
- if (I) {
+ if (I)
- error(E, A);
- usage_with_options(S, O);
+ usage_msg_optf(E, S, O, A);
- }
