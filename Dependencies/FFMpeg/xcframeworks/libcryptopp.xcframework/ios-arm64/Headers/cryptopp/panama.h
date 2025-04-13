// panama.h - originally written and placed in the public domain by Wei Dai

/// \file panama.h
/// \brief Classes for Panama hash and stream cipher

#ifndef CRYPTOPP_PANAMA_H
#define CRYPTOPP_PANAMA_H

#include "strciphr.h"
#include "iterhash.h"
#include "secblock.h"

// Clang 3.3 integrated assembler crash on Linux. Clang 3.4 due to compiler error with .intel_syntax
//#if CRYPTOPP_BOOL_X32 || defined(CRYPTOPP_DISABLE_MIXED_ASM)
//# define CRYPTOPP_DISABLE_PANAMA_ASM
//#endif

// https://github.com/weidai11/cryptopp/issues/758
#define CRYPTOPP_DISABLE_PANAMA_ASM 1

NAMESPACE_BEGIN(CryptoPP)

// Base class, do not use directly
template <class B>
class CRYPTOPP_NO_VTABLE Panama
{
public:
	virtual ~Panama() {}
	std::string AlgorithmProvider() const;
	void Reset();
	void Iterate(size_t count, const word32 *p=NULLPTR, byte *output=NULLPTR, const byte *input=NULLPTR, KeystreamOperation operation=WRITE_KEYSTREAM);

protected:
	typedef word32 Stage[8];
	CRYPTOPP_CONSTANT(STAGES = 32);

	FixedSizeAlignedSecBlock<word32, 20 + 8*32> m_state;
};

namespace Weak {
/// \brief Panama hash
/// \sa <a href="http://www.weidai.com/scan-mirror/md.html#Panama">Panama Hash</a>
template <class B = LittleEndian>
class PanamaHash : protected Panama<B>, public AlgorithmImpl<IteratedHash<word32, NativeByteOrder, 32>, PanamaHash<B> >
{
public:
	CRYPTOPP_CONSTANT(DIGESTSIZE = 32);
	virtual ~PanamaHash() {}
	PanamaHash() {Panama<B>::Reset();}
	unsigned int DigestSize() const {return DIGESTSIZE;}
	void TruncatedFinal(byte *hash, size_t size);
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return B::ToEnum() == BIG_ENDIAN_ORDER ? "Panama-BE" : "Panama-LE";}
	std::string AlgorithmProvider() const {return Panama<B>::AlgorithmProvider();} // Fix https://github.com/weidai11/cryptopp/issues/801

protected:
	void Init() {Panama<B>::Reset();}
	void HashEndianCorrectedBlock(const word32 *data) {this->Iterate(1, data);}	// push
	size_t HashMultipleBlocks(const word32 *input, size_t length);
	word32* StateBuf() {return NULLPTR;}

	FixedSizeSecBlock<word32, 8> m_buf;
};
}

/// \brief MAC construction using a hermetic hash function
template <class T_Hash, class T_Info = T_Hash>
class HermeticHashFunctionMAC : public AlgorithmImpl<SimpleKeyingInterfaceImpl<TwoBases<MessageAuthenticationCode, VariableKeyLength<32, 0, INT_MAX> > >, T_Info>
{
public:
	void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params)
	{
		CRYPTOPP_UNUSED(params);

		m_key.Assign(key, length);
		Restart();
	}

	void Restart()
	{
		m_hash.Restart();
		m_keyed = false;
	}

	void Update(const byte *input, size_t length)
	{
		if (!m_keyed)
			KeyHash();
		m_hash.Update(input, length);
	}

	void TruncatedFinal(byte *digest, size_t digestSize)
	{
		if (!m_keyed)
			KeyHash();
		m_hash.TruncatedFinal(digest, digestSize);
		m_keyed = false;
	}

	unsigned int DigestSize() const
		{return m_hash.DigestSize();}
	unsigned int BlockSize() const
		{return m_hash.BlockSize();}
	unsigned int OptimalBlockSize() const
		{return m_hash.OptimalBlockSize();}
	unsigned int OptimalDataAlignment() const
		{return m_hash.OptimalDataAlignment();}

protected:
	void KeyHash()
	{
		m_hash.Update(m_key, m_key.size());
		m_keyed = true;
	}

	T_Hash m_hash;
	bool m_keyed;
	SecByteBlock m_key;
};

namespace Weak {
/// \brief Panama message authentication code
template <class B = LittleEndian>
class PanamaMAC : public HermeticHashFunctionMAC<PanamaHash<B> >
{
public:
 	PanamaMAC() {}
	PanamaMAC(const byte *key, unsigned int length)
		{this->SetKey(key, length);}
};
}

/// \brief Panama stream cipher information
template <class B>
struct PanamaCipherInfo : public FixedKeyLength<32, SimpleKeyingInterface::UNIQUE_IV, 32>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return B::ToEnum() == BIG_ENDIAN_ORDER ? "Panama-BE" : "Panama-LE";}
};

/// \brief Panama stream cipher operation
template <class B>
class PanamaCipherPolicy : public AdditiveCipherConcretePolicy<word32, 8>,
							public PanamaCipherInfo<B>,
							protected Panama<B>
{
protected:
	virtual ~PanamaCipherPolicy() {}
	std::string AlgorithmProvider() const;
	void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length);
	void OperateKeystream(KeystreamOperation operation, byte *output, const byte *input, size_t iterationCount);
	bool CipherIsRandomAccess() const {return false;}
	void CipherResynchronize(byte *keystreamBuffer, const byte *iv, size_t length);
	unsigned int GetAlignment() const;

	FixedSizeSecBlock<word32, 8> m_key;
	FixedSizeSecBlock<word32, 8> m_buf;
};

/// \brief Panama stream cipher
/// \sa <a href="http://www.cryptolounge.org/wiki/PANAMA">Panama Stream Cipher</a>
template <class B = LittleEndian>
struct PanamaCipher : public PanamaCipherInfo<B>, public SymmetricCipherDocumentation
{
	typedef SymmetricCipherFinal<ConcretePolicyHolder<PanamaCipherPolicy<B>, AdditiveCipherTemplate<> >, PanamaCipherInfo<B> > Encryption;
	typedef Encryption Decryption;
};

NAMESPACE_END

#endif
