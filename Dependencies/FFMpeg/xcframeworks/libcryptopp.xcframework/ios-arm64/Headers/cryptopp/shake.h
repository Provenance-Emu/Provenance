// shake.h - written and placed in the public domain by Jeffrey Walton

/// \file shake.h
/// \brief Classes for SHAKE message digests
/// \details The library provides byte oriented SHAKE128 and SHAKE256 using F1600.
///   FIPS 202 allows nearly unlimited output sizes, but Crypto++ limits the output
///   size to <tt>UINT_MAX</tt> due underlying data types.
/// \sa Keccak, SHA3, SHAKE128, SHAKE256,
///   <a href="https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf">FIPS 202,
///   SHA-3 Standard: Permutation-Based Hash and Extendable-Output Functions</a>
/// \since Crypto++ 8.1

#ifndef CRYPTOPP_SHAKE_H
#define CRYPTOPP_SHAKE_H

#include "cryptlib.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief SHAKE message digest base class
/// \details SHAKE is the base class for SHAKE128 and SHAKE258.
///   Library users should instantiate a derived class, and only use SHAKE
///   as a base class reference or pointer.
/// \sa Keccak, SHA3, SHAKE128, SHAKE256,
///   <a href="https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf">FIPS 202,
///   SHA-3 Standard: Permutation-Based Hash and Extendable-Output Functions</a>
/// \since Crypto++ 8.1
class SHAKE : public HashTransformation
{
protected:
    /// \brief Construct a SHAKE
    /// \param digestSize the digest size, in bytes
    /// \details SHAKE is the base class for SHAKE128 and SHAKE256.
    ///   Library users should instantiate a derived class, and only use SHAKE
    ///   as a base class reference or pointer.
    /// \details This constructor was moved to protected at Crypto++ 8.1
    ///   because users were attempting to create Keccak objects with it.
    /// \since Crypto++ 8.1
    SHAKE(unsigned int digestSize) : m_digestSize(digestSize) {Restart();}

public:
    unsigned int DigestSize() const {return m_digestSize;}
    unsigned int OptimalDataAlignment() const {return GetAlignmentOf<word64>();}

    void Update(const byte *input, size_t length);
    void Restart();
    void TruncatedFinal(byte *hash, size_t size);

protected:
    inline unsigned int r() const {return BlockSize();}

    // SHAKE-128 and SHAKE-256 effectively allow unlimited
    // output length. However, we use an unsigned int so
    // we are limited in practice to UINT_MAX.
    void ThrowIfInvalidTruncatedSize(size_t size) const;

    FixedSizeSecBlock<word64, 25> m_state;
    unsigned int m_digestSize, m_counter;
};

/// \brief SHAKE message digest template
/// \tparam T_Strength the strength of the digest
/// \since Crypto++ 8.1
template<unsigned int T_Strength>
class SHAKE_Final : public SHAKE
{
public:
    CRYPTOPP_CONSTANT(DIGESTSIZE = (T_Strength == 128 ? 32 : 64));
    CRYPTOPP_CONSTANT(BLOCKSIZE = (T_Strength == 128 ? 1344/8 : 1088/8));
    static std::string StaticAlgorithmName()
        { return "SHAKE-" + IntToString(T_Strength); }

    /// \brief Construct a SHAKE-X message digest
    /// \details SHAKE128 and SHAKE256 don't need the output size in advance
    ///   because the output size does not affect the digest. TruncatedFinal
    ///   produces the correct digest for any output size. However, cSHAKE
    ///   requires the output size in advance because the algorithm uses
    ///   output size as a parameter to the hash function.
    SHAKE_Final(unsigned int outputSize=DIGESTSIZE) : SHAKE(outputSize) {}

    /// \brief Provides the block size of the compression function
    /// \return block size of the compression function, in bytes
    /// \details BlockSize() will return 0 if the hash is not block based
    ///   or does not have an equivalent block size. For example, Keccak
    ///   and SHA-3 do not have a block size, but they do have an equivalent
    ///   to block size called rate expressed as <tt>r</tt>.
    unsigned int BlockSize() const { return BLOCKSIZE; }

    std::string AlgorithmName() const { return StaticAlgorithmName(); }

private:
#if !defined(__BORLANDC__)
    // ensure there was no underflow in the math
    CRYPTOPP_COMPILE_ASSERT(BLOCKSIZE < 200);
#endif
};

/// \brief SHAKE128 message digest
/// \details The library provides byte oriented SHAKE128 using F1600.
///   FIPS 202 allows nearly unlimited output sizes, but Crypto++ limits
///   the output size to <tt>UINT_MAX</tt> due underlying data types.
/// \sa Keccak, SHA3, SHAKE256,
///   <a href="https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf">FIPS 202,
///   SHA-3 Standard: Permutation-Based Hash and Extendable-Output Functions</a>
/// \since Crypto++ 8.1
class SHAKE128 : public SHAKE_Final<128>
{
public:
    /// \brief Construct a SHAKE128 message digest
    /// \details SHAKE128 and SHAKE256 don't need the output size in advance
    ///   because the output size does not affect the digest. TruncatedFinal
    ///   produces the correct digest for any output size. However, cSHAKE
    ///   requires the output size in advance because the algorithm uses
    ///   output size as a parameter to the hash function.
    /// \since Crypto++ 8.1
    SHAKE128() {}

    /// \brief Construct a SHAKE128 message digest
    /// \details SHAKE128 and SHAKE256 don't need the output size in advance
    ///   because the output size does not affect the digest. TruncatedFinal
    ///   produces the correct digest for any output size. However, cSHAKE
    ///   requires the output size in advance because the algorithm uses
    ///   output size as a parameter to the hash function.
    /// \since Crypto++ 8.1
    SHAKE128(unsigned int outputSize) : SHAKE_Final<128>(outputSize) {}
};

/// \brief SHAKE256 message digest
/// \details The library provides byte oriented SHAKE256 using F1600.
///   FIPS 202 allows nearly unlimited output sizes, but Crypto++ limits
///   the output size to <tt>UINT_MAX</tt> due underlying data types.
/// \sa Keccak, SHA3, SHAKE128,
///   <a href="https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf">FIPS 202,
///   SHA-3 Standard: Permutation-Based Hash and Extendable-Output Functions</a>
/// \since Crypto++ 8.1
class SHAKE256 : public SHAKE_Final<256>
{
public:
    /// \brief Construct a SHAKE256 message digest
    /// \details SHAKE128 and SHAKE256 don't need the output size in advance
    ///   because the output size does not affect the digest. TruncatedFinal
    ///   produces the correct digest for any output size. However, cSHAKE
    ///   requires the output size in advance because the algorithm uses
    ///   output size as a parameter to the hash function.
    /// \since Crypto++ 8.1
    SHAKE256() {}

    /// \brief Construct a SHAKE256 message digest
    /// \details SHAKE128 and SHAKE256 don't need the output size in advance
    ///   because the output size does not affect the digest. TruncatedFinal
    ///   produces the correct digest for any output size. However, cSHAKE
    ///   requires the output size in advance because the algorithm uses
    ///   output size as a parameter to the hash function.
    /// \since Crypto++ 8.1
    SHAKE256(unsigned int outputSize) : SHAKE_Final<256>(outputSize) {}
};

NAMESPACE_END

#endif
