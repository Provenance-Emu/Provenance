// serpent.h - originally written and placed in the public domain by Wei Dai

/// \file serpent.h
/// \brief Classes for the Serpent block cipher
/// \sa <a href="https://www.cl.cam.ac.uk/~rja14/serpent.html">A
///  Candidate Block Cipher for the Advanced Encryption Standard</a>

#ifndef CRYPTOPP_SERPENT_H
#define CRYPTOPP_SERPENT_H

#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Serpent block cipher information
/// \since Crypto++ 3.1
struct Serpent_Info : public FixedBlockSize<16>, public VariableKeyLength<16, 16, 32, 8>, public FixedRounds<32>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "Serpent";}
};

/// \brief Serpent block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/Serpent">Serpent</a> on the
///  Crypto++ wiki, <a href="https://www.cl.cam.ac.uk/~rja14/serpent.html">A
///  Candidate Block Cipher for the Advanced Encryption Standard</a>
/// \since Crypto++ 3.1
class Serpent : public Serpent_Info, public BlockCipherDocumentation
{
	/// \brief Serpen block cipher base implementation
	/// \details Provides implementation common to encryption and decryption
	/// \since Crypto++ 3.1
	class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<Serpent_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);

	protected:
		FixedSizeSecBlock<word32, 33*4> m_key;
	};

	/// \brief Serpent encryption transformation
	/// \details Enc provides the encryption transformation.
	///  All key sizes are supported.
	/// \since Crypto++ 3.1
	class CRYPTOPP_NO_VTABLE Enc : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

	/// \brief Serpent decryption transformation
	/// \details Dec provides the decryption transformation.
	///  All key sizes are supported.
	/// \since Crypto++ 3.1
	class CRYPTOPP_NO_VTABLE Dec : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef Serpent::Encryption SerpentEncryption;
typedef Serpent::Decryption SerpentDecryption;

NAMESPACE_END

#endif  // CRYPTOPP_SERPENT_H
