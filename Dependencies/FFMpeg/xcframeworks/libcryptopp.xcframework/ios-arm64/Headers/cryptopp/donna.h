// donna.h - written and placed in public domain by Jeffrey Walton
//           Crypto++ specific implementation wrapped around Andrew
//           Moon's public domain curve25519-donna and ed25519-donna,
//           https://github.com/floodyberry/curve25519-donna and
//           https://github.com/floodyberry/ed25519-donna.

// The curve25519 and ed25519 source files multiplex different repos and
// architectures using namespaces. The repos are Andrew Moon's
// curve25519-donna and ed25519-donna. The architectures are 32-bit, 64-bit
// and SSE. For example, 32-bit x25519 uses symbols from Donna::X25519 and
// Donna::Arch32.

// If needed, see Moon's commit "Go back to ignoring 256th bit [sic]",
// https://github.com/floodyberry/curve25519-donna/commit/57a683d18721a658

/// \file donna.h
/// \details Functions for curve25519 and ed25519 operations
/// \details This header provides the entry points into Andrew Moon's
///   curve25519 and ed25519 curve functions. The Crypto++ classes x25519
///   and ed25519 use the functions. The functions are in the <tt>Donna</tt>
///   namespace and are curve25519_mult(), ed25519_publickey(),
///   ed25519_sign() and ed25519_sign_open().
/// \details At the moment the hash function for signing is fixed at
///   SHA512.

#ifndef CRYPTOPP_DONNA_H
#define CRYPTOPP_DONNA_H

#include "config.h"
#include "cryptlib.h"
#include "stdcpp.h"

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(Donna)

//***************************** curve25519 *****************************//

/// \brief Generate a public key
/// \param publicKey byte array for the public key
/// \param secretKey byte array with the private key
/// \return 0 on success, non-0 otherwise
/// \details curve25519_mult() generates a public key from an existing
///   secret key. Internally curve25519_mult() performs a scalar
///   multiplication using the base point and writes the result to
///   <tt>pubkey</tt>.
int curve25519_mult(byte publicKey[32], const byte secretKey[32]);

/// \brief Generate a shared key
/// \param sharedKey byte array for the shared secret
/// \param secretKey byte array with the private key
/// \param othersKey byte array with the peer's public key
/// \return 0 on success, non-0 otherwise
/// \details curve25519_mult() generates a shared key from an existing
///   secret key and the other party's public key. Internally
///   curve25519_mult() performs a scalar multiplication using the two keys
///   and writes the result to <tt>sharedKey</tt>.
int curve25519_mult(byte sharedKey[32], const byte secretKey[32], const byte othersKey[32]);

//******************************* ed25519 *******************************//

/// \brief Creates a public key from a secret key
/// \param publicKey byte array for the public key
/// \param secretKey byte array with the private key
/// \return 0 on success, non-0 otherwise
/// \details ed25519_publickey() generates a public key from a secret key.
///   Internally ed25519_publickey() performs a scalar multiplication
///   using the secret key and then writes the result to <tt>publicKey</tt>.
int ed25519_publickey(byte publicKey[32], const byte secretKey[32]);

/// \brief Creates a signature on a message
/// \param message byte array with the message
/// \param messageLength size of the message, in bytes
/// \param publicKey byte array with the public key
/// \param secretKey byte array with the private key
/// \param signature byte array for the signature
/// \return 0 on success, non-0 otherwise
/// \details ed25519_sign() generates a signature on a message using
///   the public and private keys. The various buffers can be exact
///   sizes, and do not require extra space like when using the
///   NaCl library functions.
/// \details At the moment the hash function for signing is fixed at
///   SHA512.
int ed25519_sign(const byte* message, size_t messageLength, const byte secretKey[32], const byte publicKey[32], byte signature[64]);

/// \brief Creates a signature on a message
/// \param stream std::istream derived class
/// \param publicKey byte array with the public key
/// \param secretKey byte array with the private key
/// \param signature byte array for the signature
/// \return 0 on success, non-0 otherwise
/// \details ed25519_sign() generates a signature on a message using
///   the public and private keys. The various buffers can be exact
///   sizes, and do not require extra space like when using the
///   NaCl library functions.
/// \details This ed25519_sign() overload handles large streams. It
///   was added for signing and verifying files that are too large
///   for a memory allocation.
/// \details At the moment the hash function for signing is fixed at
///   SHA512.
int ed25519_sign(std::istream& stream, const byte secretKey[32], const byte publicKey[32], byte signature[64]);

/// \brief Verifies a signature on a message
/// \param message byte array with the message
/// \param messageLength size of the message, in bytes
/// \param publicKey byte array with the public key
/// \param signature byte array with the signature
/// \return 0 on success, non-0 otherwise
/// \details ed25519_sign_open() verifies a signature on a message using
///   the public key. The various buffers can be exact sizes, and do not
///   require extra space like when using the NaCl library functions.
/// \details At the moment the hash function for signing is fixed at
///   SHA512.
int
ed25519_sign_open(const byte *message, size_t messageLength, const byte publicKey[32], const byte signature[64]);

/// \brief Verifies a signature on a message
/// \param stream std::istream derived class
/// \param publicKey byte array with the public key
/// \param signature byte array with the signature
/// \return 0 on success, non-0 otherwise
/// \details ed25519_sign_open() verifies a signature on a message using
///   the public key. The various buffers can be exact sizes, and do not
///   require extra space like when using the NaCl library functions.
/// \details This ed25519_sign_open() overload handles large streams. It
///   was added for signing and verifying files that are too large
///   for a memory allocation.
/// \details At the moment the hash function for signing is fixed at
///   SHA512.
int
ed25519_sign_open(std::istream& stream, const byte publicKey[32], const byte signature[64]);

//****************************** Internal ******************************//

#ifndef CRYPTOPP_DOXYGEN_PROCESSING

// CRYPTOPP_WORD128_AVAILABLE mostly depends upon GCC support for
// __SIZEOF_INT128__. If __SIZEOF_INT128__ is not available then Moon
// provides routines for MSC and GCC. It should cover most platforms,
// but there are gaps like MS ARM64 and XLC. We tried to enable the
// 64-bit path for SunCC from 12.5 but we got the dreaded compile
// error "The operand ___LCM cannot be assigned to".

#if defined(CRYPTOPP_WORD128_AVAILABLE) || \
   (defined(CRYPTOPP_MSC_VERSION) && defined(_M_X64))
# define CRYPTOPP_CURVE25519_64BIT 1
#else
# define CRYPTOPP_CURVE25519_32BIT 1
#endif

// Benchmarking on a modern 64-bit Core i5-6400 @2.7 GHz shows SSE2 on Linux
// is not profitable. Here are the numbers in milliseconds/operation:
//
//   * Langley, C++, 0.050
//   * Moon, C++: 0.040
//   * Moon, SSE2: 0.061
//   * Moon, native: 0.045
//
// However, a modern 64-bit Core i5-3200 @2.5 GHz shows SSE2 is profitable
// for MS compilers. Here are the numbers in milliseconds/operation:
//
//   * x86, no SSE2, 0.294
//   * x86, SSE2, 0.097
//   * x64, no SSE2, 0.081
//   * x64, SSE2, 0.071

#if defined(CRYPTOPP_MSC_VERSION) && (CRYPTOPP_SSE2_INTRIN_AVAILABLE)
# define CRYPTOPP_CURVE25519_SSE2 1
#endif

#if (CRYPTOPP_CURVE25519_SSE2)
  extern int curve25519_mult_SSE2(byte sharedKey[32], const byte secretKey[32], const byte othersKey[32]);
#endif

#endif  // CRYPTOPP_DOXYGEN_PROCESSING

NAMESPACE_END  // Donna
NAMESPACE_END  // CryptoPP

#endif  // CRYPTOPP_DONNA_H
