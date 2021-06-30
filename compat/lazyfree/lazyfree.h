#ifndef LAZYFREE_H
#define LAZYFREE_H

#ifdef REPLACE_SYSTEM_ALLOCATOR
#define lazyfree free
#endif

extern void lazyfree(void *mem);

#endif
