#include "cache.h"
#include "object-array.h"
#include "object.h"

void add_object_array_with_path(struct object *obj, const char *name,
				struct object_array *array,
				unsigned mode, const char *path)
{
	unsigned nr = array->nr;
	struct object_array_entry *entry;

	ALLOC_GROW(array->objects, array->nr + 1, array->alloc);
	entry = &array->objects[array->nr++];
	entry->item = obj;
	entry->name = xstrdup_or_null(name);
	entry->mode = mode;
	entry->path = xstrdup_or_null(path);
	array->nr = ++nr;
}

void add_object_array(struct object *obj, const char *name, struct object_array *array)
{
	add_object_array_with_path(obj, name, array, S_IFINVALID, NULL);
}

/*
 * Free all memory associated with an entry; the result is
 * in an unspecified state and should not be examined.
 */
static void object_array_release_entry(struct object_array_entry *ent)
{
	free(ent->name);
	free(ent->path);
}

void object_array_clear(struct object_array *array)
{
	int i;
	for (i = 0; i < array->nr; i++)
		object_array_release_entry(&array->objects[i]);
	FREE_AND_NULL(array->objects);
	array->nr = array->alloc = 0;
}

/*
 * Return true if array already contains an entry.
 */
static int contains_object(struct object_array *array,
			   const struct object *item, const char *name)
{
	unsigned nr = array->nr, i;
	struct object_array_entry *object = array->objects;

	for (i = 0; i < nr; i++, object++)
		if (item == object->item && !strcmp(object->name, name))
			return 1;
	return 0;
}

void object_array_remove_duplicates(struct object_array *array)
{
	unsigned nr = array->nr, src;
	struct object_array_entry *objects = array->objects;

	array->nr = 0;
	for (src = 0; src < nr; src++) {
		/* wtf are we doing here if we're getting NULL entries anyway? */
		/* todo: missing test for "~/g/git/git bundle create o.bdl meta meta" duplicate test */
		if (!objects[src].name ||
		    !contains_object(array, objects[src].item,
				     objects[src].name)) {
			if (src != array->nr)
				objects[array->nr] = objects[src];
			array->nr++;
		} else {
			object_array_release_entry(&objects[src]);
		}
	}
}
