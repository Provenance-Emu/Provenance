// chacha.h - written and placed in the public domain by Jeffrey Walton.
//            Based on Wei Dai's Salsa20, Botan's SSE2 implementation,
//            and Bernstein's reference ChaCha family implementation at
//            http://cr.yp.to/chacha.html.

// The library added Bernstein's ChaCha classes at Crypto++ 5.6.4. The IETF
// uses a slightly different implementation than Bernstein, and the IETF
// ChaCha and XChaCha classes were added at Crypto++ 8.1. We wanted to maintain
// ABI compatibility at the 8.1 release so the original ChaCha classes were not
// disturbed. Instead new classes were added for IETF ChaCha. The back-end
// implementation shares code as expected, however.

/// \file chacha.h
/// \brief Classes for ChaCha8, ChaCha12 and ChaCha20 stream ciphers
/// \details Crypto++ provides Bernstein and ECRYPT's ChaCha from <a
///  href="http://cr.yp.to/chacha/chacha-20080128.pdf">ChaCha, a
///  variant of Salsa20</a> (2008.01.28). Crypto++ also provides the
///  IETF implementation of ChaCha using the ChaChaTLS name. Bernstein's
///  implementation is _slightly_ different from the TLS working group's
///  implementation for cipher suites
///  <tt>TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256</tt>,
///  <tt>TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256</tt>,
///  and <tt>TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256</tt>. Finally,
///  the library provides <a
///  href="https://tools.ietf.org/html/draft-arciszewski-xchacha">XChaCha:
///  eXtended-nonce ChaCha and AEAD_XChaCha20_Poly1305 (rev. 03)</a>.
/// \since ChaCha since Crypto++ 5.6.4, ChaChaTLS and XChaCha20 since Crypto++ 8.1

#ifndef CRYPTOPP_CHACHA_H
#define CRYPTOPP_CHACHA_H

#include "strciphr.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

////////////////////////////// Bernstein ChaCha //////////////////////////////

/// \brief ChaCha stream cipher information
/// \since Crypto++ 5.6.4
struct ChaCha_Info : public VariableKeyLength<32, 16, 32, 16, SimpleKeyingInterface::UNIQUE_IV, 8>
{
    /// \brief The algorithm name
    /// \return the algorithm name
    /// \details StaticAlgorithmName returns the algorithm's name as a static
    ///  member function.
    /// \details Bernstein named the cipher variants ChaCha8, ChaCha12 and
    ///  ChaCha20. More generally, Bernstein called the family ChaCha{r}.
    ///  AlgorithmName() provides the exact name once rounds are set.
    static const char* StaticAlgorithmName() {
        return "ChaCha";
    }
};

/// \brief ChaCha stream cipher implementation
/// \since Crypto++ 5.6.4
class CRYPTOPP_NO_VTABLE ChaCha_Policy : public AdditiveCipherConcretePolicy<word32, 16>
{
public:
    virtual ~ChaCha_Policy() {}
    ChaCha_Policy() : m_rounds(ROUNDS) {}

protected:
    void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length);
    void OperateKeystream(KeystreamOperation operation, byte *output, const byte *input, size_t iterationCount);
    void CipherResynchronize(byte *keystreamBuffer, const byte *IV, size_t length);
    bool CipherIsRandomAccess() const {return true;}
    void SeekToIteration(lword iterationCount);
    unsigned int GetAlignment() const;
    unsigned int GetOptimalBlockSize() const;

    std::string AlgorithmName() const;
    std::string AlgorithmProvider() const;

    CRYPTOPP_CONSTANT(ROUNDS = 20);  // Default rounds
    FixedSizeAlignedSecBlock<word32, 16> m_state;
    unsigned int m_rounds;
};

/// \brief ChaCha stream cipher
/// \details This is Bernstein and ECRYPT's ChaCha. It is _slightly_ different
///  from the IETF's version of ChaCha called ChaChaTLS.
/// \sa <a href="http://cr.yp.to/chacha/chacha-20080208.pdf">ChaCha, a variant
///  of Salsa20</a> (2008.01.28).
/// \since Crypto++ 5.6.4
struct ChaCha : public ChaCha_Info, public SymmetricCipherDocumentation
{
    /// \brief ChaCha Encryption
    typedef SymmetricCipherFinal<ConcretePolicyHolder<ChaCha_Policy, AdditiveCipherTemplate<> >, ChaCha_Info > Encryption;
    /// \brief ChaCha Decryption
    typedef Encryption Decryption;
};

////////////////////////////// IETF ChaChaTLS //////////////////////////////

/// \brief IETF ChaCha20 stream cipher information
/// \since Crypto++ 8.1
struct ChaChaTLS_Info : public FixedKeyLength<32, SimpleKeyingInterface::UNIQUE_IV, 12>, FixedRounds<20>
{
    /// \brief The algorithm name
    /// \return the algorithm name
    /// \details StaticAlgorithmName returns the algorithm's name as a static
    ///  member function.
    /// \details This is the IETF's variant of Bernstein's ChaCha from RFC
    ///  8439. IETF ChaCha is called ChaChaTLS in the Crypto++ library. It
    ///  is _slightly_ different from Bernstein's implementation.
    static const char* StaticAlgorithmName() {
        return "ChaChaTLS";
    }
};

/// \brief IETF ChaCha20 stream cipher implementation
/// \since Crypto++ 8.1
class CRYPTOPP_NO_VTABLE ChaChaTLS_Policy : public AdditiveCipherConcretePolicy<word32, 16>
{
public:
    virtual ~ChaChaTLS_Policy() {}
    ChaChaTLS_Policy() : m_counter(0) {}

protected:
    void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length);
    void OperateKeystream(KeystreamOperation operation, byte *output, const byte *input, size_t iterationCount);
    void CipherResynchronize(byte *keystreamBuffer, const byte *IV, size_t length);
    bool CipherIsRandomAccess() const {return true;}
    void SeekToIteration(lword iterationCount);
    unsigned int GetAlignment() const;
    unsigned int GetOptimalBlockSize() const;

    std::string AlgorithmName() const;
    std::string AlgorithmProvider() const;

    FixedSizeAlignedSecBlock<word32, 16+8> m_state;
    unsigned int m_counter;
    CRYPTOPP_CONSTANT(ROUNDS = ChaChaTLS_Info::ROUNDS);
    CRYPTOPP_CONSTANT(KEY = 16);  // Index into m_state
    CRYPTOPP_CONSTANT(CTR = 24);  // Index into m_state
};

/// \brief IETF ChaCha20 stream cipher
/// \details This is the IETF's variant of Bernstein's ChaCha from RFC 8439.
///  IETF ChaCha is called ChaChaTLS in the Crypto++ library. It is
///  _slightly_ different from the Bernstein implementation. ChaCha-TLS
///  can be used for cipher suites
///  <tt>TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256</tt>,
///  <tt>TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256</tt>, and
///  <tt>TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256</tt>.
/// \sa <a href="https://tools.ietf.org/html/rfc8439">RFC 8439, ChaCha20 and
///  Poly1305 for IETF Protocols</a>, <A
///  HREF="https://mailarchive.ietf.org/arch/msg/cfrg/gsOnTJzcbgG6OqD8Sc0GO5aR_tU">How
///  to handle block counter wrap in IETF's ChaCha algorithm?</A> and
///  <A HREF="https://github.com/weidai11/cryptopp/issues/790">Issue
///  790, ChaChaTLS results when counter block wraps</A>.
/// \since Crypto++ 8.1
struct ChaChaTLS : public ChaChaTLS_Info, public SymmetricCipherDocumentation
{
    /// \brief ChaCha-TLS Encryption
    typedef SymmetricCipherFinal<ConcretePolicyHolder<ChaChaTLS_Policy, AdditiveCipherTemplate<> >, ChaChaTLS_Info > Encryption;
    /// \brief ChaCha-TLS Decryption
    typedef Encryption Decryption;
};

////////////////////////////// IETF XChaCha20 draft //////////////////////////////

/// \brief IETF XChaCha20 stream cipher information
/// \since Crypto++ 8.1
struct XChaCha20_Info : public FixedKeyLength<32, SimpleKeyingInterface::UNIQUE_IV, 24>
{
    /// \brief The algorithm name
    /// \return the algorithm name
    /// \details StaticAlgorithmName returns the algorithm's name as a static
    ///  member function.
    /// \details This is the IETF's XChaCha from draft-arciszewski-xchacha.
    static const char* StaticAlgorithmName() {
        return "XChaCha20";
    }
};

/// \brief IETF XChaCha20 stream cipher implementation
/// \since Crypto++ 8.1
class CRYPTOPP_NO_VTABLE XChaCha20_Policy : public AdditiveCipherConcretePolicy<word32, 16>
{
public:
    virtual ~XChaCha20_Policy() {}
    XChaCha20_Policy() : m_counter(0), m_rounds(ROUNDS) {}

protected:
    void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length);
    void OperateKeystream(KeystreamOperation operation, byte *output, const byte *input, size_t iterationCount);
    void CipherResynchronize(byte *keystreamBuffer, const byte *IV, size_t length);
    bool CipherIsRandomAccess() const {return false;}
    void SeekToIteration(lword iterationCount);
    unsigned int GetAlignment() const;
    unsigned int GetOptimalBlockSize() const;

    std::string AlgorithmName() const;
    std::string AlgorithmProvider() const;

    FixedSizeAlignedSecBlock<word32, 16+8> m_state;
    unsigned int m_counter, m_rounds;
    CRYPTOPP_CONSTANT(ROUNDS = 20);  // Default rounds
    CRYPTOPP_CONSTANT(KEY = 16);  // Index into m_state
};

/// \brief IETF XChaCha20 stream cipher
/// \details This is the IETF's XChaCha from draft-arciszewski-xchacha.
/// \sa <a href="https://tools.ietf.org/html/draft-arciszewski-xchacha">XChaCha:
///  eXtended-nonce ChaCha and AEAD_XChaCha20_Poly1305 (rev. 03)</a>, <A
///  HREF="https://mailarchive.ietf.org/arch/msg/cfrg/gsOnTJzcbgG6OqD8Sc0GO5aR_tU">How
///  to handle block counter wrap in IETF's ChaCha algorithm?</A> and
///  <A HREF="https://github.com/weidai11/cryptopp/issues/790">Issue
///  790, ChaCha20 results when counter block wraps</A>.
/// \since Crypto++ 8.1
struct XChaCha20 : public XChaCha20_Info, public SymmetricCipherDocumentation
{
    /// \brief XChaCha Encryption
    typedef SymmetricCipherFinal<ConcretePolicyHolder<XChaCha20_Policy, AdditiveCipherTemplate<> >, XChaCha20_Info > Encryption;
    /// \brief XChaCha Decryption
    typedef Encryption Decryption;
};

NAMESPACE_END

#endif  // CRYPTOPP_CHACHA_H
