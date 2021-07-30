#ifndef GIT_CURL_COMPAT_H
#define GIT_CURL_COMPAT_H

/**
 * This header centralizes the declaration of our libcurl dependencies
 * to make it easy to discover the oldest versions we support, and to
 * inform decisions about removing support for older libcurl in the
 * future.
 *
 * The source of truth for what versions have which symbols is
 * https://github.com/curl/curl/blob/master/docs/libcurl/symbols-in-versions;
 * the release dates are taken from curl.git (at
 * https://github.com/curl/curl/).
 *
 * For each X symbol we need from curl we check if it exists and
 * declare our own GIT_CURL_HAVE_X, or if it's for both X and Y
 * GIT_CURL_HAVE_X_and_Y, where the "Y" in "X_and_Y" is only the part
 * of the symbol name that "X" and "Y" don't have in common.
 *
 * We avoid comparisons against LIBCURL_VERSION_NUM, enterprise
 * distros have been known to backport symbols to their older curl
 * versions.
 *
 * Keep any symbols in date order of when their support was
 * introduced, oldest first, in the official version of cURL library.
 */

/**
 * CURLOPT_TCP_KEEPALIVE was added in 7.25.0, released in March 2012.
 */
#ifdef CURLOPT_TCP_KEEPALIVE
#define GITCURL_HAVE_CURLOPT_TCP_KEEPALIVE 1
#endif


/**
 * CURLOPT_LOGIN_OPTIONS was added in 7.34.0, released in December
 * 2013.
 */
#ifdef CURLOPT_LOGIN_OPTIONS
#define GIT_CURL_HAVE_CURLOPT_LOGIN_OPTIONS 1
#endif

/**
 * CURL_SSLVERSION_TLSv1_[012] was added in 7.34.0, released in
 * December 2013.
 */
#if defined(CURL_SSLVERSION_TLSv1_0) && \
    defined(CURL_SSLVERSION_TLSv1_1) && \
    defined(CURL_SSLVERSION_TLSv1_2)
#define GIT_CURL_HAVE_CURL_SSLVERSION_TLSv1_0_and_1_and_2
#endif

/**
 * CURLOPT_PINNEDPUBLICKEY was added in 7.39.0, released in November
 * 2014.
 */
#ifdef CURLOPT_PINNEDPUBLICKEY
#define GIT_CURL_HAVE_CURLOPT_PINNEDPUBLICKEY 1
#endif

/**
 * CURL_HTTP_VERSION_2 was added in 7.43.0, released in June 2015.
 */
#ifdef CURL_HTTP_VERSION_2
#define GIT_CURL_HAVE_CURL_HTTP_VERSION_2 1
#endif

/**
 * CURLSSLOPT_NO_REVOKE was added in 7.44.0, released in August 2015.
 */
#ifdef CURLSSLOPT_NO_REVOKE
#define GIT_CURL_HAVE_CURLSSLOPT_NO_REVOKE 1
#endif

/**
 * CURLOPT_PROXY_CAINFO was added in 7.52.0, released in August 2017.
 */
#ifdef CURLOPT_PROXY_CAINFO
#define GIT_CURL_HAVE_CURLOPT_PROXY_CAINFO 1
#endif

/**
 * CURLOPT_PROXY_{KEYPASSWD,SSLCERT,SSLKEY} was added in 7.52.0,
 * released in August 2017.
 */
#if defined(CURLOPT_PROXY_KEYPASSWD) && \
    defined(CURLOPT_PROXY_SSLCERT) && \
    defined(CURLOPT_PROXY_SSLKEY)
#define GIT_CURL_HAVE_CURLOPT_PROXY_KEYPASSWD_and_SSLCERT_and_SSLKEY 1
#endif

/**
 * CURL_SSLVERSION_TLSv1_3 was added in 7.53.0, released in February
 * 2017.
 */
#ifdef CURL_SSLVERSION_TLSv1_3
#define GIT_CURL_HAVE_CURL_SSLVERSION_TLSv1_3 1
#endif

/**
 * CURLSSLSET_{NO_BACKENDS,OK,TOO_LATE,UNKNOWN_BACKEND} were added in
 * 7.56.0, released in September 2017.
 */
#if defined(CURLSSLSET_NO_BACKENDS) && \
    defined(CURLSSLSET_OK) && \
    defined(CURLSSLSET_TOO_LATE) && \
    defined(CURLSSLSET_UNKNOWN_BACKEND)
#define GIT_CURL_HAVE_CURLSSLSET_NO_BACKENDS_and_OK_and_TOO_LATE_and_UNKNOWN_BACKEND 1
#endif

#endif
