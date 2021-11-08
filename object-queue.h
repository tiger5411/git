#ifndef OBJECT_QUEUE_H
#define OBJECT_QUEUE_H

struct object_queue {
	struct object *item;
	struct object_queue *next;
};

struct object_queue *object_queue_insert(struct object *item,
					 struct object_queue **list_p);

int object_queue_contains(struct object_queue *list, struct object *obj);

void object_queue_free(struct object_queue **list);

#endif
