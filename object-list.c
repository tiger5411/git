#include "cache.h"
#include "object-list.h"

struct object_list *object_list_insert(struct object *item,
				       struct object_list **list_p)
{
	struct object_list *new_list = xmalloc(sizeof(struct object_list));
	new_list->item = item;
	new_list->next = *list_p;
	*list_p = new_list;
	return new_list;
}

int object_list_contains(struct object_list *list, struct object *obj)
{
	while (list) {
		if (list->item == obj)
			return 1;
		list = list->next;
	}
	return 0;
}

void object_list_free(struct object_list **list)
{
	while (*list) {
		struct object_list *p = *list;
		*list = p->next;
		free(p);
	}
}
