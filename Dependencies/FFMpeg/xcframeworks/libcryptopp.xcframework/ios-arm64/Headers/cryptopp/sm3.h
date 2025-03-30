// sm3.h - written and placed in the public domain by Jeffrey Walton and Han Lulu
//         Based on the specification provided by Sean Shen and Xiaodong Lee.
//         Based on code by Krzysztof Kwiatkowski and Jack Lloyd.
//         Also see https://tools.ietf.org/html/draft-shen-sm3-hash.

/// \file sm3.h
/// \brief Classes for the SM3 hash function
/// \details SM3 is a hash function designed by Xiaoyun Wang, et al. The hash is part of the
///   Chinese State Cryptography Administration portfolio.
/// \sa <A HREF="https://tools.ietf.org/html/draft-shen-sm3-hash">SM3 Hash Function</A> and
///   <A HREF="http://github.com/guanzhi/GmSSL">Reference implementation using OpenSSL</A>.
/// \since Crypto++ 6.0

#ifndef CRYPTOPP_SM3_H
#define CRYPTOPP_SM3_H

#include "config.h"
#include "iterhash.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief SM3 hash function
/// \details SM3 is a hash function designed by Xiaoyun Wang, et al. The hash is part of the
///   Chinese State Cryptography Administration portfolio.
/// \sa <A HREF="https://tools.ietf.org/html/draft-shen-sm3-hash">SM3 Hash Function</A>
/// \since Crypto++ 6.0
class SM3 : public IteratedHashWithStaticTransform<word32, BigEndian, 64, 32, SM3, 32, true>
{
public:
    /// \brief Initialize state array
    /// \param state the state of the hash
    /// \details InitState sets a state array to SM3 initial values
    /// \details Hashes which derive from IteratedHashWithStaticTransform provide static
    ///   member functions InitState() and Transform(). External classes, like SEAL and MDC,
    ///   can initialize state with a user provided key and operate the hash on the data
    ///   with the user supplied state.
    static void InitState(HashWordType *state);

    /// \brief Operate the hash
    /// \param digest the state of the hash
    /// \param data the data to be digested
    /// \details Transform() operates the hash on <tt>data</tt>. When the call is invoked
    ///   <tt>digest</tt> holds initial or current state. Upon return <tt>digest</tt> holds
    ///   the hash or updated state.
    /// \details Hashes which derive from IteratedHashWithStaticTransform provide static
    ///   member functions InitState() and Transform(). External classes, like SEAL and MDC,
    ///   can initialize state with a user provided key and operate the hash on the data
    ///   with the user supplied state.
    static void Transform(HashWordType *digest, const HashWordType *data);

    /// \brief The algorithm name
    /// \return C-style string "SM3"
    CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() { return "SM3"; }

protected:
    size_t HashMultipleBlocks(const HashWordType *input, size_t length);
};

NAMESPACE_END

#endif  // CRYPTOPP_SM3_H
