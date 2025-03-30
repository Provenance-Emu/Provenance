// des.h - originally written and placed in the public domain by Wei Dai

/// \file des.h
/// \brief Classes for DES, 2-key Triple-DES, 3-key Triple-DES and DESX

#ifndef CRYPTOPP_DES_H
#define CRYPTOPP_DES_H

#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief DES block cipher base class
/// \since Crypto++ 1.0
class CRYPTOPP_DLL RawDES
{
public:
	void RawSetKey(CipherDir direction, const byte *userKey);
	void RawProcessBlock(word32 &l, word32 &r) const;

protected:
	static const word32 Spbox[8][64];

	FixedSizeSecBlock<word32, 32> k;
};

/// \brief DES block cipher information
/// \since Crypto++ 1.0
struct DES_Info : public FixedBlockSize<8>, public FixedKeyLength<8>
{
	// disable DES in DLL version by not exporting this function
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "DES";}
};

/// \brief DES block cipher
/// \details The DES implementation in Crypto++ ignores the parity bits
///   (the least significant bits of each byte) in the key. However you can use CheckKeyParityBits()
///   and CorrectKeyParityBits() to	check or correct the parity bits if you wish.
/// \sa <a href="http://www.cryptopp.com/wiki/TripleDES">DES</a>
/// \since Crypto++ 1.0
class DES : public DES_Info, public BlockCipherDocumentation
{
	/// \brief DES block cipher default operation
	class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<DES_Info>, public RawDES
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

public:
	/// check DES key parity bits
	static bool CheckKeyParityBits(const byte *key);
	/// correct DES key parity bits
	static void CorrectKeyParityBits(byte *key);

	typedef BlockCipherFinal<ENCRYPTION, Base> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Base> Decryption;
};

/// \brief 2-key TripleDES block cipher information
/// \since Crypto++ 1.0
struct DES_EDE2_Info : public FixedBlockSize<8>, public FixedKeyLength<16>
{
	CRYPTOPP_DLL static const char * CRYPTOPP_API StaticAlgorithmName() {return "DES-EDE2";}
};

/// \brief 2-key TripleDES block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/TripleDES">DES-EDE2</a>
/// \since Crypto++ 1.0
class DES_EDE2 : public DES_EDE2_Info, public BlockCipherDocumentation
{
	/// \brief DES_EDE2 block cipher default operation
	class CRYPTOPP_DLL CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<DES_EDE2_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

	protected:
		RawDES m_des1, m_des2;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Base> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Base> Decryption;
};

/// \brief 3-key TripleDES block cipher information
/// \since Crypto++ 1.0
struct DES_EDE3_Info : public FixedBlockSize<8>, public FixedKeyLength<24>
{
	CRYPTOPP_DLL static const char * CRYPTOPP_API StaticAlgorithmName() {return "DES-EDE3";}
};

/// \brief 3-key TripleDES block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/TripleDES">DES-EDE3</a>
/// \since Crypto++ 1.0
class DES_EDE3 : public DES_EDE3_Info, public BlockCipherDocumentation
{
	/// \brief DES_EDE3 block cipher default operation
	class CRYPTOPP_DLL CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<DES_EDE3_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

	protected:
		RawDES m_des1, m_des2, m_des3;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Base> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Base> Decryption;
};

/// \brief DESX block cipher information
/// \since Crypto++ 3.2
struct DES_XEX3_Info : public FixedBlockSize<8>, public FixedKeyLength<24>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "DES-XEX3";}
};

/// \brief DESX block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/TripleDES">DES-XEX3</a>, AKA DESX
/// \since Crypto++ 3.2
class DES_XEX3 : public DES_XEX3_Info, public BlockCipherDocumentation
{
	/// \brief DES_XEX3 block cipher default operation
	class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<DES_XEX3_Info>
	{
	public:
		void UncheckedSetKey(const byte *userKey, unsigned int length, const NameValuePairs &params);
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

	protected:
		FixedSizeSecBlock<byte, BLOCKSIZE> m_x1, m_x3;
		// VS2005 workaround: calling modules compiled with /clr gets unresolved external symbol DES::Base::ProcessAndXorBlock
		// if we use DES::Encryption here directly without value_ptr.
		value_ptr<DES::Encryption> m_des;
	};

public:
	typedef BlockCipherFinal<ENCRYPTION, Base> Encryption;
	typedef BlockCipherFinal<DECRYPTION, Base> Decryption;
};

typedef DES::Encryption DESEncryption;
typedef DES::Decryption DESDecryption;

typedef DES_EDE2::Encryption DES_EDE2_Encryption;
typedef DES_EDE2::Decryption DES_EDE2_Decryption;

typedef DES_EDE3::Encryption DES_EDE3_Encryption;
typedef DES_EDE3::Decryption DES_EDE3_Decryption;

typedef DES_XEX3::Encryption DES_XEX3_Encryption;
typedef DES_XEX3::Decryption DES_XEX3_Decryption;

NAMESPACE_END

#endif
