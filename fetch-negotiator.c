#include "git-compat-util.h"
#include "fetch-negotiator.h"
#include "negotiator/default.h"
#include "negotiator/skipping.h"
#include "negotiator/noop.h"
#include "repository.h"

void fetch_negotiator_init(struct fetch_negotiator *negotiator,
			   enum fetch_negotiation_setting backend)

{
	switch (backend) {
	case FETCH_NEGOTIATION_SKIPPING:
		skipping_negotiator_init(negotiator);
		return;

	case FETCH_NEGOTIATION_NOOP:
		noop_negotiator_init(negotiator);
		return;

	case FETCH_NEGOTIATION_DEFAULT:
		default_negotiator_init(negotiator);
		return;
	}
}

void known_common_BUG(struct fetch_negotiator *negotiator,
		      struct object_id *oid)
{
	BUG("known_common() called after add_tip() and/or next() was called");
}

void add_tip_BUG(struct fetch_negotiator *negotiator, struct object_id *oid)
{
	BUG("add_tip() called after next() called");
}
