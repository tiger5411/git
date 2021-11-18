@@
expression E;
expression F;
expression G;
@@
- add_pending_oid(E, NULL, F, G);
+ add_pending_oid_no_name(E, F, G);

@@
expression E;
expression F;
@@
- add_pending_object(E, F, NULL);
+ add_pending_object_no_name(E, F);

@@
expression E;
expression F;
expression G;
expression H;
@@
- add_pending_object_with_path(E, F, "", G, H);
+ add_pending_object_with_path(E, F, NULL, G, H);

@@
expression E;
expression F;
expression G;
@@
- add_pending_object_with_mode(E, F, "", G);
+ add_pending_object_with_mode(E, F, NULL, G);
