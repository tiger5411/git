#include "cache.h"
#include "object.h"
#include "object-list.h"

void object_list_insert(struct object_list *array,
			struct object *object)
{
	struct object_list_item *e;

	ALLOC_GROW(array->objects, array->nr + 1, array->alloc);
	e = &array->objects[array->nr++];
	e->item = object;
}

void object_list_clear(struct object_list *array)
{
	FREE_AND_NULL(array->objects);
	array->nr = array->alloc = 0;
}
