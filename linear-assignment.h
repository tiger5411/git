#ifndef LINEAR_ASSIGNMENT_H
#define LINEAR_ASSIGNMENT_H

/*
 * Compute an assignment of columns -> rows (and vice versa) such that every
 * column is assigned to at most one row (and vice versa) minimizing the
 * overall cost.
 *
 * The parameter `cost` is the cost matrix: the cost to assign column j to row
 * i is `cost[j + column_count * i].
 *
 * The arrays column2row and row2column will be populated with the respective
 * assignments (-1 for unassigned, which can happen only if column_count !=
 * row_count).
 */
void compute_assignment(size_t column_count, size_t row_count,
			int *cost,
			int *column2row, int *row2column);

/**
 * Get an overflow-proof offset into the "cost" array.
 */
static inline size_t cost_offset(const size_t column,
				 const size_t column_count, const size_t row)
{
	const size_t a = st_mult(column_count, row);
	const size_t b = st_add(column, a);

	return b;
}

/**
 * Convenience macro for doing the cost[] lookup using cost_offset().
 */
#define COST(column, row) cost[cost_offset((column), (column_count), (row))]

/* The maximal cost in the cost matrix (to prevent integer overflows). */
#define COST_MAX (1<<16)

#endif
