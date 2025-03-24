// skipjack.h - originally written and placed in the public domain by Wei Dai

/// \file skipjack.h
/// \brief Classes for the SKIPJACK block cipher
/// \details The Crypto++ implementation conforms to SKIPJACK and KEA
///  Algorithm Specifications published by NIST in May 1998. The library passes
///  known answer tests available in NIST SP800-17, Table 6, pp. 140-42.
/// \sa <a href ="http://csrc.nist.gov/encryption/skipjack/skipjack.pdf">SKIPJACK
///  and KEA Algorithm Specifications</a> (May 1998),
///  <a href="http://www.cryptopp.com/wiki/SKIPJACK">SKIPJACK</a> on the
//   Crypto++ wiki

#ifndef CRYPTOPP_SKIPJACK_H
#define CRYPTOPP_SKIPJACK_H

#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief SKIPJACK block cipher information
struct SKIPJACK_Info : public FixedBlockSize<8>, public FixedKeyLength<10>
{
	CRYPTOPP_DLL static const char * CRYPTOPP_API StaticAlgorithmName() {return "SKIPJACK";}
};

/// \brief SKIPJACK block cipher
/// \details The Crypto++ implementation conforms to SKIPJACK and KEA
///  Algorithm Specifications published by NIST in May 1998. The library passes
///  known answer tests available in NIST SP800-17, Table 6, pp. 140-42.
/// \sa <a href ="http://csrc.nist.gov/encryption/skipjack/skipjack.pdf">SKIPJACK
///  and KEA Algorithm Specifications</a> (May 1998),
///  <a href="http://www.cryptopp.com/wiki/SKIPJACK">SKIPJACK</a> on the
///  Crypto++ wiki
class SKIPJACK : public SKIPJACK_Info, public BlockCipherDocumentation
{
	/// \brief SKIPJACK block cipher default operation
	class CRYPTOPP_DLL CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<SKIPJACK_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);
		unsigned int OptimalDataAlignment() const {return GetAlignmentOf<word16>();}

	protected:
		static const byte fTable[256];

		FixedSizeSecBlock<byte, 10*256> tab;
	};

	/// \brief SKIPJACK block cipher encryption operation
	class CRYPTOPP_DLL CRYPTOPP_NO_VTABLE Enc : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	private:
		static const byte Se[256];
		static const word32 Te[4][256];
	};

	/// \brief SKIPJACK block cipher decryption operation
	class CRYPTOPP_DLL CRYPTOPP_NO_VTABLE Dec : public Base
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

typedef SKIPJACK::Encryption SKIPJACKEncryption;
typedef SKIPJACK::Decryption SKIPJACKDecryption;

NAMESPACE_END

#endif
