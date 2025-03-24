// tea.h - originally written and placed in the public domain by Wei Dai

/// \file tea.h
/// \brief Classes for the TEA, BTEA and XTEA block ciphers

#ifndef CRYPTOPP_TEA_H
#define CRYPTOPP_TEA_H

#include "seckey.h"
#include "secblock.h"
#include "misc.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief TEA block cipher information
struct TEA_Info : public FixedBlockSize<8>, public FixedKeyLength<16>, public VariableRounds<32>
{
	/// \brief The algorithm name
	/// \return the algorithm name
	/// \details StaticAlgorithmName returns the algorithm's name as a static
	///   member function.
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "TEA";}
};

/// \brief TEA block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/TEA">TEA</a>
class TEA : public TEA_Info, public BlockCipherDocumentation
{
	/// \brief TEA block cipher default operation
	class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<TEA_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);

	protected:
		FixedSizeSecBlock<word32, 4> m_k;
		word32 m_limit;
	};

	/// \brief TEA block cipher encryption operation
	class CRYPTOPP_NO_VTABLE Enc : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

	/// \brief TEA block cipher decryption operation
	class CRYPTOPP_NO_VTABLE Dec : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef TEA::Encryption TEAEncryption;
typedef TEA::Decryption TEADecryption;

/// \brief XTEA block cipher information
struct XTEA_Info : public FixedBlockSize<8>, public FixedKeyLength<16>, public VariableRounds<32>
{
	/// \brief The algorithm name
	/// \return the algorithm name
	/// \details StaticAlgorithmName returns the algorithm's name as a static
	///   member function.
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "XTEA";}
};

/// \brief XTEA block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/TEA">XTEA</a>
class XTEA : public XTEA_Info, public BlockCipherDocumentation
{
	/// \brief XTEA block cipher default operation
	class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<XTEA_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);

	protected:
		FixedSizeSecBlock<word32, 4> m_k;
		word32 m_limit;
	};

	/// \brief XTEA block cipher encryption operation
	class CRYPTOPP_NO_VTABLE Enc : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

	/// \brief XTEA block cipher decryption operation
	class CRYPTOPP_NO_VTABLE Dec : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

/// \brief BTEA block cipher information
struct BTEA_Info : public FixedKeyLength<16>
{
	/// \brief The algorithm name
	/// \return the algorithm name
	/// \details StaticAlgorithmName returns the algorithm's name as a static
	///   member function.
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "BTEA";}
};

/// \brief BTEA block cipher
/// \details Corrected Block TEA as described in "xxtea". This class hasn't been tested yet.
/// \sa <A HREF="http://www.movable-type.co.uk/scripts/xxtea.pdf">Correction to xtea</A> and
///   <a href="http://www.cryptopp.com/wiki/TEA">Corrected Block TEA</a>.
class BTEA : public BTEA_Info, public BlockCipherDocumentation
{
	/// \brief BTEA block cipher default operation
	class CRYPTOPP_NO_VTABLE Base : public AlgorithmImpl<SimpleKeyingInterfaceImpl<BlockCipher, BTEA_Info>, BTEA_Info>
	{
	public:
		void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params)
		{
			CRYPTOPP_UNUSED(length), CRYPTOPP_UNUSED(params);
			m_blockSize = params.GetIntValueWithDefault("BlockSize", 60*4);
			GetUserKey(BIG_ENDIAN_ORDER, m_k.begin(), 4, key, KEYLENGTH);
		}

		unsigned int BlockSize() const {return m_blockSize;}

	protected:
		FixedSizeSecBlock<word32, 4> m_k;
		unsigned int m_blockSize;
	};

	/// \brief BTEA block cipher encryption operation
	class CRYPTOPP_NO_VTABLE Enc : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

	/// \brief BTEA block cipher decryption operation
	class CRYPTOPP_NO_VTABLE Dec : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

NAMESPACE_END

#endif
