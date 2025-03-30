// cast.h - originally written and placed in the public domain by Wei Dai

/// \file cast.h
/// \brief Classes for the CAST-128 and CAST-256 block ciphers
/// \since Crypto++ 2.2

#ifndef CRYPTOPP_CAST_H
#define CRYPTOPP_CAST_H

#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief CAST block cipher base
/// \since Crypto++ 2.2
class CAST
{
protected:
	static const word32 S[8][256];
};

/// \brief CAST128 block cipher information
/// \since Crypto++ 2.2
struct CAST128_Info : public FixedBlockSize<8>, public VariableKeyLength<16, 5, 16>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "CAST-128";}
};

/// \brief CAST128 block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/CAST-128">CAST-128</a>
/// \since Crypto++ 2.2
class CAST128 : public CAST128_Info, public BlockCipherDocumentation
{
	/// \brief CAST128 block cipher default operation
	class CRYPTOPP_NO_VTABLE Base : public CAST, public BlockCipherImpl<CAST128_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);

	protected:
		bool reduced;
		FixedSizeSecBlock<word32, 32> K;
		mutable FixedSizeSecBlock<word32, 3> m_t;
	};

	/// \brief CAST128 block cipher encryption operation
	class CRYPTOPP_NO_VTABLE Enc : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

	/// \brief CAST128 block cipher decryption operation
	class CRYPTOPP_NO_VTABLE Dec : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

/// \brief CAST256 block cipher information
/// \since Crypto++ 4.0
struct CAST256_Info : public FixedBlockSize<16>, public VariableKeyLength<16, 16, 32, 4>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "CAST-256";}
};

/// \brief CAST256 block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/CAST-256">CAST-256</a>
/// \since Crypto++ 4.0
class CAST256 : public CAST256_Info, public BlockCipherDocumentation
{
	/// \brief CAST256 block cipher default operation
	class CRYPTOPP_NO_VTABLE Base : public CAST, public BlockCipherImpl<CAST256_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

	protected:
		static const word32 t_m[8][24];
		static const unsigned int t_r[8][24];

		static void Omega(int i, word32 kappa[8]);

		FixedSizeSecBlock<word32, 8*12> K;
		mutable FixedSizeSecBlock<word32, 8> kappa;
		mutable FixedSizeSecBlock<word32, 3> m_t;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Base> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Base> Decryption;
};

typedef CAST128::Encryption CAST128Encryption;
typedef CAST128::Decryption CAST128Decryption;

typedef CAST256::Encryption CAST256Encryption;
typedef CAST256::Decryption CAST256Decryption;

NAMESPACE_END

#endif
