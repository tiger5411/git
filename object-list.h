#ifndef OBJECT_LIST_H
#define OBJECT_LIST_H

struct object_list {
	struct object *item;
	struct object_list *next;
};

struct object_list *object_list_insert(struct object *item,
				       struct object_list **list_p);

int object_list_contains(struct object_list *list, struct object *obj);

void object_list_free(struct object_list **list);

#endif
