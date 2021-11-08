#include "cache.h"
#include "object-queue.h"

struct object_queue *object_queue_insert(struct object *item,
					 struct object_queue **list_p)
{
	struct object_queue *new_list = xmalloc(sizeof(struct object_queue));
	new_list->item = item;
	new_list->next = *list_p;
	*list_p = new_list;
	return new_list;
}

int object_queue_contains(struct object_queue *list, struct object *obj)
{
	while (list) {
		if (list->item == obj)
			return 1;
		list = list->next;
	}
	return 0;
}

void object_queue_free(struct object_queue **list)
{
	while (*list) {
		struct object_queue *p = *list;
		*list = p->next;
		free(p);
	}
}
