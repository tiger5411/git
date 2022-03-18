#ifndef LINEAR_ASSIGNMENT_H
#define LINEAR_ASSIGNMENT_H

/**
 * Compute an assignment of columns -> rows (and vice versa) such that every
 * column is assigned to at most one row (and vice versa) minimizing the
 * overall cost.
 *
 * The parameter `cost` is the cost matrix: the cost to assign column j to row
 * i is `COST(i, j)`, which is an overflow-safe way of referring to
 * `cost[j + column_count * i]`. The `column_count` variable being defined
 * in the function that invokes it.
 *
 * The arrays column2row and row2column will be populated with the respective
 * assignments (-1 for unassigned, which can happen only if column_count !=
 * row_count).
 */
void compute_assignment(int column_count, int row_count, int *cost,
			int *column2row, int *row2column);

/**
 * The COST() macro computes the offset into the `cost` array, as
 * discussed for compute_assignment() above. Even though `column`,
 * `row` and the `column_count` variables may be `int` the offset into
 * the `int *` array might still exceed what `int` can represent on
 * the platform. This does the offset calculation with the
 * size_t-casting `st_add()` and `st_mult()` helpers.
 */
#define COST(column, row) cost[st_add((column),st_mult((column_count), (row)))]

/**
 * COST_MAX is the maximal cost *value* in the cost matrix, this
 * prevents integer overflows (assuming at least 32 bit integers) in
 * computations involving the cost value in the cost matrix, as
 * opposed to the COST() macro, which computes cost offsets.
 */
#define COST_MAX (1<<16)

#endif
