#ifndef UNPACK_TREES_H
#define UNPACK_TREES_H

#define MAX_UNPACK_TREES 8

struct unpack_trees_options;
struct exclude_list;

typedef int (*merge_fn_t)(struct cache_entry **src,
		struct unpack_trees_options *options);

enum unpack_trees_error_types {
	would_overwrite = 0,
	not_uptodate_file,
	not_uptodate_dir,
	would_lose_untracked_overwritten,
	would_lose_untracked_removed,
	bind_overlap,
	sparse_not_uptodate_file,
	would_lose_orphaned_overwritten,
	would_lose_orphaned_removed,
	NB_UNPACK_TREES_ERROR_TYPES
};

struct unpack_trees_options {
	unsigned int reset,
		     merge,
		     update,
		     index_only,
		     nontrivial_merge,
		     trivial_merges_only,
		     verbose_update,
		     aggressive,
		     skip_unmerged,
		     initial_checkout,
		     diff_index_cached,
		     debug_unpack,
		     skip_sparse_checkout,
		     gently;
	const char *prefix;
	int cache_bottom;
	struct dir_struct *dir;
	merge_fn_t fn;
	const char *msgs[NB_UNPACK_TREES_ERROR_TYPES];

	int head_idx;
	int merge_size;

	struct cache_entry *df_conflict_entry;
	void *unpack_data;

	struct index_state *dst_index;
	struct index_state *src_index;
	struct index_state result;

	struct exclude_list *el; /* for internal use */
};

extern int unpack_trees(unsigned n, struct tree_desc *t,
		struct unpack_trees_options *options);

int threeway_merge(struct cache_entry **stages, struct unpack_trees_options *o);
int twoway_merge(struct cache_entry **src, struct unpack_trees_options *o);
int bind_merge(struct cache_entry **src, struct unpack_trees_options *o);
int oneway_merge(struct cache_entry **src, struct unpack_trees_options *o);

#endif
