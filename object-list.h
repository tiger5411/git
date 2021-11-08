#ifndef OBJECT_LIST_H
#define OBJECT_LIST_H

/**
 * The "object_list" API is a "bare" list of "struct object *" managed
 * with the ALLOC_GROW() pattern.
 *
 * This is like the "struct object_array", except that here the "item"
 * contains only a "struct object", not an additional metadata about
 * how the object maps to a tree name, path and mode.
 */
struct object_list {
	size_t nr;
	size_t alloc;
	struct object_list_item {
		struct object *item;
	} *objects;
};

#define OBJECT_LIST_INIT { 0 }

/**
 * Insert a new "struct object *" at the end of the array
 *
 * Since this function uses xrealloc() (which die()s if it fails) if
 * the list needs to grow, it is safe not to check the pointer.
 * I.e. you may unconditionally use `object_list_insert(...)->item = * ...;`.
 */
void object_list_insert(struct object_list *array,
			struct object *object);

/**
 * Iterate over each item, as a macro.
 */
#define for_each_object_list_item(item,array) \
	for (item = (array)->objects; \
	     item && item < (array)->objects + (array)->nr; \
	     ++item)

/**
 * Free an object_list.
 */
void object_list_clear(struct object_list *array);

/**
 * object_list_pop(): Peels the last item off the list and returns the
 * "struct object_list_item". Passes the ownership of it over to you.
 */
struct object *object_list_pop(struct object_list *array);

#endif
