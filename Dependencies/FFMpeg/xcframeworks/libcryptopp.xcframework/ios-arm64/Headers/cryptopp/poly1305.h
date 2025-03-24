// poly1305.h - written and placed in the public domain by Jeffrey Walton and Jean-Pierre Munch
//              Based on Andy Polyakov's Base-2^26 scalar multiplication implementation.
//              For more information, see https://www.openssl.org/~appro/cryptogams/.

// The library added Bernstein's Poly1305 classes at Crypto++ 6.0. The IETF
// uses a slightly different implementation than Bernstein, and the IETF
// classes were added at Crypto++ 8.1. We wanted to maintain ABI compatibility
// at the 8.1 release so the original Poly1305 classes were not disturbed.
// Instead new classes were added for IETF Poly1305. The back-end implementation
// shares code as expected, however.

/// \file poly1305.h
/// \brief Classes for Poly1305 message authentication code
/// \details Poly1305-AES is a state-of-the-art message-authentication code suitable for a wide
///   variety of applications. Poly1305-AES computes a 16-byte authenticator of a variable-length
///   message, using a 16-byte AES key, a 16-byte additional key, and a 16-byte nonce.
/// \details Crypto++ also supplies the IETF's version of Poly1305. It is a slightly different
///   algorithm than Bernstein's version.
/// \sa Daniel J. Bernstein <A HREF="http://cr.yp.to/mac/poly1305-20050329.pdf">The Poly1305-AES
///   Message-Authentication Code (20050329)</A>, <a href="http://tools.ietf.org/html/rfc8439">RFC
///   8439, ChaCha20 and Poly1305 for IETF Protocols</a> and Andy Polyakov <A
///   HREF="http://www.openssl.org/blog/blog/2016/02/15/poly1305-revised/">Poly1305 Revised</A>
/// \since Poly1305 since Crypto++ 6.0, Poly1305TLS since Crypto++ 8.1

#ifndef CRYPTOPP_POLY1305_H
#define CRYPTOPP_POLY1305_H

#include "cryptlib.h"
#include "seckey.h"
#include "secblock.h"
#include "argnames.h"
#include "algparam.h"

NAMESPACE_BEGIN(CryptoPP)

////////////////////////////// Bernstein Poly1305 //////////////////////////////

/// \brief Poly1305 message authentication code base class
/// \tparam T BlockCipherDocumentation derived class with 16-byte key and 16-byte blocksize
/// \details Poly1305_Base is the base class of Bernstein's Poly1305 algorithm.
/// \since Crypto++ 6.0
template <class T>
class CRYPTOPP_NO_VTABLE Poly1305_Base : public FixedKeyLength<32, SimpleKeyingInterface::UNIQUE_IV, 16>, public MessageAuthenticationCode
{
	CRYPTOPP_COMPILE_ASSERT(T::DEFAULT_KEYLENGTH == 16);
	CRYPTOPP_COMPILE_ASSERT(T::BLOCKSIZE == 16);

public:
	static std::string StaticAlgorithmName() {return std::string("Poly1305(") + T::StaticAlgorithmName() + ")";}

	CRYPTOPP_CONSTANT(DIGESTSIZE=T::BLOCKSIZE);
	CRYPTOPP_CONSTANT(BLOCKSIZE=T::BLOCKSIZE);

	virtual ~Poly1305_Base() {}
	Poly1305_Base() : m_idx(0), m_used(true) {}

	void Resynchronize (const byte *iv, int ivLength=-1);
	void GetNextIV (RandomNumberGenerator &rng, byte *iv);

	void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params);
	void Update(const byte *input, size_t length);
	void TruncatedFinal(byte *mac, size_t size);
	void Restart();

	unsigned int BlockSize() const {return BLOCKSIZE;}
	unsigned int DigestSize() const {return DIGESTSIZE;}

	std::string AlgorithmProvider() const;

protected:
	// TODO: No longer needed. Remove at next major version bump
	void HashBlocks(const byte *input, size_t length, word32 padbit);
	void HashFinal(byte *mac, size_t length);

	typename T::Encryption m_cipher;

	// Accumulated hash, clamped r-key, and encrypted nonce
	FixedSizeAlignedSecBlock<word32, 5> m_h;
	FixedSizeAlignedSecBlock<word32, 4> m_r;
	FixedSizeAlignedSecBlock<word32, 4> m_n;

	// Accumulated message bytes and index
	FixedSizeAlignedSecBlock<byte, BLOCKSIZE> m_acc, m_nk;
	size_t m_idx;

	// Track nonce reuse; assert in debug but continue
	bool m_used;
};

/// \brief Poly1305 message authentication code
/// \tparam T class derived from BlockCipherDocumentation with 16-byte key and 16-byte blocksize
/// \details Poly1305-AES is a state-of-the-art message-authentication code suitable for a wide
///   variety of applications. Poly1305-AES computes a 16-byte authenticator of a variable-length
///   message, using a 16-byte AES key, a 16-byte additional key, and a 16-byte nonce.
/// \details The key is 32 bytes and a concatenation <tt>key = {k,s}</tt>, where
///   <tt>k</tt> is the AES key and <tt>r</tt> is additional key that gets clamped.
///   The key is clamped internally so there is no need to perform the operation
///   before setting the key.
/// \details Each message must have a unique security context, which means either the key or nonce
///   must be changed after each message. It can be accomplished in one of two ways. First, you
///   can create a new Poly1305 object each time its needed.
///   <pre>  SecByteBlock key(32), nonce(16);
///   prng.GenerateBlock(key, key.size());
///   prng.GenerateBlock(nonce, nonce.size());
///
///   Poly1305<AES> poly1305(key, key.size(), nonce, nonce.size());
///   poly1305.Update(...);
///   poly1305.Final(...);</pre>
///
/// \details Second, you can create a Poly1305 object, reuse the key, and set a fresh nonce
///   for each message. The second and subsequent nonces can be generated using GetNextIV().
///   <pre>  SecByteBlock key(32), nonce(16);
///   prng.GenerateBlock(key, key.size());
///   prng.GenerateBlock(nonce, nonce.size());
///
///   // First message
///   Poly1305<AES> poly1305(key, key.size());
///   poly1305.Resynchronize(nonce);
///   poly1305.Update(...);
///   poly1305.Final(...);
///
///   // Second message
///   poly1305.GetNextIV(prng, nonce);
///   poly1305.Resynchronize(nonce);
///   poly1305.Update(...);
///   poly1305.Final(...);
///   ...</pre>
/// \warning Each message must have a unique security context. The Poly1305 class does not
///   enforce a fresh key or nonce for each message. The source code will assert in debug
///   builds to alert of nonce reuse. No action is taken in release builds.
/// \sa Daniel J. Bernstein <A HREF="http://cr.yp.to/mac/poly1305-20050329.pdf">The Poly1305-AES
///   Message-Authentication Code (20050329)</A> and Andy Polyakov <A
///   HREF="http://www.openssl.org/blog/blog/2016/02/15/poly1305-revised/">Poly1305 Revised</A>
/// \since Crypto++ 6.0
template <class T>
class Poly1305 : public MessageAuthenticationCodeFinal<Poly1305_Base<T> >
{
public:
	CRYPTOPP_CONSTANT(DEFAULT_KEYLENGTH=Poly1305_Base<T>::DEFAULT_KEYLENGTH);

	/// \brief Construct a Poly1305
	Poly1305() {}

	/// \brief Construct a Poly1305
	/// \param key a byte array used to key the cipher
	/// \param keyLength the size of the byte array, in bytes
	/// \param nonce a byte array used to key the cipher
	/// \param nonceLength the size of the byte array, in bytes
	/// \details The key is 32 bytes and a concatenation <tt>key = {k,s}</tt>, where
	///   <tt>k</tt> is the AES key and <tt>r</tt> is additional key that gets clamped.
	///   The key is clamped internally so there is no need to perform the operation
	///   before setting the key.
	/// \details Each message requires a unique security context. You can use GetNextIV()
	///   and Resynchronize() to set a new nonce under a key for a message.
	Poly1305(const byte *key, size_t keyLength=DEFAULT_KEYLENGTH, const byte *nonce=NULLPTR, size_t nonceLength=0)
		{this->SetKey(key, keyLength, MakeParameters(Name::IV(), ConstByteArrayParameter(nonce, nonceLength)));}
};

////////////////////////////// IETF Poly1305 //////////////////////////////

/// \brief Poly1305-TLS message authentication code base class
/// \details Poly1305TLS_Base is the base class of the IETF's Poly1305 algorithm.
/// \since Crypto++ 8.1
class Poly1305TLS_Base : public FixedKeyLength<32>, public MessageAuthenticationCode
{
public:
	static std::string StaticAlgorithmName() {return std::string("Poly1305TLS");}
	CRYPTOPP_CONSTANT(DIGESTSIZE=16);
	CRYPTOPP_CONSTANT(BLOCKSIZE=16);

	virtual ~Poly1305TLS_Base() {}
	Poly1305TLS_Base() {}

	void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params);
	void Update(const byte *input, size_t length);
	void TruncatedFinal(byte *mac, size_t size);
	void Restart();

	unsigned int BlockSize() const {return BLOCKSIZE;}
	unsigned int DigestSize() const {return DIGESTSIZE;}

protected:
	// Accumulated hash, clamped r-key, and encrypted nonce
	FixedSizeAlignedSecBlock<word32, 5> m_h;
	FixedSizeAlignedSecBlock<word32, 4> m_r;
	FixedSizeAlignedSecBlock<word32, 4> m_n;

	// Accumulated message bytes and index
	FixedSizeAlignedSecBlock<byte, BLOCKSIZE> m_acc;
	size_t m_idx;
};

/// \brief Poly1305-TLS message authentication code
/// \details This is the IETF's variant of Bernstein's Poly1305 from RFC 8439.
///   IETF Poly1305 is called Poly1305TLS in the Crypto++ library. It is
///   _slightly_ different from the Bernstein implementation. Poly1305-TLS
///   can be used for cipher suites
///   <tt>TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256</tt>,
///   <tt>TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256</tt>, and
///   <tt>TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256</tt>.
/// \details The key is 32 bytes and a concatenation <tt>key = {r,s}</tt>, where
///   <tt>r</tt> is additional key that gets clamped and <tt>s</tt> is the nonce.
///   The key is clamped internally so there is no need to perform the operation
///   before setting the key.
/// \details Each message must have a unique security context, which means the key
///   must be changed after each message. It can be accomplished in one of two ways.
///   First, you can create a new Poly1305 object with a new key each time its needed.
///   <pre>  SecByteBlock key(32);
///   prng.GenerateBlock(key, key.size());
///
///   Poly1305TLS poly1305(key, key.size());
///   poly1305.Update(...);
///   poly1305.Final(...);</pre>
///
/// \details Second, you can create a Poly1305 object, and use a new key for each
///   message. The keys can be generated directly using a RandomNumberGenerator()
///   derived class.
///   <pre>  SecByteBlock key(32);
///   prng.GenerateBlock(key, key.size());
///
///   // First message
///   Poly1305TLS poly1305(key, key.size());
///   poly1305.Update(...);
///   poly1305.Final(...);
///
///   // Second message
///   prng.GenerateBlock(key, key.size());
///   poly1305.SetKey(key, key.size());
///   poly1305.Update(...);
///   poly1305.Final(...);
///   ...</pre>
/// \warning Each message must have a unique security context. The Poly1305-TLS class
///   does not enforce a fresh key or nonce for each message.
/// \since Crypto++ 8.1
/// \sa MessageAuthenticationCode(), <a href="http://tools.ietf.org/html/rfc8439">RFC
///   8439, ChaCha20 and Poly1305 for IETF Protocols</a>
DOCUMENTED_TYPEDEF(MessageAuthenticationCodeFinal<Poly1305TLS_Base>, Poly1305TLS);

NAMESPACE_END

#endif  // CRYPTOPP_POLY1305_H
