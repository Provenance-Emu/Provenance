// rc5.h - originally written and placed in the public domain by Wei Dai

/// \file rc5.h
/// \brief Classes for the RC5 block cipher

#ifndef CRYPTOPP_RC5_H
#define CRYPTOPP_RC5_H

#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief RC5 block cipher information
/// \since Crypto++ 1.0
struct RC5_Info : public FixedBlockSize<8>, public VariableKeyLength<16, 0, 255>, public VariableRounds<16>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "RC5";}
	typedef word32 RC5_WORD;
};

/// \brief RC5 block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/RC5">RC5</a>
/// \since Crypto++ 1.0
class RC5 : public RC5_Info, public BlockCipherDocumentation
{
	class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<RC5_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);

	protected:
		unsigned int r;       // number of rounds
		SecBlock<RC5_WORD> sTable;  // expanded key table
	};

	class CRYPTOPP_NO_VTABLE Enc : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

	class CRYPTOPP_NO_VTABLE Dec : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef RC5::Encryption RC5Encryption;
typedef RC5::Decryption RC5Decryption;

NAMESPACE_END

#endif
