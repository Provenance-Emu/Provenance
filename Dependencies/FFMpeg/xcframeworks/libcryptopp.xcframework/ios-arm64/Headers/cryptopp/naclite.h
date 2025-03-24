// naclite.h - written and placed in the public domain by Jeffrey Walton
//          based on public domain NaCl source code written by
//          Daniel J. Bernstein, Bernard van Gastel, Wesley Janssen,
//          Tanja Lange, Peter Schwabe and Sjaak Smetsers.

// The Tweet API was added to the Crypto++ library to cross-validate results.
// We debated over putting it in the Test namespace, but settled for the NaCl
// namespace to segregate it from other parts of the library.

/// \file naclite.h
/// \brief Crypto++ interface to TweetNaCl library (20140917)
/// \details TweetNaCl is a compact reimplementation of the NaCl library
///   by Daniel J. Bernstein, Bernard van Gastel, Wesley Janssen, Tanja
///   Lange, Peter Schwabe and Sjaak Smetsers. The library is less than
///   20 KB in size and provides 25 of the NaCl library functions.
/// \details The compact library uses curve25519, XSalsa20, Poly1305 and
///   SHA-512 as default primitives, and includes both x25519 key exchange
///   and ed25519 signatures. The complete list of functions can be found
///   in <A
///   HREF="https://tweetnacl.cr.yp.to/tweetnacl-20140917.pdf">TweetNaCl:
///   A crypto library in 100 tweets</A> (20140917), Table 1, page 5.
/// \details Crypto++ rejects small order elements using libsodium's
///   blacklist. The TweetNaCl library allowed them but the library predated
///   the attack. If you wish to allow small elements then use the "unchecked"
///   versions of crypto_box_unchecked, crypto_box_open_unchecked and
///   crypto_box_beforenm_unchecked.
/// \details TweetNaCl is well written but not well optimzed. It runs about
///   10x slower than optimized routines from libsodium. However, the library
///   is still 2x to 4x faster than the algorithms NaCl was designed to replace
///   and allows cross-checking results from an independent implementation.
/// \details The Crypto++ wrapper for TweetNaCl requires OS features. That is,
///   <tt>NO_OS_DEPENDENCE</tt> cannot be defined. It is due to TweetNaCl's
///   internal function <tt>randombytes</tt>. Crypto++ used
///   <tt>DefaultAutoSeededRNG</tt> within <tt>randombytes</tt>, so OS
///   integration must be enabled. You can use another generator like
///   <tt>RDRAND</tt> to avoid the restriction.
/// \sa <A HREF="https://cr.yp.to/highspeed/coolnacl-20120725.pdf">The security
///   impact of a new cryptographic library</A>, <A
///   HREF="https://tweetnacl.cr.yp.to/tweetnacl-20140917.pdf">TweetNaCl:
///   A crypto library in 100 tweets</A> (20140917), <A
///   HREF="https://eprint.iacr.org/2017/806.pdf">May the Fourth Be With You:
///   A Microarchitectural Side Channel Attack on Several Real-World
///   Applications of Curve25519</A>, <A
///   HREF="https://github.com/jedisct1/libsodium/commit/afabd7e7386e1194">libsodium
///   commit afabd7e7386e1194</A> and <A
///   HREF="https://tools.ietf.org/html/rfc7748">RFC 7748, Elliptic Curves for
///   Security</A>, Section 6.
/// \since Crypto++ 6.0

#ifndef CRYPTOPP_NACL_H
#define CRYPTOPP_NACL_H

#include "config.h"
#include "stdcpp.h"

#if defined(NO_OS_DEPENDENCE) || !defined(OS_RNG_AVAILABLE)
# define CRYPTOPP_DISABLE_NACL 1
#endif

#ifndef CRYPTOPP_DISABLE_NACL

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(NaCl)

/// \brief Hash size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/hash.html">NaCl crypto_hash documentation</A>
CRYPTOPP_CONSTANT(crypto_hash_BYTES = 64);

/// \brief Key size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/stream.html">NaCl crypto_stream documentation</A>
CRYPTOPP_CONSTANT(crypto_stream_KEYBYTES = 32);
/// \brief Nonce size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/stream.html">NaCl crypto_stream documentation</A>
CRYPTOPP_CONSTANT(crypto_stream_NONCEBYTES = 24);

/// \brief Key size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/auth.html">NaCl crypto_auth documentation</A>
CRYPTOPP_CONSTANT(crypto_auth_KEYBYTES = 32);
/// \brief Tag size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/auth.html">NaCl crypto_auth documentation</A>
CRYPTOPP_CONSTANT(crypto_auth_BYTES = 16);

/// \brief Key size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/onetimeauth.html">NaCl crypto_onetimeauth documentation</A>
CRYPTOPP_CONSTANT(crypto_onetimeauth_KEYBYTES = 32);
/// \brief Tag size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/onetimeauth.html">NaCl crypto_onetimeauth documentation</A>
CRYPTOPP_CONSTANT(crypto_onetimeauth_BYTES = 16);

/// \brief Key size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/secretbox.html">NaCl crypto_secretbox documentation</A>
CRYPTOPP_CONSTANT(crypto_secretbox_KEYBYTES = 32);
/// \brief Nonce size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/secretbox.html">NaCl crypto_secretbox documentation</A>
CRYPTOPP_CONSTANT(crypto_secretbox_NONCEBYTES = 24);
/// \brief Zero-padded message prefix in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/secretbox.html">NaCl crypto_secretbox documentation</A>
CRYPTOPP_CONSTANT(crypto_secretbox_ZEROBYTES = 32);
/// \brief Zero-padded message prefix in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/secretbox.html">NaCl crypto_secretbox documentation</A>
CRYPTOPP_CONSTANT(crypto_secretbox_BOXZEROBYTES = 16);

/// \brief Private key size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
CRYPTOPP_CONSTANT(crypto_box_SECRETKEYBYTES = 32);
/// \brief Public key size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
CRYPTOPP_CONSTANT(crypto_box_PUBLICKEYBYTES = 32);
/// \brief Nonce size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
CRYPTOPP_CONSTANT(crypto_box_NONCEBYTES = 24);
/// \brief Message 0-byte prefix in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
CRYPTOPP_CONSTANT(crypto_box_ZEROBYTES = 32);
/// \brief Open box 0-byte prefix in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
CRYPTOPP_CONSTANT(crypto_box_BOXZEROBYTES = 16);
/// \brief Precomputation 0-byte prefix in bytes in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
CRYPTOPP_CONSTANT(crypto_box_BEFORENMBYTES = 32);
/// \brief MAC size in bytes
/// \details crypto_box_MACBYTES was missing from tweetnacl.h. Its is defined as
///   crypto_box_curve25519xsalsa20poly1305_MACBYTES, which is defined as 16U.
/// \sa <A HREF="https://nacl.cr.yp.to/hash.html">NaCl crypto_box documentation</A>
CRYPTOPP_CONSTANT(crypto_box_MACBYTES = 16);

/// \brief Private key size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/sign.html">NaCl crypto_sign documentation</A>
CRYPTOPP_CONSTANT(crypto_sign_SECRETKEYBYTES = 64);
/// \brief Public key size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/sign.html">NaCl crypto_sign documentation</A>
CRYPTOPP_CONSTANT(crypto_sign_PUBLICKEYBYTES = 32);
/// \brief Seed size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/sign.html">NaCl crypto_sign documentation</A>
CRYPTOPP_CONSTANT(crypto_sign_SEEDBYTES = 32);
/// \brief Signature size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/sign.html">NaCl crypto_sign documentation</A>
CRYPTOPP_CONSTANT(crypto_sign_BYTES = 64);

/// \brief Group element size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/scalarmult.html">NaCl crypto_scalarmult documentation</A>
CRYPTOPP_CONSTANT(crypto_scalarmult_BYTES = 32);
/// \brief Integer size in bytes
/// \sa <A HREF="https://nacl.cr.yp.to/scalarmult.html">NaCl crypto_scalarmult documentation</A>
CRYPTOPP_CONSTANT(crypto_scalarmult_SCALARBYTES = 32);

/// \brief Encrypt and authenticate a message
/// \param c output byte buffer
/// \param m input byte buffer
/// \param d size of the input byte buffer
/// \param n nonce byte buffer
/// \param y other's public key
/// \param x private key
/// \details crypto_box() uses crypto_box_curve25519xsalsa20poly1305
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
/// \since Crypto++ 6.0
int crypto_box(byte *c,const byte *m,word64 d,const byte *n,const byte *y,const byte *x);

/// \brief Verify and decrypt a message
/// \param m output byte buffer
/// \param c input byte buffer
/// \param d size of the input byte buffer
/// \param n nonce byte buffer
/// \param y other's public key
/// \param x private key
/// \details crypto_box_open() uses crypto_box_curve25519xsalsa20poly1305
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
/// \since Crypto++ 6.0
int crypto_box_open(byte *m,const byte *c,word64 d,const byte *n,const byte *y,const byte *x);

/// \brief Generate a keypair for encryption
/// \param y public key byte buffer
/// \param x private key byte buffer
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
/// \since Crypto++ 6.0
int crypto_box_keypair(byte *y,byte *x);

/// \brief Encrypt and authenticate a message
/// \param k shared secret byte buffer
/// \param y other's public key
/// \param x private key
/// \details crypto_box_beforenm() performs message-independent precomputation to derive the key.
///   Once the key is derived multiple calls to crypto_box_afternm() can be made to process the message.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
/// \since Crypto++ 6.0
int crypto_box_beforenm(byte *k,const byte *y,const byte *x);

/// \brief Encrypt and authenticate a message
/// \param m output byte buffer
/// \param c input byte buffer
/// \param d size of the input byte buffer
/// \param n nonce byte buffer
/// \param k shared secret byte buffer
/// \details crypto_box_afternm() performs message-dependent computation using the derived the key.
///   Once the key is derived using crypto_box_beforenm() multiple calls to crypto_box_afternm()
///   can be made to process the message.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
/// \since Crypto++ 6.0
int crypto_box_afternm(byte *c,const byte *m,word64 d,const byte *n,const byte *k);

/// \brief Verify and decrypt a message
/// \param m output byte buffer
/// \param c input byte buffer
/// \param d size of the input byte buffer
/// \param n nonce byte buffer
/// \param k shared secret byte buffer
/// \details crypto_box_afternm() performs message-dependent computation using the derived the key.
///   Once the key is derived using crypto_box_beforenm() multiple calls to crypto_box_open_afternm()
///   can be made to process the message.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>
/// \since Crypto++ 6.0
int crypto_box_open_afternm(byte *m,const byte *c,word64 d,const byte *n,const byte *k);

/// \brief Encrypt and authenticate a message
/// \param c output byte buffer
/// \param m input byte buffer
/// \param d size of the input byte buffer
/// \param n nonce byte buffer
/// \param y other's public key
/// \param x private key
/// \details crypto_box() uses crypto_box_curve25519xsalsa20poly1305.
/// \details This version of crypto_box() does not check for small order elements. It can be unsafe
///   but it exists for backwards compatibility with downlevel clients. Without the compatibility
///   interop with early versions of NaCl, libsodium and other libraries does not exist. The
///   downlevel interop may also be needed of cryptocurrencies like Bitcoin, Ethereum, Monero
///   and Zcash.
/// \return 0 on success, non-0 otherwise
/// \warning This version of crypto_box() does not check for small order elements. It should not
///   be used in new software.
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>,
///   <A HREF="https://eprint.iacr.org/2017/806.pdf">May the Fourth Be With You: A Microarchitectural
///   Side Channel Attack on Several Real-World Applications of Curve25519</A>,
///   <A HREF="https://github.com/jedisct1/libsodium/commit/afabd7e7386e1194">libsodium commit
///   afabd7e7386e1194</A>.
/// \since Crypto++ 6.0
int crypto_box_unchecked(byte *c,const byte *m,word64 d,const byte *n,const byte *y,const byte *x);

/// \brief Verify and decrypt a message
/// \param m output byte buffer
/// \param c input byte buffer
/// \param d size of the input byte buffer
/// \param n nonce byte buffer
/// \param y other's public key
/// \param x private key
/// \details crypto_box_open() uses crypto_box_curve25519xsalsa20poly1305.
/// \details This version of crypto_box_open() does not check for small order elements. It can be unsafe
///   but it exists for backwards compatibility with downlevel clients. Without the compatibility
///   interop with early versions of NaCl, libsodium and other libraries does not exist. The
///   downlevel interop may also be needed of cryptocurrencies like Bitcoin, Ethereum, Monero
///   and Zcash.
/// \return 0 on success, non-0 otherwise
/// \warning This version of crypto_box_open() does not check for small order elements. It should not
///   be used in new software.
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>,
///   <A HREF="https://eprint.iacr.org/2017/806.pdf">May the Fourth Be With You: A Microarchitectural
///   Side Channel Attack on Several Real-World Applications of Curve25519</A>,
///   <A HREF="https://github.com/jedisct1/libsodium/commit/afabd7e7386e1194">libsodium commit
///   afabd7e7386e1194</A>.
/// \since Crypto++ 6.0
int crypto_box_open_unchecked(byte *m,const byte *c,word64 d,const byte *n,const byte *y,const byte *x);

/// \brief Encrypt and authenticate a message
/// \param k shared secret byte buffer
/// \param y other's public key
/// \param x private key
/// \details crypto_box_beforenm() performs message-independent precomputation to derive the key.
///   Once the key is derived multiple calls to crypto_box_afternm() can be made to process the message.
/// \details This version of crypto_box_beforenm() does not check for small order elements. It can be unsafe
///   but it exists for backwards compatibility with downlevel clients. Without the compatibility
///   interop with early versions of NaCl, libsodium and other libraries does not exist. The
///   downlevel interop may also be needed of cryptocurrencies like Bitcoin, Ethereum, Monero
///   and Zcash.
/// \return 0 on success, non-0 otherwise
/// \warning This version of crypto_box_beforenm() does not check for small order elements. It should not
///   be used in new software.
/// \sa <A HREF="https://nacl.cr.yp.to/box.html">NaCl crypto_box documentation</A>,
///   <A HREF="https://eprint.iacr.org/2017/806.pdf">May the Fourth Be With You: A Microarchitectural
///   Side Channel Attack on Several Real-World Applications of Curve25519</A>,
///   <A HREF="https://github.com/jedisct1/libsodium/commit/afabd7e7386e1194">libsodium commit
///   afabd7e7386e1194</A>.
/// \since Crypto++ 6.0
int crypto_box_beforenm_unchecked(byte *k,const byte *y,const byte *x);

/// \brief TODO
int crypto_core_salsa20(byte *out,const byte *in,const byte *k,const byte *c);

/// \brief TODO
/// \return 0 on success, non-0 otherwise
/// \since Crypto++ 6.0
int crypto_core_hsalsa20(byte *out,const byte *in,const byte *k,const byte *c);

/// \brief Hash multiple blocks
/// \details crypto_hashblocks() uses crypto_hashblocks_sha512.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/hash.html">NaCl crypto_hash documentation</A>
/// \since Crypto++ 6.0
int crypto_hashblocks(byte *x,const byte *m,word64 n);

/// \brief Hash a message
/// \details crypto_hash() uses crypto_hash_sha512.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/hash.html">NaCl crypto_hash documentation</A>
/// \since Crypto++ 6.0
int crypto_hash(byte *out,const byte *m,word64 n);

/// \brief Create an authentication tag for a message
/// \details crypto_onetimeauth() uses crypto_onetimeauth_poly1305.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/onetimeauth.html">NaCl crypto_onetimeauth documentation</A>
/// \since Crypto++ 6.0
int crypto_onetimeauth(byte *out,const byte *m,word64 n,const byte *k);

/// \brief Verify an authentication tag on a message
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/onetimeauth.html">NaCl crypto_onetimeauth documentation</A>
/// \since Crypto++ 6.0
int crypto_onetimeauth_verify(const byte *h,const byte *m,word64 n,const byte *k);

/// \brief Scalar multiplication of a point
/// \details crypto_scalarmult() uses crypto_scalarmult_curve25519
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/scalarmult.html">NaCl crypto_scalarmult documentation</A>
/// \since Crypto++ 6.0
int crypto_scalarmult(byte *q,const byte *n,const byte *p);

/// \brief Scalar multiplication of base point
/// \details crypto_scalarmult_base() uses crypto_scalarmult_curve25519
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/scalarmult.html">NaCl crypto_scalarmult documentation</A>
/// \since Crypto++ 6.0
int crypto_scalarmult_base(byte *q,const byte *n);

/// \brief Encrypt and authenticate a message
/// \details crypto_secretbox() uses a symmetric key to encrypt and authenticate a message.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/secretbox.html">NaCl crypto_secretbox documentation</A>
/// \since Crypto++ 6.0
int crypto_secretbox(byte *c,const byte *m,word64 d,const byte *n,const byte *k);

/// \brief Verify and decrypt a message
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/secretbox.html">NaCl crypto_secretbox documentation</A>
/// \since Crypto++ 6.0
int crypto_secretbox_open(byte *m,const byte *c,word64 d,const byte *n,const byte *k);

/// \brief Sign a message
/// \param sm output byte buffer
/// \param smlen size of the output byte buffer
/// \param m input byte buffer
/// \param n size of the input byte buffer
/// \param sk private key
/// \details crypto_sign() uses crypto_sign_ed25519.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/sign.html">NaCl crypto_sign documentation</A>
/// \since Crypto++ 6.0
int crypto_sign(byte *sm,word64 *smlen,const byte *m,word64 n,const byte *sk);

/// \brief Verify a message
/// \param m output byte buffer
/// \param mlen size of the output byte buffer
/// \param sm input byte buffer
/// \param n size of the input byte buffer
/// \param pk public key
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/sign.html">NaCl crypto_sign documentation</A>
/// \since Crypto++ 6.0
int crypto_sign_open(byte *m,word64 *mlen,const byte *sm,word64 n,const byte *pk);

/// \brief Generate a keypair for signing
/// \param pk public key byte buffer
/// \param sk private key byte buffer
/// \details crypto_sign_keypair() creates an ed25519 keypair.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/sign.html">NaCl crypto_sign documentation</A>
/// \since Crypto++ 6.0
int crypto_sign_keypair(byte *pk, byte *sk);

/// \brief Calculate a public key from a secret key
/// \param pk public key byte buffer
/// \param sk private key byte buffer
/// \details crypto_sign_sk2pk() creates an ed25519 public key from an existing
///   32-byte secret key. The function does not backfill the tail bytes of the
///   secret key with the calculated public key.
/// \details crypto_sign_sk2pk() is not part of libsodium or Tweet API. It was
///   added for interop with some anonymous routing protocols.
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/sign.html">NaCl crypto_sign documentation</A>
/// \since Crypto++ 8.0
int crypto_sign_sk2pk(byte *pk, const byte *sk);

/// \brief Produce a keystream using XSalsa20
/// \details crypto_stream() uses crypto_stream_xsalsa20
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/stream.html">NaCl crypto_stream documentation</A>
/// \since Crypto++ 6.0
int crypto_stream(byte *c,word64 d,const byte *n,const byte *k);

/// \brief Encrypt a message using XSalsa20
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/stream.html">NaCl crypto_stream documentation</A>
/// \since Crypto++ 6.0
int crypto_stream_xor(byte *c,const byte *m,word64 d,const byte *n,const byte *k);

/// \brief Produce a keystream using Salsa20
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/stream.html">NaCl crypto_stream documentation</A>
/// \since Crypto++ 6.0
int crypto_stream_salsa20(byte *c,word64 d,const byte *n,const byte *k);

/// \brief Encrypt a message using Salsa20
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/stream.html">NaCl crypto_stream documentation</A>
/// \since Crypto++ 6.0
int crypto_stream_salsa20_xor(byte *c,const byte *m,word64 b,const byte *n,const byte *k);

/// \brief Compare 16-byte buffers
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/verify.html">NaCl crypto_verify documentation</A>
/// \since Crypto++ 6.0
int crypto_verify_16(const byte *x,const byte *y);

/// \brief Compare 32-byte buffers
/// \return 0 on success, non-0 otherwise
/// \sa <A HREF="https://nacl.cr.yp.to/verify.html">NaCl crypto_verify documentation</A>
/// \since Crypto++ 6.0
int crypto_verify_32(const byte *x,const byte *y);

NAMESPACE_END  // CryptoPP
NAMESPACE_END  // NaCl

#endif  // CRYPTOPP_DISABLE_NACL
#endif  // CRYPTOPP_NACL_H
