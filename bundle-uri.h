#ifndef BUNDLE_URI_H
#define BUNDLE_URI_H

struct repository;
struct packet_reader;
struct packet_writer;

/**
 * serve.[ch] API.
 */
int bundle_uri_advertise(struct repository *r, struct strbuf *value);
int bundle_uri_command(struct repository *r, struct packet_reader *request);

#endif /* BUNDLE_URI_H */
