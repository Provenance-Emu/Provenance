// ripemd.h - originally written and placed in the public domain by Wei Dai

/// \file
/// \brief Classes for RIPEMD message digest

#ifndef CRYPTOPP_RIPEMD_H
#define CRYPTOPP_RIPEMD_H

#include "iterhash.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief RIPEMD-160 message digest
/// \details Digest size is 160-bits.
/// \sa <a href="http://www.weidai.com/scan-mirror/md.html#RIPEMD-160">RIPEMD-160</a>
/// \since Crypto++ 2.1
class RIPEMD160 : public IteratedHashWithStaticTransform<word32, LittleEndian, 64, 20, RIPEMD160>
{
public:
	static void InitState(HashWordType *state);
	static void Transform(word32 *digest, const word32 *data);
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "RIPEMD-160";}
};

/// \brief RIPEMD-320 message digest
/// \details Digest size is 320-bits.
/// \sa <a href="http://www.weidai.com/scan-mirror/md.html#RIPEMD-320">RIPEMD-320</a>
/// \since Crypto++ 2.1
class RIPEMD320 : public IteratedHashWithStaticTransform<word32, LittleEndian, 64, 40, RIPEMD320>
{
public:
	static void InitState(HashWordType *state);
	static void Transform(word32 *digest, const word32 *data);
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "RIPEMD-320";}
};

/// \brief RIPEMD-128 message digest
/// \details Digest size is 128-bits.
/// \warning RIPEMD-128 is considered insecure, and should not be used unless you absolutely need it for compatibility.
/// \sa <a href="http://www.weidai.com/scan-mirror/md.html#RIPEMD-128">RIPEMD-128</a>
/// \since Crypto++ 2.1
class RIPEMD128 : public IteratedHashWithStaticTransform<word32, LittleEndian, 64, 16, RIPEMD128>
{
public:
	static void InitState(HashWordType *state);
	static void Transform(word32 *digest, const word32 *data);
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "RIPEMD-128";}
};

/// \brief RIPEMD-256 message digest
/// \details Digest size is 256-bits.
/// \warning RIPEMD-256 is considered insecure, and should not be used unless you absolutely need it for compatibility.
/// \sa <a href="http://www.weidai.com/scan-mirror/md.html#RIPEMD-256">RIPEMD-256</a>
/// \since Crypto++ 2.1
class RIPEMD256 : public IteratedHashWithStaticTransform<word32, LittleEndian, 64, 32, RIPEMD256>
{
public:
	static void InitState(HashWordType *state);
	static void Transform(word32 *digest, const word32 *data);
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "RIPEMD-256";}
};

NAMESPACE_END

#endif
