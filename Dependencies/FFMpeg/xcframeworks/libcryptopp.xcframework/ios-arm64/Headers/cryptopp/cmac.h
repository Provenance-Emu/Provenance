// cmac.h - originally written and placed in the public domain by Wei Dai

/// \file cmac.h
/// \brief Classes for CMAC message authentication code
/// \since Crypto++ 5.6.0

#ifndef CRYPTOPP_CMAC_H
#define CRYPTOPP_CMAC_H

#include "seckey.h"
#include "secblock.h"

/// \brief Enable CMAC and wide block ciphers
/// \details CMAC is only defined for AES. The library can support wide
///  block ciphers like Kaylna and Threefish since we know the polynomials.
#ifndef CRYPTOPP_CMAC_WIDE_BLOCK_CIPHERS
# define CRYPTOPP_CMAC_WIDE_BLOCK_CIPHERS 1
#endif  // CRYPTOPP_CMAC_WIDE_BLOCK_CIPHERS

NAMESPACE_BEGIN(CryptoPP)

/// \brief CMAC base implementation
/// \since Crypto++ 5.6.0
class CRYPTOPP_DLL CRYPTOPP_NO_VTABLE CMAC_Base : public MessageAuthenticationCode
{
public:

	virtual ~CMAC_Base() {}
	CMAC_Base() : m_counter(0) {}

	void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params);
	void Update(const byte *input, size_t length);
	void TruncatedFinal(byte *mac, size_t size);
	unsigned int DigestSize() const {return GetCipher().BlockSize();}
	unsigned int OptimalBlockSize() const {return GetCipher().BlockSize();}
	unsigned int OptimalDataAlignment() const {return GetCipher().OptimalDataAlignment();}
	std::string AlgorithmProvider() const {return GetCipher().AlgorithmProvider();}

protected:
	friend class EAX_Base;

	const BlockCipher & GetCipher() const {return const_cast<CMAC_Base*>(this)->AccessCipher();}
	virtual BlockCipher & AccessCipher() =0;

	void ProcessBuf();
	SecByteBlock m_reg;
	unsigned int m_counter;
};

/// \brief CMAC message authentication code
/// \tparam T block cipher
/// \details Template parameter T should be a class derived from BlockCipherDocumentation, for example AES, with a block size of 8, 16, or 32.
/// \sa <a href="http://www.cryptolounge.org/wiki/CMAC">CMAC</a>
/// \since Crypto++ 5.6.0
template <class T>
class CMAC : public MessageAuthenticationCodeImpl<CMAC_Base, CMAC<T> >, public SameKeyLengthAs<T>
{
public:
	/// \brief Construct a CMAC
	CMAC() {}
	/// \brief Construct a CMAC
	/// \param key the MAC key
	/// \param length the key size, in bytes
	CMAC(const byte *key, size_t length=SameKeyLengthAs<T>::DEFAULT_KEYLENGTH)
		{this->SetKey(key, length);}

	static std::string StaticAlgorithmName() {return std::string("CMAC(") + T::StaticAlgorithmName() + ")";}

private:
	BlockCipher & AccessCipher() {return m_cipher;}
	typename T::Encryption m_cipher;
};

NAMESPACE_END

#endif
