// sha3.h - originally written and placed in the public domain by Wei Dai

/// \file sha3.h
/// \brief Classes for SHA3 message digests
/// \details The Crypto++ implementation conforms to the FIPS 202 version of SHA3 using F1600 with XOF d=0x06.
///   Previous behavior (XOF d=0x01) is available in Keccak classes.
/// \sa <a href="http://en.wikipedia.org/wiki/SHA-3">SHA-3</a>,
///   <A HREF="http://csrc.nist.gov/groups/ST/hash/sha-3/fips202_standard_2015.html">SHA-3 STANDARD (FIPS 202)</A>.
/// \since Crypto++ 5.6.2

#ifndef CRYPTOPP_SHA3_H
#define CRYPTOPP_SHA3_H

#include "cryptlib.h"
#include "secblock.h"
#include "misc.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief SHA3 message digest base class
/// \details The Crypto++ implementation conforms to FIPS 202 version of SHA3 using F1600 with XOF d=0x06.
///   Previous behavior (XOF d=0x01) is available in Keccak classes.
/// \details SHA3 is the base class for SHA3_224, SHA3_256, SHA3_384 and SHA3_512.
///   Library users should instantiate a derived class, and only use SHA3
///   as a base class reference or pointer.
/// \sa Keccak, SHA3_224, SHA3_256, SHA3_384 and SHA3_512.
/// \since Crypto++ 5.6.2
class SHA3 : public HashTransformation
{
protected:
    /// \brief Construct a SHA3
    /// \param digestSize the digest size, in bytes
    /// \details SHA3 is the base class for SHA3_224, SHA3_256, SHA3_384 and SHA3_512.
    ///   Library users should instantiate a derived class, and only use SHA3
    ///   as a base class reference or pointer.
    /// \details This constructor was moved to protected at Crypto++ 8.1
    ///   because users were attempting to create Keccak objects with it.
    /// \since Crypto++ 5.6.2
    SHA3(unsigned int digestSize) : m_digestSize(digestSize) {Restart();}

public:
    unsigned int DigestSize() const {return m_digestSize;}
    unsigned int OptimalDataAlignment() const {return GetAlignmentOf<word64>();}

    void Update(const byte *input, size_t length);
    void Restart();
    void TruncatedFinal(byte *hash, size_t size);

protected:
    inline unsigned int r() const {return BlockSize();}

    FixedSizeSecBlock<word64, 25> m_state;
    unsigned int m_digestSize, m_counter;
};

/// \brief SHA3 message digest template
/// \tparam T_DigestSize the size of the digest, in bytes
/// \since Crypto++ 5.6.2
template<unsigned int T_DigestSize>
class SHA3_Final : public SHA3
{
public:
    CRYPTOPP_CONSTANT(DIGESTSIZE = T_DigestSize);
    CRYPTOPP_CONSTANT(BLOCKSIZE = 200 - 2 * DIGESTSIZE);
    static std::string StaticAlgorithmName()
        { return "SHA3-" + IntToString(DIGESTSIZE * 8); }

    /// \brief Construct a SHA3-X message digest
    SHA3_Final() : SHA3(DIGESTSIZE) {}

    /// \brief Provides the block size of the compression function
    /// \return block size of the compression function, in bytes
    /// \details BlockSize() will return 0 if the hash is not block based
    ///   or does not have an equivalent block size. For example, Keccak
    ///   and SHA-3 do not have a block size, but they do have an equivalent
    ///   block size called rate expressed as <tt>r</tt>.
    unsigned int BlockSize() const { return BLOCKSIZE; }

    std::string AlgorithmName() const { return StaticAlgorithmName(); }

private:
#if !defined(__BORLANDC__)
    // ensure there was no underflow in the math
    CRYPTOPP_COMPILE_ASSERT(BLOCKSIZE < 200);
#endif
};

/// \brief SHA3-224 message digest
/// \since Crypto++ 5.6.2
class SHA3_224 : public SHA3_Final<28> {};

/// \brief SHA3-256 message digest
/// \since Crypto++ 5.6.2
class SHA3_256 : public SHA3_Final<32> {};

/// \brief SHA3-384 message digest
/// \since Crypto++ 5.6.2
class SHA3_384 : public SHA3_Final<48> {};

/// \brief SHA3-512 message digest
/// \since Crypto++ 5.6.2
class SHA3_512 : public SHA3_Final<64> {};

NAMESPACE_END

#endif
