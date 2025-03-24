// hashfwd.h - written and placed in the public domain by Jeffrey Walton

/// \file hashfwd.h
/// \brief Forward declarations for hash functions used in signature encoding methods

#ifndef CRYPTOPP_HASHFWD_H
#define CRYPTOPP_HASHFWD_H

#include "config.h"

NAMESPACE_BEGIN(CryptoPP)

class SHA1;
class SHA224;
class SHA256;
class SHA384;
class SHA512;

class SHA3_256;
class SHA3_384;
class SHA3_512;

class SHAKE128;
class SHAKE256;

class Tiger;
class RIPEMD128;
class RIPEMD160;
class Whirlpool;

namespace Weak1 {
  class MD2;
  class MD5;
}

NAMESPACE_END

#endif  // CRYPTOPP_HASHFWD_H
