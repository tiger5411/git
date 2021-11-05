#ifndef FETCH_NEGOTIATOR_H
#define FETCH_NEGOTIATOR_H

struct commit;
struct repository;

/**
 * Our negotiation algorithm, this maps onto
 * fetch.negotiationAlgorithm and is used by fetch_negotiator_init()
 * below.
 */
enum fetch_negotiation_setting {
	FETCH_NEGOTIATION_DEFAULT,
	FETCH_NEGOTIATION_SKIPPING,
	FETCH_NEGOTIATION_NOOP,
};

/*
 * An object that supplies the information needed to negotiate the contents of
 * the to-be-sent packfile during a fetch.
 *
 * To set up the negotiator, call fetch_negotiator_init(), then known_common()
 * (0 or more times), then add_tip() (0 or more times).
 *
 * Then, when "have" lines are required, call next(). Call ack() to report what
 * the server tells us.
 *
 * Once negotiation is done, call release(). The negotiator then cannot be used
 * (unless reinitialized with fetch_negotiator_init()).
 */
struct fetch_negotiator {
	/*
	 * Before negotiation starts, indicate that the server is known to have
	 * this commit.
	 */
	void (*known_common)(struct fetch_negotiator *, struct commit *);

	/*
	 * Once this function is invoked, known_common() cannot be invoked any
	 * more.
	 *
	 * Set "known_common" to "known_common_BUG" in this callback
	 * to assert the invocation flow.
	 *
	 * Indicate that this commit and all its ancestors are to be checked
	 * for commonality with the server.
	 */
	void (*add_tip)(struct fetch_negotiator *, struct commit *);

	/*
	 * Once this function is invoked, known_common() and add_tip() cannot
	 * be invoked any more.
	 *
	 * Set "add_tip" to "add_tip_BUG" in this callback to assert
	 * the invocation flow, and "known_common" to
	 * "known_common_BUG" as noted for in add_tip() above.
	 *
	 * Return the next commit that the client should send as a "have" line.
	 */
	const struct object_id *(*next)(struct fetch_negotiator *);

	/*
	 * Inform the negotiator that the server has the given commit. This
	 * method must only be called on commits returned by next().
	 */
	int (*ack)(struct fetch_negotiator *, struct commit *);

	void (*release)(struct fetch_negotiator *);

	/* internal use */
	void *data;
};

/**
 * Takes a pointer to a "struct fetch_negotiator" to populate, and a
 * "enum fetch_negotiation_setting" indicating the backend to use.
 */
void fetch_negotiator_init(struct fetch_negotiator *negotiator,
			   enum fetch_negotiation_setting backend);

void known_common_BUG(struct fetch_negotiator *, struct commit *);
void add_tip_BUG(struct fetch_negotiator *, struct commit *);

#endif
