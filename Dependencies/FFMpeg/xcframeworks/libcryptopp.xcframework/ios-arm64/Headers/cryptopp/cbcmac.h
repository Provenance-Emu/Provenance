// cbcmac.h - originally written and placed in the public domain by Wei Dai

/// \file
/// \brief Classes for CBC MAC
/// \since Crypto++ 3.1

#ifndef CRYPTOPP_CBCMAC_H
#define CRYPTOPP_CBCMAC_H

#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief CBC-MAC base class
/// \since Crypto++ 3.1
class CRYPTOPP_DLL CRYPTOPP_NO_VTABLE CBC_MAC_Base : public MessageAuthenticationCode
{
public:
	CBC_MAC_Base() : m_counter(0) {}

	void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params);
	void Update(const byte *input, size_t length);
	void TruncatedFinal(byte *mac, size_t size);
	unsigned int DigestSize() const {return const_cast<CBC_MAC_Base*>(this)->AccessCipher().BlockSize();}

protected:
	virtual BlockCipher & AccessCipher() =0;

private:
	void ProcessBuf();
	SecByteBlock m_reg;
	unsigned int m_counter;
};

/// \brief CBC-MAC
/// \tparam T BlockCipherDocumentation derived class
/// \details CBC-MAC is compatible with FIPS 113. The MAC is secure only for fixed
///   length messages. For variable length messages use CMAC or DMAC.
/// \sa <a href="http://www.weidai.com/scan-mirror/mac.html#CBC-MAC">CBC-MAC</a>
/// \since Crypto++ 3.1
template <class T>
class CBC_MAC : public MessageAuthenticationCodeImpl<CBC_MAC_Base, CBC_MAC<T> >, public SameKeyLengthAs<T>
{
public:
	/// \brief Construct a CBC_MAC
	CBC_MAC() {}
	/// \brief Construct a CBC_MAC
	/// \param key a byte buffer used to key the cipher
	/// \param length the length of the byte buffer
	CBC_MAC(const byte *key, size_t length=SameKeyLengthAs<T>::DEFAULT_KEYLENGTH)
		{this->SetKey(key, length);}

	static std::string StaticAlgorithmName() {return std::string("CBC-MAC(") + T::StaticAlgorithmName() + ")";}

private:
	BlockCipher & AccessCipher() {return m_cipher;}
	typename T::Encryption m_cipher;
};

NAMESPACE_END

#endif
