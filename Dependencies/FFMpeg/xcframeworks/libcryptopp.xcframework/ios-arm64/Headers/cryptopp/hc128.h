// hc128.h - written and placed in the public domain by Jeffrey Walton
//           based on public domain code by Hongjun Wu.
//
//           The reference materials and source files are available at
//           The eSTREAM Project, http://www.ecrypt.eu.org/stream/e2-hc128.html.

/// \file hc128.h
/// \brief Classes for HC-128 stream cipher
/// \sa <A HREF="http://www.ecrypt.eu.org/stream/e2-hc128.html">The
///   eSTREAM Project | HC-128</A> and
///   <A HREF="https://www.cryptopp.com/wiki/HC-128">Crypto++ Wiki | HC-128</A>.
/// \since Crypto++ 8.0

#ifndef CRYPTOPP_HC128_H
#define CRYPTOPP_HC128_H

#include "strciphr.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief HC-128 stream cipher information
/// \since Crypto++ 8.0
struct HC128Info : public FixedKeyLength<16, SimpleKeyingInterface::UNIQUE_IV, 16>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() { return "HC-128"; }
};

/// \brief HC-128 stream cipher implementation
/// \since Crypto++ 8.0
class HC128Policy : public AdditiveCipherConcretePolicy<word32, 16>, public HC128Info
{
protected:
	void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length);
	void OperateKeystream(KeystreamOperation operation, byte *output, const byte *input, size_t iterationCount);
	void CipherResynchronize(byte *keystreamBuffer, const byte *iv, size_t length);
	bool CanOperateKeystream() const { return true; }
	bool CipherIsRandomAccess() const { return false; }

	void GenerateKeystream(word32* keystream);
	void SetupUpdate();

private:
	FixedSizeSecBlock<word32, 16> m_X;
	FixedSizeSecBlock<word32, 16> m_Y;
	FixedSizeSecBlock<word32, 8> m_key;
	FixedSizeSecBlock<word32, 8> m_iv;
	word32 m_T[1024];
	word32 m_ctr;
};

/// \brief HC-128 stream cipher
/// \details HC-128 is a stream cipher developed by Hongjun Wu. HC-128 is one of the
///   final four Profile 1 (software) ciphers selected for the eSTREAM portfolio.
/// \sa <A HREF="http://www.ecrypt.eu.org/stream/e2-hc128.html">The
///   eSTREAM Project | HC-128</A> and
///   <A HREF="https://www.cryptopp.com/wiki/HC-128">Crypto++ Wiki | HC-128</A>.
/// \since Crypto++ 8.0
struct HC128 : public HC128Info, public SymmetricCipherDocumentation
{
	typedef SymmetricCipherFinal<ConcretePolicyHolder<HC128Policy, AdditiveCipherTemplate<> >, HC128Info> Encryption;
	typedef Encryption Decryption;
};

NAMESPACE_END

#endif  // CRYPTOPP_HC128_H
