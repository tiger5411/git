#ifndef OBJECT_QUEUE_H
#define OBJECT_QUEUE_H

/**
 * The "object_queue" API is a singly linked-list containing a "struct
 * object".
 *
 * Use the "struct object_array" API instead for a batch allocated
 * list of objects, use this API to consume a list of objects in FIFO
 * order, as mutation of the beginning of the list is O(1) here,
 * rather than "struct object_array"'s O(n).
 *
 * See walker_fetch() in walker.c (and the private loop() function)
 * for the canonical use of this API.
 */
struct object_queue {
	struct object *item;
	struct object_queue *next;
};

/**
 * Given a "struct object" allocate a new "struct object_queue" and
 * add it to the list.
 */
struct object_queue *object_queue_insert(struct object *item,
					 struct object_queue **list_p);

/**
 * Check if a given object is already in the queue, O(n).
 */
int object_queue_contains(struct object_queue *list, struct object *obj);

/**
 * Walk the queue and free() each item in it.
 */
void object_queue_free(struct object_queue **list);

#endif
