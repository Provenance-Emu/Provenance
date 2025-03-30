// keccak.h - originally written and placed in the public domain by Wei Dai

/// \file keccak.h
/// \brief Classes for Keccak message digests
/// \details The Crypto++ Keccak implementation uses F1600 with XOF d=0x01.
///   FIPS 202 conformance (XOF d=0x06) is available in SHA3 classes.
/// \details Keccak will likely change in the future to accommodate extensibility of the
///   round function and the XOF functions.
/// \sa <a href="http://en.wikipedia.org/wiki/Keccak">Keccak</a>
/// \since Crypto++ 5.6.4

#ifndef CRYPTOPP_KECCAK_H
#define CRYPTOPP_KECCAK_H

#include "cryptlib.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Keccak message digest base class
/// \details The Crypto++ Keccak implementation uses F1600 with XOF d=0x01.
///   FIPS 202 conformance (XOF d=0x06) is available in SHA3 classes.
/// \details Keccak is the base class for Keccak_224, Keccak_256, Keccak_384 and Keccak_512.
///   Library users should instantiate a derived class, and only use Keccak
///   as a base class reference or pointer.
/// \details Keccak will likely change in the future to accommodate extensibility of the
///   round function and the XOF functions.
/// \details Perform the following to specify a different digest size. The class will use F1600,
///   XOF d=0x01, and a new value for <tt>r()</tt> (which will be <tt>200-2*24 = 152</tt>).
///   <pre>  Keccack_192 : public Keccack
///   {
///     public:
///       CRYPTOPP_CONSTANT(DIGESTSIZE = 24);
///       Keccack_192() : Keccack(DIGESTSIZE) {}
///   };
///   </pre>
///
/// \sa SHA3, Keccak_224, Keccak_256, Keccak_384 and Keccak_512.
/// \since Crypto++ 5.6.4
class Keccak : public HashTransformation
{
protected:
    /// \brief Construct a Keccak
    /// \param digestSize the digest size, in bytes
    /// \details Keccak is the base class for Keccak_224, Keccak_256, Keccak_384 and Keccak_512.
    ///   Library users should instantiate a derived class, and only use Keccak
    ///   as a base class reference or pointer.
    /// \details This constructor was moved to protected at Crypto++ 8.1
    ///   because users were attempting to create Keccak objects with it.
    /// \since Crypto++ 5.6.4
    Keccak(unsigned int digestSize) : m_digestSize(digestSize) {Restart();}

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

/// \brief Keccak message digest template
/// \tparam T_DigestSize the size of the digest, in bytes
/// \since Crypto++ 6.0
template<unsigned int T_DigestSize>
class Keccak_Final : public Keccak
{
public:
    CRYPTOPP_CONSTANT(DIGESTSIZE = T_DigestSize);
    CRYPTOPP_CONSTANT(BLOCKSIZE = 200 - 2 * DIGESTSIZE);
    static std::string StaticAlgorithmName()
        { return "Keccak-" + IntToString(DIGESTSIZE * 8); }

    /// \brief Construct a Keccak-X message digest
    Keccak_Final() : Keccak(DIGESTSIZE) {}

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

/// \brief Keccak-224 message digest
/// \since Crypto++ 5.6.4
DOCUMENTED_TYPEDEF(Keccak_Final<28>, Keccak_224);

/// \brief Keccak-256 message digest
/// \since Crypto++ 5.6.4
DOCUMENTED_TYPEDEF(Keccak_Final<32>, Keccak_256);

/// \brief Keccak-384 message digest
/// \since Crypto++ 5.6.4
DOCUMENTED_TYPEDEF(Keccak_Final<48>, Keccak_384);

/// \brief Keccak-512 message digest
/// \since Crypto++ 5.6.4
DOCUMENTED_TYPEDEF(Keccak_Final<64>, Keccak_512);

NAMESPACE_END

#endif
