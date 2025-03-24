// scrypt.h - written and placed in public domain by Jeffrey Walton.
//            Based on reference source code by Colin Percival.

/// \file scrypt.h
/// \brief Classes for Scrypt from RFC 7914
/// \sa <A HREF="https://www.tarsnap.com/scrypt/scrypt.pdf">Stronger Key Derivation via
///   Sequential Memory-Hard Functions</a>,
///   <A HREF="https://www.tarsnap.com/scrypt.html">The scrypt key derivation function</A>
///   and <A HREF="https://tools.ietf.org/html/rfc7914">RFC 7914, The scrypt Password-Based
///   Key Derivation Function</A>
/// \since Crypto++ 7.0

#ifndef CRYPTOPP_SCRYPT_H
#define CRYPTOPP_SCRYPT_H

#include "cryptlib.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Scrypt key derivation function
/// \details The Crypto++ implementation uses OpenMP to accelerate the derivation when
///   available.
/// \details The Crypto++ implementation of Scrypt is limited by C++ datatypes. For
///   example, the library is limited to a derived key length of <tt>SIZE_MAX</tt>,
///   and not <tt>(2^32 - 1) * 32</tt>.
/// \sa <A HREF="https://www.tarsnap.com/scrypt/scrypt.pdf">Stronger Key Derivation via
///   Sequential Memory-Hard Functions</A>,
///   <A HREF="https://www.tarsnap.com/scrypt.html">The scrypt key derivation function</A>
///   and <A HREF="https://tools.ietf.org/html/rfc7914">RFC 7914, The scrypt Password-Based
///   Key Derivation Function</A>
/// \since Crypto++ 7.0
class Scrypt : public KeyDerivationFunction
{
public:
    virtual ~Scrypt() {}

    static std::string StaticAlgorithmName () {
        return "scrypt";
    }

    // KeyDerivationFunction interface
    std::string AlgorithmName() const {
        return StaticAlgorithmName();
    }

    // KeyDerivationFunction interface
    size_t MaxDerivedKeyLength() const {
        return static_cast<size_t>(0)-1;
    }

    // KeyDerivationFunction interface
    size_t GetValidDerivedLength(size_t keylength) const;

    // KeyDerivationFunction interface
    size_t DeriveKey(byte *derived, size_t derivedLen, const byte *secret, size_t secretLen,
        const NameValuePairs& params) const;

    /// \brief Derive a key from a seed
    /// \param derived the derived output buffer
    /// \param derivedLen the size of the derived buffer, in bytes
    /// \param secret the seed input buffer
    /// \param secretLen the size of the secret buffer, in bytes
    /// \param salt the salt input buffer
    /// \param saltLen the size of the salt buffer, in bytes
    /// \param cost the CPU/memory cost factor
    /// \param blockSize the block size
    /// \param parallelization the parallelization factor
    /// \return the number of iterations performed
    /// \throw InvalidDerivedKeyLength if <tt>derivedLen</tt> is invalid for the scheme
    /// \details DeriveKey() provides a standard interface to derive a key from
    ///   a seed and other parameters. Each class that derives from KeyDerivationFunction
    ///   provides an overload that accepts most parameters used by the derivation function.
    /// \details The CPU/Memory <tt>cost</tt> parameter ("N" in the documents) must be
    ///   larger than 1, a power of 2, and less than <tt>2^(128 * r / 8)</tt>.
    /// \details The parameter <tt>blockSize</tt> ("r" in the documents) specifies the block
    ///   size.
    /// \details The <tt>parallelization</tt> parameter ("p" in the documents) is a positive
    ///   integer less than or equal to <tt>((2^32-1) * 32) / (128 * r)</tt>. Due to Microsoft
    ///   and its OpenMP 2.0 implementation <tt>parallelization</tt> is limited to
    ///   <tt>std::numeric_limits<int>::max()</tt>.
    /// \details Scrypt always returns 1 because it only performs 1 iteration. Other
    ///   derivation functions, like PBKDF's, will return more interesting values.
    /// \details The Crypto++ implementation of Scrypt is limited by C++ datatypes. For
    ///   example, the library is limited to a derived key length of <tt>SIZE_MAX</tt>,
    ///   and not <tt>(2^32 - 1) * 32</tt>.
    size_t DeriveKey(byte *derived, size_t derivedLen, const byte *secret, size_t secretLen,
        const byte *salt, size_t saltLen, word64 cost=2, word64 blockSize=8, word64 parallelization=1) const;

protected:
    enum {defaultCost=2, defaultBlockSize=8, defaultParallelization=1};

    // KeyDerivationFunction interface
    const Algorithm & GetAlgorithm() const {
        return *this;
    }

    inline void ValidateParameters(size_t derivedlen, word64 cost, word64 blockSize, word64 parallelization) const;
};

NAMESPACE_END

#endif // CRYPTOPP_SCRYPT_H
