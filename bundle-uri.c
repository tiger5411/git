#include "cache.h"
#include "repository.h"
#include "pkt-line.h"
#include "bundle-uri.h"

static int advertise_bundle_uri;

int bundle_uri_configure(const char *var, const char *value, void *data)
{
	if (!strcmp("uploadpack.bundleuri", var))
		advertise_bundle_uri = 1;
	return 0;
}

int bundle_uri_advertise(struct repository *r, struct strbuf *value)
{
	return advertise_bundle_uri;
}

int bundle_uri(struct repository *r, struct strvec *keys,
		struct packet_reader *request)
{
	packet_flush(1);
	return 0;
}
