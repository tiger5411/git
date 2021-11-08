#include "cache.h"
#include "object.h"
#include "object-array-bare.h"

void object_array_bare_insert(struct object_array_bare *array,
			      struct object *object)
{
	struct object_array_bare_item *e;

	ALLOC_GROW(array->objects, array->nr + 1, array->alloc);
	e = &array->objects[array->nr++];
	e->item = object;
}

void object_array_bare_clear(struct object_array_bare *array)
{
	FREE_AND_NULL(array->objects);
	array->nr = array->alloc = 0;
}
