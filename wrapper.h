#ifndef WRAPPER_H
#define WRAPPER_H
 /*
  * Tries to unlink file.  Returns 0 if unlink succeeded
  * or the file already didn't exist.  Returns -1 and
  * appends a message to err suitable for
  * 'error("%s", err->buf)' on error.
  */
int unlink_or_msg(const char *file, struct strbuf *err);
#endif
