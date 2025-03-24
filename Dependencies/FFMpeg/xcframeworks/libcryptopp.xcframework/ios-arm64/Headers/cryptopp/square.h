// square.h - originally written and placed in the public domain by Wei Dai

/// \file square.h
/// \brief Classes for the Square block cipher

#ifndef CRYPTOPP_SQUARE_H
#define CRYPTOPP_SQUARE_H

#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Square block cipher information
/// \since Crypto++ 2.2
struct Square_Info : public FixedBlockSize<16>, public FixedKeyLength<16>, FixedRounds<8>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "Square";}
};

/// \brief Square block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/Square">Square</a>
/// \since Crypto++ 2.2
class Square : public Square_Info, public BlockCipherDocumentation
{
	class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<Square_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);

	protected:
		FixedSizeSecBlock<word32, 4*(ROUNDS+1)> m_roundkeys;
	};

	class CRYPTOPP_NO_VTABLE Enc : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	private:
		static const byte Se[256];
		static const word32 Te[4][256];
	};

	class CRYPTOPP_NO_VTABLE Dec : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	private:
		static const byte Sd[256];
		static const word32 Td[4][256];
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef Square::Encryption SquareEncryption;
typedef Square::Decryption SquareDecryption;

NAMESPACE_END

#endif
