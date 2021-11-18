#ifndef OBJECT_ARRAY_H
#define OBJECT_ARRAY_H

/**
 * The "object_array" API associates a "struct object" with a "name"
 * and "path" "char *", as well as an "unsigned mode". This is used by
 * revision.c for the "pending" array, and in consumers such as merge,
 * diff etc. who are interested in how objects might map onto paths.
 *
 * See "struct object_array_bare" (in "object-array-bare.h") if you
 * only need to keep track of lists of "struct object *", and aren't
 * interested in the "name", "path" and "mode" members provided by
 * this API.
 */
struct object_array {
	unsigned int nr;
	unsigned int alloc;
	struct object_array_entry {
		struct object *item;
		/*
		 * name or NULL.  If non-NULL, the memory pointed to
		 * is owned by this object.
		 */
		char *name;
		char *path;
		unsigned mode;
	} *objects;
};

#define OBJECT_ARRAY_INIT { 0 }

/**
 * add_object_array(): push an object without a "path" onto the end of
 * the array. Equivalent to calling add_object_array_with_path() with
 * a mode of S_IFINVALID, and a "path" of NULL.
 */
void add_object_array(struct object *obj, const char *name,
		      struct object_array *array);

/**
 * Iterate over each entry, as a macro.
 */
#define for_each_object_array_entry(entry,array)      \
	for (entry = (array)->objects;                       \
	     entry && entry < (array)->objects + (array)->nr; \
	     ++entry)

/**
 * add_object_array_with_path(): push an object onto the end of the
 * array. The "name" and "path" can be NULL, when non-NULL they'll be
 * xstrdup()'d.
 */
void add_object_array_with_path(struct object *obj, const char *name,
				struct object_array *array, unsigned mode,
				const char *path);

/**
 * Remove from array all but the first entry with a given name.
 * Warning: this function uses an O(N^2) algorithm.
 */
void object_array_remove_duplicates(struct object_array *array);

/**
 * Remove any objects from the array, freeing all used memory; afterwards
 * the array is ready to store more objects with add_object_array().
 */
void object_array_clear(struct object_array *array);

#endif
