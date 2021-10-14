#ifndef SERVE_H
#define SERVE_H

void protocol_v2_advertise_capabilities(void);
int protocol_v2_request(void);
void protocol_v2_serve_loop(void);

#endif /* SERVE_H */
