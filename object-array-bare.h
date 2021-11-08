#ifndef OBJECT_ARRAY_BARE_H
#define OBJECT_ARRAY_BARE_H

/**
 * The "object_array_bare" API is a "bare" list of "struct object *"
 * managed with the ALLOC_GROW() pattern.  Ideally this would be
 * called "object_array" and the existing "object_array" (see
 * "object-array.h") should be called "object_array_path", but there
 * were existing API users.
 */

struct object_array_bare {
	size_t nr;
	size_t alloc;
	struct object_array_bare_item {
		struct object *item;
	} *objects;
};

#define OBJECT_ARRAY_BARE_INIT { 0 }

/**
 * Insert a new "struct object *" at the end of the array
 *
 * Since this function uses xrealloc() (which die()s if it fails) if
 * the list needs to grow, it is safe not to check the pointer.
 * I.e. you may write `object_array_bare_insert(...)->bare = * ...;`.
 */
void object_array_bare_insert(struct object_array_bare *array,
			      struct object *object);

/**
 * Iterate over each item, as a macro.
 */
#define for_each_object_array_bare_item(item,array)      \
	for (item = (array)->objects;                       \
	     item && item < (array)->objects + (array)->nr; \
	     ++item)

/**
 * Free a object_array_bare, but not the "bare" member.
 */
void object_array_bare_clear(struct object_array_bare *array);

/**
 * object_array_util_pop(): Peels the last item off the array and
 * returns the "struct object_array_util_item". Passes the ownership
 * of it over to you.
 */
struct object *object_array_bare_pop(struct object_array_bare *array);

#endif
