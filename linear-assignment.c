/*
 * Based on: Jonker, R., & Volgenant, A. (1987). <i>A shortest augmenting path
 * algorithm for dense and sparse linear assignment problems</i>. Computing,
 * 38(4), 325-340.
 */
#include "cache.h"
#include "linear-assignment.h"

static inline intmax_t cost_index(intmax_t *cost, intmax_t a, intmax_t b, intmax_t c)
{
	intmax_t r;

	if (INT_MULTIPLY_WRAPV(a, c, &r))
		die(_("integer overflow in cost[%"PRIuMAX" + %"PRIuMAX" * %"PRIuMAX"] multiplication"), b, a, c);
	if (INT_ADD_WRAPV(b, r, &r))
		die(_("integer overflow in cost[%"PRIuMAX" + ((%"PRIuMAX" * %"PRIuMAX") = %"PRIuMAX")] addition"), b, a, c, r);

	return r;
}

#define COST(column, row) cost[cost_index(cost, column_count, column, row)]

static void columns_reduction(size_t column_count, size_t row_count,
			      intmax_t *cost,
			      intmax_t *column2row, intmax_t *row2column,
			      intmax_t *v)
{
	intmax_t i, j;

	/* column reduction */
	for (j = column_count - 1; j >= 0; j--) {
		intmax_t i1 = 0;

		for (i = 1; i < row_count; i++)
			if (COST(j, i1) > COST(j, i))
				i1 = i;
		v[j] = COST(j, i1);
		if (row2column[i1] == -1) {
			/* row i1 unassigned */
			row2column[i1] = j;
			column2row[j] = i1;
		} else {
			if (row2column[i1] >= 0)
				row2column[i1] = -2 - row2column[i1];
			column2row[j] = -1;
		}
	}
}

static void reduction_transfer(size_t column_count, size_t row_count,
			       intmax_t *cost,
			       intmax_t *free_row, intmax_t *free_count,
			       intmax_t *column2row, intmax_t *row2column,
			       intmax_t *v)
{
	intmax_t i, j;

	/* reduction transfer */
	for (i = 0; i < row_count; i++) {
		intmax_t j1 = row2column[i];
		if (j1 == -1)
			free_row[(*free_count)++] = i;
		else if (j1 < -1)
			row2column[i] = -2 - j1;
		else {
			intmax_t min = COST(!j1, i) - v[!j1];
			for (j = 1; j < column_count; j++)
				if (j != j1 && min > COST(j, i) - v[j])
					min = COST(j, i) - v[j];
			v[j1] -= min;
		}
	}
}

static void augmenting_row_reduction(size_t column_count,
				     intmax_t *cost,
				     intmax_t *column2row, intmax_t *row2column,
				     intmax_t *free_row, intmax_t *free_count, intmax_t *saved_free_count,
				     intmax_t *v)
{
	int phase;

	/* augmenting row reduction */
	for (phase = 0; phase < 2; phase++) {
		intmax_t i;
		intmax_t k = 0;

		*saved_free_count = *free_count;
		*free_count = 0;
		while (k < *saved_free_count) {
			intmax_t j;
			intmax_t u1, u2;
			intmax_t j1 = 0, j2, i0;

			i = free_row[k++];
			u1 = COST(j1, i) - v[j1];
			j2 = -1;
			u2 = INTMAX_MAX;
			for (j = 1; j < column_count; j++) {
				intmax_t c = COST(j, i) - v[j];
				if (u2 > c) {
					if (u1 < c) {
						u2 = c;
						j2 = j;
					} else {
						u2 = u1;
						u1 = c;
						j2 = j1;
						j1 = j;
					}
				}
			}
			if (j2 < 0) {
				j2 = j1;
				u2 = u1;
			}

			i0 = column2row[j1];
			if (u1 < u2)
				v[j1] -= u2 - u1;
			else if (i0 >= 0) {
				j1 = j2;
				i0 = column2row[j1];
			}

			if (i0 >= 0) {
				if (u1 < u2)
					free_row[--k] = i0;
				else
					free_row[(*free_count)++] = i0;
			}
			row2column[i] = j1;
			column2row[j1] = i;
		}
	}
}

static void augmentation(size_t column_count,
			 intmax_t *cost,
			 intmax_t *column2row, intmax_t *row2column,
			 intmax_t *free_row, intmax_t free_count,
			 intmax_t *v)
{
	intmax_t i, j;
	intmax_t *d;
	intmax_t *pred, *col;
	intmax_t saved_free_count;

	/* augmentation */
	saved_free_count = free_count;
	ALLOC_ARRAY(d, column_count);
	ALLOC_ARRAY(pred, column_count);
	ALLOC_ARRAY(col, column_count);
	for (free_count = 0; free_count < saved_free_count; free_count++) {
		intmax_t i1 = free_row[free_count], low = 0, up = 0, last, k;
		intmax_t min, c, u1;

		for (j = 0; j < column_count; j++) {
			d[j] = COST(j, i1) - v[j];
			pred[j] = i1;
			col[j] = j;
		}

		j = -1;
		do {
			last = low;
			min = d[col[up++]];
			for (k = up; k < column_count; k++) {
				j = col[k];
				c = d[j];
				if (c <= min) {
					if (c < min) {
						up = low;
						min = c;
					}
					col[k] = col[up];
					col[up++] = j;
				}
			}
			for (k = low; k < up; k++)
				if (column2row[col[k]] == -1)
					goto update;

			/* scan a row */
			do {
				intmax_t j1 = col[low++];

				i = column2row[j1];
				u1 = COST(j1, i) - v[j1] - min;
				for (k = up; k < column_count; k++) {
					j = col[k];
					c = COST(j, i) - v[j] - u1;
					if (c < d[j]) {
						d[j] = c;
						pred[j] = i;
						if (c == min) {
							if (column2row[j] == -1)
								goto update;
							col[k] = col[up];
							col[up++] = j;
						}
					}
				}
			} while (low != up);
		} while (low == up);

update:
		/* updating of the column pieces */
		for (k = 0; k < last; k++) {
			intmax_t j1 = col[k];
			v[j1] += d[j1] - min;
		}

		/* augmentation */
		do {
			if (j < 0)
				BUG("negative j: %"PRIuMAX, j);
			i = pred[j];
			column2row[j] = i;
			SWAP(j, row2column[i]);
		} while (i1 != i);
	}

	free(col);
	free(pred);
	free(d);
}

/*
 * The parameter `cost` is the cost matrix: the cost to assign column j to row
 * i is `cost[j + column_count * i].
 */
void compute_assignment(size_t column_count, size_t row_count,
			intmax_t *cost,
			intmax_t *column2row, intmax_t *row2column)
{
	intmax_t *v;
	intmax_t *free_row, free_count = 0, saved_free_count;

	assert(column_count > 1);
	memset(column2row, -1, sizeof(intmax_t) * column_count);
	memset(row2column, -1, sizeof(intmax_t) * row_count);
	ALLOC_ARRAY(v, column_count);

	columns_reduction(column_count, row_count, cost, column2row,
			  row2column, v);

	ALLOC_ARRAY(free_row, row_count);
	reduction_transfer(column_count, row_count, cost, free_row,
			   &free_count, column2row, row2column, v);
	if (free_count ==
	    (column_count < row_count ? row_count - column_count : 0))
		goto cleanup;

	augmenting_row_reduction(column_count, cost, column2row,
				 row2column, free_row, &free_count,
				 &saved_free_count,v);

	augmentation(column_count, cost, column2row, row2column,
		     free_row, free_count, v);

cleanup:
	free(v);
	free(free_row);
}
