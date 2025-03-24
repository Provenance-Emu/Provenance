// rc6.h - originally written and placed in the public domain by Wei Dai

/// \file rc6.h
/// \brief Classes for the RC6 block cipher
/// \since Crypto++ 3.0

#ifndef CRYPTOPP_RC6_H
#define CRYPTOPP_RC6_H

#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief RC6 block cipher information
/// \since Crypto++ 3.0
struct RC6_Info : public FixedBlockSize<16>, public VariableKeyLength<16, 16, 32, 8>, public VariableRounds<20>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "RC6";}
	typedef word32 RC6_WORD;
};

/// \brief RC6 block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/RC6">RC6</a>
/// \since Crypto++ 3.0
class RC6 : public RC6_Info, public BlockCipherDocumentation
{
	class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<RC6_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);

	protected:
		unsigned int r;       // number of rounds
		SecBlock<RC6_WORD> sTable;  // expanded key table
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

typedef RC6::Encryption RC6Encryption;
typedef RC6::Decryption RC6Decryption;

NAMESPACE_END

#endif
