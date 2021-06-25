#ifndef BUNDLE_URI_H
#define BUNDLE_URI_H

struct repository;
struct strvec;
struct packet_reader;
int bundle_uri_configure(const char *var, const char *value, void *data);
int bundle_uri_advertise(struct repository *r, struct strbuf *value);
int bundle_uri(struct repository *r, struct strvec *keys,
	       struct packet_reader *request);
#endif /* BUNDLE_URI_H */
