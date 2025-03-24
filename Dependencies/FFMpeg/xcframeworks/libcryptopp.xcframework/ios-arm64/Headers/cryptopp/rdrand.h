// rdrand.h - written and placed in public domain by Jeffrey Walton and Uri Blumenthal.

/// \file rdrand.h
/// \brief Classes for RDRAND and RDSEED
/// \since Crypto++ 5.6.3

#ifndef CRYPTOPP_RDRAND_H
#define CRYPTOPP_RDRAND_H

#include "cryptlib.h"

// This class file provides both RDRAND and RDSEED. They were added at
//   Crypto++ 5.6.3. At compile time, it uses CRYPTOPP_BOOL_{X86|X32|X64}
//   to select an implementation or "throw NotImplemented". At runtime the
//   constructor will throw RDRAND_Err or RDSEED_Err if a generator is
//   is not available.
// The original classes accepted a retry count. Retries were superfluous for
//   RDRAND, and RDSEED encountered a failure about 1 in 256 bytes depending
//   on the processor. Retries were removed at Crypto++ 6.0 because
//   GenerateBlock unconditionally retries and always fulfills the request.

// Throughput varies wildly depending on processor and manufacturer. A Core i5 or
//   Core i7 RDRAND can generate at over 200 MiB/s. It is below theroetical
//   maximum, but it takes about 5 instructions to generate, retry and store a
//   result. A low-end Celeron may perform RDRAND at about 7 MiB/s. RDSEED
//   performs at about 1/4 to 1/2 the rate of RDRAND. AMD RDRAND performed poorly
//   during testing with Athlon X4 845. The Bulldozer v4 only performed at 1 MiB/s.

// Microsoft added RDRAND in August 2012, VS2012; RDSEED in October 2013, VS2013.
// GCC added RDRAND in December 2010, GCC 4.6. LLVM added RDRAND in July 2012,
// Clang 3.2. Intel added RDRAND in September 2011, ICC 12.1.

NAMESPACE_BEGIN(CryptoPP)

/// \brief Exception thrown when a RDRAND generator encounters
///    a generator related error.
/// \since Crypto++ 5.6.3
class RDRAND_Err : public Exception
{
public:
    RDRAND_Err(const std::string &operation)
        : Exception(OTHER_ERROR, "RDRAND: " + operation + " operation failed") {}
};

/// \brief Hardware generated random numbers using RDRAND instruction
/// \sa MaurerRandomnessTest() for random bit generators
/// \since Crypto++ 5.6.3
class RDRAND : public RandomNumberGenerator
{
public:
    CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() { return "RDRAND"; }

    virtual ~RDRAND() {}

    /// \brief Construct a RDRAND generator
    /// \details According to DJ of Intel, the Intel RDRAND circuit does not underflow.
    ///   If it did hypothetically underflow, then it would return 0 for the random value.
    ///   AMD's RDRAND implementation appears to provide the same behavior.
     /// \throw RDRAND_Err if the random number generator is not available
    RDRAND();

    /// \brief Generate random array of bytes
    /// \param output the byte buffer
    /// \param size the length of the buffer, in bytes
    virtual void GenerateBlock(byte *output, size_t size);

    /// \brief Generate and discard n bytes
    /// \param n the number of bytes to generate and discard
    /// \details the RDSEED generator discards words, not bytes. If n is
    ///   not a multiple of a machine word, then it is rounded up to
    ///   that size.
    virtual void DiscardBytes(size_t n);

    /// \brief Update RNG state with additional unpredictable values
    /// \param input unused
    /// \param length unused
    /// \details The operation is a nop for this generator.
    virtual void IncorporateEntropy(const byte *input, size_t length)
    {
        // Override to avoid the base class' throw.
        CRYPTOPP_UNUSED(input); CRYPTOPP_UNUSED(length);
    }

    std::string AlgorithmProvider() const {
        return "RDRAND";
    }
};

/// \brief Exception thrown when a RDSEED generator encounters
///    a generator related error.
/// \since Crypto++ 5.6.3
class RDSEED_Err : public Exception
{
public:
    RDSEED_Err(const std::string &operation)
        : Exception(OTHER_ERROR, "RDSEED: " + operation + " operation failed") {}
};

/// \brief Hardware generated random numbers using RDSEED instruction
/// \sa MaurerRandomnessTest() for random bit generators
/// \since Crypto++ 5.6.3
class RDSEED : public RandomNumberGenerator
{
public:
    CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() { return "RDSEED"; }

    virtual ~RDSEED() {}

    /// \brief Construct a RDSEED generator
    /// \details Empirical testing under a 6th generation i7 (6200U) shows RDSEED fails
    ///   to fulfill requests at about once every for every 256 bytes requested.
    ///   The generator runs about 4 times slower than RDRAND.
     /// \throw RDSEED_Err if the random number generator is not available
    RDSEED();

    /// \brief Generate random array of bytes
    /// \param output the byte buffer
    /// \param size the length of the buffer, in bytes
    virtual void GenerateBlock(byte *output, size_t size);

    /// \brief Generate and discard n bytes
    /// \param n the number of bytes to generate and discard
    /// \details the RDSEED generator discards words, not bytes. If n is
    ///   not a multiple of a machine word, then it is rounded up to
    ///   that size.
    virtual void DiscardBytes(size_t n);

    /// \brief Update RNG state with additional unpredictable values
    /// \param input unused
    /// \param length unused
    /// \details The operation is a nop for this generator.
    virtual void IncorporateEntropy(const byte *input, size_t length)
    {
        // Override to avoid the base class' throw.
        CRYPTOPP_UNUSED(input); CRYPTOPP_UNUSED(length);
    }

    std::string AlgorithmProvider() const {
        return "RDSEED";
    }
};

NAMESPACE_END

#endif // CRYPTOPP_RDRAND_H
