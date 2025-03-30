#ifndef OpenSSLShim_h
#define OpenSSLShim_h

#include <OpenSSL/conf.h>
#include <OpenSSL/evp.h>
#include <OpenSSL/err.h>
#include <OpenSSL/bio.h>
#include <OpenSSL/x509.h>
#include <OpenSSL/cms.h>

#undef SSL_library_init
static inline void SSL_library_init(void) {
    OPENSSL_init_ssl(0, NULL);
}

#undef SSL_load_error_strings
static inline void SSL_load_error_strings(void) {
    OPENSSL_init_ssl(OPENSSL_INIT_LOAD_SSL_STRINGS \
                     | OPENSSL_INIT_LOAD_CRYPTO_STRINGS, NULL);
}

#undef OpenSSL_add_all_ciphers
static inline void OpenSSL_add_all_ciphers(void) {
    OPENSSL_init_crypto(OPENSSL_INIT_ADD_ALL_CIPHERS, NULL);
}

#undef OpenSSL_add_all_digests
static inline void OpenSSL_add_all_digests(void) {
    OPENSSL_init_crypto(OPENSSL_INIT_ADD_ALL_DIGESTS, NULL);
}

#undef OpenSSL_add_all_algorithms
static inline void OpenSSL_add_all_algorithms(void) {
    #ifdef OPENSSL_LOAD_CONF
    OPENSSL_add_all_algorithms_conf();
    #else
    OPENSSL_add_all_algorithms_noconf();
    #endif
}

#endif
