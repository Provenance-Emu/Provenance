// hc256.h - written and placed in the public domain by Jeffrey Walton
//           based on public domain code by Hongjun Wu.
//
//           The reference materials and source files are available at
//           The eSTREAM Project, http://www.ecrypt.eu.org/stream/hc256.html.

/// \file hc256.h
/// \brief Classes for HC-256 stream cipher
/// \sa <A HREF="http://www.ecrypt.eu.org/stream/hc256.html">The
///   eSTREAM Project | HC-256</A> and
///   <A HREF="https://www.cryptopp.com/wiki/HC-128">Crypto++ Wiki | HC-128</A>.
/// \since Crypto++ 8.0

#ifndef CRYPTOPP_HC256_H
#define CRYPTOPP_HC256_H

#include "strciphr.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief HC-256 stream cipher information
/// \since Crypto++ 8.0
struct HC256Info : public FixedKeyLength<32, SimpleKeyingInterface::UNIQUE_IV, 32>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() { return "HC-256"; }
};

/// \brief HC-256 stream cipher implementation
/// \since Crypto++ 8.0
class HC256Policy : public AdditiveCipherConcretePolicy<word32, 4>, public HC256Info
{
protected:
	void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length);
	void OperateKeystream(KeystreamOperation operation, byte *output, const byte *input, size_t iterationCount);
	void CipherResynchronize(byte *keystreamBuffer, const byte *iv, size_t length);
	bool CanOperateKeystream() const { return true; }
	bool CipherIsRandomAccess() const { return false; }

	word32 H1(word32 u);
	word32 H2(word32 u);

	void GenerateKeystream(word32* keystream);
	word32 Generate();

private:
	FixedSizeSecBlock<word32, 8> m_key;
	FixedSizeSecBlock<word32, 8> m_iv;
	word32 m_P[1024];
	word32 m_Q[1024];
	word32 m_ctr;
};

/// \brief HC-256 stream cipher
/// \details HC-256 is a stream cipher developed by Hongjun Wu. HC-256 is the
///   successor to HC-128 from the eSTREAM project.
/// \sa <A HREF="http://www.ecrypt.eu.org/stream/hc256.html">The
///   eSTREAM Project | HC-256</A> and
///   <A HREF="https://www.cryptopp.com/wiki/HC-128">Crypto++ Wiki | HC-128</A>.
/// \since Crypto++ 8.0
struct HC256 : public HC256Info, public SymmetricCipherDocumentation
{
	typedef SymmetricCipherFinal<ConcretePolicyHolder<HC256Policy, AdditiveCipherTemplate<> >, HC256Info> Encryption;
	typedef Encryption Decryption;
};

NAMESPACE_END

#endif  // CRYPTOPP_HC256_H
