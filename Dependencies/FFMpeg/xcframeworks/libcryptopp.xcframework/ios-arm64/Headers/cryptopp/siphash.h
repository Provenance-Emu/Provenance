// siphash.h - written and placed in public domain by Jeffrey Walton.

/// \file siphash.h
/// \brief Classes for SipHash message authentication code
/// \details SipHash computes a 64-bit or 128-bit message authentication code from a variable-length
///   message and 128-bit secret key. It was designed to be efficient even for short inputs, with
///   performance comparable to non-cryptographic hash functions.
/// \details To create a SipHash-2-4 object with a 64-bit MAC use code similar to the following.
///   <pre>  SecByteBlock key(16);
///   prng.GenerateBlock(key, key.size());
///
///   SipHash<2,4,false> hash(key, key.size());
///   hash.Update(...);
///   hash.Final(...);</pre>
/// \details To create a SipHash-2-4 object with a 128-bit MAC use code similar to the following.
///   <pre>  SecByteBlock key(16);
///   prng.GenerateBlock(key, key.size());
///
///   SipHash<2,4,true> hash(key, key.size());
///   hash.Update(...);
///   hash.Final(...);</pre>
/// \sa Jean-Philippe Aumasson and Daniel J. Bernstein <A HREF="http://131002.net/siphash/siphash.pdf">SipHash:
///   a fast short-input PRF</A>
/// \since Crypto++ 6.0

#ifndef CRYPTOPP_SIPHASH_H
#define CRYPTOPP_SIPHASH_H

#include "cryptlib.h"
#include "secblock.h"
#include "seckey.h"
#include "misc.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief SipHash message authentication code information
/// \tparam T_128bit flag indicating 128-bit (true) versus 64-bit (false) digest size
template <bool T_128bit>
class SipHash_Info : public FixedKeyLength<16>
{
public:
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "SipHash";}
	CRYPTOPP_CONSTANT(DIGESTSIZE = (T_128bit ? 16 : 8));
};

/// \brief SipHash message authentication code base class
/// \tparam C the number of compression rounds
/// \tparam D the number of finalization rounds
/// \tparam T_128bit flag indicating 128-bit (true) versus 64-bit (false) digest size
template <unsigned int C, unsigned int D, bool T_128bit>
class SipHash_Base : public MessageAuthenticationCode, public SipHash_Info<T_128bit>
{
public:
	static std::string StaticAlgorithmName() {
		return std::string(SipHash_Info<T_128bit>::StaticAlgorithmName())+"-"+IntToString(C)+"-"+IntToString(D);
	}

	virtual ~SipHash_Base() {}

	SipHash_Base() : m_idx(0) {}

	virtual unsigned int DigestSize() const
		{return SipHash_Info<T_128bit>::DIGESTSIZE;}
	virtual size_t MinKeyLength() const
		{return SipHash_Info<T_128bit>::MIN_KEYLENGTH;}
	virtual size_t MaxKeyLength() const
		{return SipHash_Info<T_128bit>::MAX_KEYLENGTH;}
	virtual size_t DefaultKeyLength() const
		{return SipHash_Info<T_128bit>::DEFAULT_KEYLENGTH;}
	virtual size_t GetValidKeyLength(size_t keylength) const
		{CRYPTOPP_UNUSED(keylength); return SipHash_Info<T_128bit>::DEFAULT_KEYLENGTH;}
	virtual IV_Requirement IVRequirement() const
		{return SimpleKeyingInterface::NOT_RESYNCHRONIZABLE;}
	virtual unsigned int IVSize() const
		{return 0;}
	virtual unsigned int OptimalBlockSize() const
		{return sizeof(word64);}
	virtual unsigned int OptimalDataAlignment () const
		{return GetAlignmentOf<word64>();}

	virtual void Update(const byte *input, size_t length);
	virtual void TruncatedFinal(byte *digest, size_t digestSize);

protected:

	virtual void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params);
	virtual void Restart();

	inline void SIPROUND()
	{
		m_v[0] += m_v[1];
		m_v[1] = rotlConstant<13>(m_v[1]);
		m_v[1] ^= m_v[0];
		m_v[0] = rotlConstant<32>(m_v[0]);
		m_v[2] += m_v[3];
		m_v[3] = rotlConstant<16>(m_v[3]);
		m_v[3] ^= m_v[2];
		m_v[0] += m_v[3];
		m_v[3] = rotlConstant<21>(m_v[3]);
		m_v[3] ^= m_v[0];
		m_v[2] += m_v[1];
		m_v[1] = rotlConstant<17>(m_v[1]);
		m_v[1] ^= m_v[2];
		m_v[2] = rotlConstant<32>(m_v[2]);
	}

private:
	FixedSizeSecBlock<word64, 4> m_v;
	FixedSizeSecBlock<word64, 2> m_k;
	FixedSizeSecBlock<word64, 2> m_b;

	// Tail bytes
	FixedSizeSecBlock<byte, 8> m_acc;
	size_t m_idx;
};

/// \brief SipHash message authentication code
/// \tparam C the number of compression rounds
/// \tparam D the number of finalization rounds
/// \tparam T_128bit flag indicating 128-bit (true) versus 64-bit (false) digest size
/// \details SipHash computes a 64-bit or 128-bit message authentication code from a variable-length
///   message and 128-bit secret key. It was designed to be efficient even for short inputs, with
///   performance comparable to non-cryptographic hash functions.
/// \details To create a SipHash-2-4 object with a 64-bit MAC use code similar to the following.
///   <pre>  SecByteBlock key(16);
///   prng.GenerateBlock(key, key.size());
///
///   SipHash<2,4,false> hash(key, key.size());
///   hash.Update(...);
///   hash.Final(...);</pre>
/// \details To create a SipHash-2-4 object with a 128-bit MAC use code similar to the following.
///   <pre>  SecByteBlock key(16);
///   prng.GenerateBlock(key, key.size());
///
///   SipHash<2,4,true> hash(key, key.size());
///   hash.Update(...);
///   hash.Final(...);</pre>
/// \sa Jean-Philippe Aumasson and Daniel J. Bernstein <A HREF="http://131002.net/siphash/siphash.pdf">SipHash:
///   a fast short-input PRF</A>
/// \since Crypto++ 6.0
template <unsigned int C=2, unsigned int D=4, bool T_128bit=false>
class SipHash : public SipHash_Base<C, D, T_128bit>
{
public:
	/// \brief Create a SipHash
	SipHash()
		{this->UncheckedSetKey(NULLPTR, 0, g_nullNameValuePairs);}
	/// \brief Create a SipHash
	/// \param key a byte array used to key the cipher
	/// \param length the size of the byte array, in bytes
	SipHash(const byte *key, unsigned int length)
		{this->ThrowIfInvalidKeyLength(length);
		 this->UncheckedSetKey(key, length, g_nullNameValuePairs);}
};

template <unsigned int C, unsigned int D, bool T_128bit>
void SipHash_Base<C,D,T_128bit>::Update(const byte *input, size_t length)
{
	CRYPTOPP_ASSERT((input && length) || !length);
	if (!length) return;

	if (m_idx)
	{
		size_t head = STDMIN(size_t(8U-m_idx), length);
		std::memcpy(m_acc+m_idx, input, head);
		m_idx += head; input += head; length -= head;

		if (m_idx == 8)
		{
			word64 m = GetWord<word64>(true, LITTLE_ENDIAN_ORDER, m_acc);
			m_v[3] ^= m;
			for (unsigned int i = 0; i < C; ++i)
				SIPROUND();

			m_v[0] ^= m;
			m_b[0] += 8;

			m_idx = 0;
		}
	}

	while (length >= 8)
	{
		word64 m = GetWord<word64>(false, LITTLE_ENDIAN_ORDER, input);
		m_v[3] ^= m;
		for (unsigned int i = 0; i < C; ++i)
			SIPROUND();

		m_v[0] ^= m;
		m_b[0] += 8;

		input += 8;
		length -= 8;
	}

	CRYPTOPP_ASSERT(length < 8);
	size_t tail = length % 8;
	if (tail)
	{
		std::memcpy(m_acc+m_idx, input, tail);
		m_idx += tail;
	}
}

template <unsigned int C, unsigned int D, bool T_128bit>
void SipHash_Base<C,D,T_128bit>::TruncatedFinal(byte *digest, size_t digestSize)
{
	CRYPTOPP_ASSERT(digest);      // Pointer is valid

	ThrowIfInvalidTruncatedSize(digestSize);

	// The high octet holds length and is digested mod 256
	m_b[0] += m_idx; m_b[0] <<= 56U;
	switch (m_idx)
	{
		case 7:
			m_b[0] |= ((word64)m_acc[6]) << 48;
			// fall through
		case 6:
			m_b[0] |= ((word64)m_acc[5]) << 40;
			// fall through
		case 5:
			m_b[0] |= ((word64)m_acc[4]) << 32;
			// fall through
		case 4:
			m_b[0] |= ((word64)m_acc[3]) << 24;
			// fall through
		case 3:
			m_b[0] |= ((word64)m_acc[2]) << 16;
			// fall through
		case 2:
			m_b[0] |= ((word64)m_acc[1]) << 8;
			// fall through
		case 1:
			m_b[0] |= ((word64)m_acc[0]);
			// fall through
		case 0:
			break;
	}

	m_v[3] ^= m_b[0];

	for (unsigned int i=0; i<C; i++)
		SIPROUND();

	m_v[0] ^= m_b[0];

	if (T_128bit)
		m_v[2] ^= 0xee;
	else
		m_v[2] ^= 0xff;

	for (unsigned int i=0; i<D; i++)
		SIPROUND();

	m_b[0] = m_v[0] ^ m_v[1] ^ m_v[2] ^ m_v[3];
	m_b[0] = ConditionalByteReverse(LITTLE_ENDIAN_ORDER, m_b[0]);

	if (T_128bit)
	{
		m_v[1] ^= 0xdd;
		for (unsigned int i = 0; i<D; ++i)
			SIPROUND();

		m_b[1] = m_v[0] ^ m_v[1] ^ m_v[2] ^ m_v[3];
		m_b[1] = ConditionalByteReverse(LITTLE_ENDIAN_ORDER, m_b[1]);
	}

	memcpy_s(digest, digestSize, m_b.begin(), STDMIN(digestSize, (size_t)SipHash_Info<T_128bit>::DIGESTSIZE));
	Restart();
}

template <unsigned int C, unsigned int D, bool T_128bit>
void SipHash_Base<C,D,T_128bit>::UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params)
{
	CRYPTOPP_UNUSED(params);
	if (key && length)
	{
		m_k[0] = GetWord<word64>(false, LITTLE_ENDIAN_ORDER, key);
		m_k[1] = GetWord<word64>(false, LITTLE_ENDIAN_ORDER, key+8);
	}
	else
	{
		// Avoid Coverity finding
		m_k[0] = m_k[1] = 0;
	}
	Restart();
}

template <unsigned int C, unsigned int D, bool T_128bit>
void SipHash_Base<C,D,T_128bit>::Restart ()
{
	m_v[0] = W64LIT(0x736f6d6570736575);
	m_v[1] = W64LIT(0x646f72616e646f6d);
	m_v[2] = W64LIT(0x6c7967656e657261);
	m_v[3] = W64LIT(0x7465646279746573);

	m_v[3] ^= m_k[1];
	m_v[2] ^= m_k[0];
	m_v[1] ^= m_k[1];
	m_v[0] ^= m_k[0];

	if (T_128bit)
	{
		m_v[1] ^= 0xee;
	}

	m_idx = 0;
	m_b[0] = 0;
}

NAMESPACE_END

#endif // CRYPTOPP_SIPHASH_H
