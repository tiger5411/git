#ifndef BUNDLE_URI_H
#define BUNDLE_URI_H
#include "repository.h"
#include "pkt-line.h"
#include "strbuf.h"

/**
 * API used by serve.[ch].
 */
int bundle_uri_advertise(struct repository *r, struct strbuf *value);
int bundle_uri_command(struct repository *r, struct packet_reader *request);

#endif /* BUNDLE_URI_H */
