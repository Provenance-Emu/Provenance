// drbg.h - written and placed in public domain by Jeffrey Walton.

/// \file drbg.h
/// \brief Classes for NIST DRBGs from SP 800-90A
/// \sa <A HREF="http://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-90Ar1.pdf">Recommendation
///  for Random Number Generation Using Deterministic Random Bit Generators, Rev 1 (June 2015)</A>
/// \since Crypto++ 6.0

#ifndef CRYPTOPP_NIST_DRBG_H
#define CRYPTOPP_NIST_DRBG_H

#include "cryptlib.h"
#include "secblock.h"
#include "hmac.h"
#include "sha.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Interface for NIST DRBGs from SP 800-90A
/// \details NIST_DRBG is the base class interface for NIST DRBGs from SP 800-90A Rev 1 (June 2015)
/// \details You should reseed the generator after a fork() to avoid multiple generators
///  with the same internal state.
/// \sa <A HREF="http://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-90Ar1.pdf">Recommendation
///  for Random Number Generation Using Deterministic Random Bit Generators, Rev 1 (June 2015)</A>
/// \since Crypto++ 6.0
class NIST_DRBG : public RandomNumberGenerator
{
public:
    /// \brief Exception thrown when a NIST DRBG encounters an error
    class Err : public Exception
    {
    public:
        explicit Err(const std::string &c, const std::string &m)
        : Exception(OTHER_ERROR, c + ": " + m) {}
    };

public:
    virtual ~NIST_DRBG() {}

    /// \brief Determines if a generator can accept additional entropy
    /// \return true
    /// \details All NIST_DRBG return true
    virtual bool CanIncorporateEntropy() const {return true;}

    /// \brief Update RNG state with additional unpredictable values
    /// \param input the entropy to add to the generator
    /// \param length the size of the input buffer
    /// \throw NIST_DRBG::Err if the generator is reseeded with insufficient entropy
    /// \details NIST instantiation and reseed requirements demand the generator is constructed
    ///  with at least <tt>MINIMUM_ENTROPY</tt> entropy. The byte array for <tt>input</tt> must
    ///  meet <A HREF ="http://csrc.nist.gov/publications/PubsSPs.html">NIST SP 800-90B or
    ///  SP 800-90C</A> requirements.
    virtual void IncorporateEntropy(const byte *input, size_t length)=0;

    /// \brief Update RNG state with additional unpredictable values
    /// \param entropy the entropy to add to the generator
    /// \param entropyLength the size of the input buffer
    /// \param additional additional input to add to the generator
    /// \param additionaLength the size of the additional input buffer
    /// \throw NIST_DRBG::Err if the generator is reseeded with insufficient entropy
    /// \details IncorporateEntropy() is an overload provided to match NIST requirements. NIST
    ///  instantiation and reseed requirements demand the generator is constructed with at least
    ///  <tt>MINIMUM_ENTROPY</tt> entropy. The byte array for <tt>entropy</tt> must meet
    ///  <A HREF ="http://csrc.nist.gov/publications/PubsSPs.html">NIST SP 800-90B or
    ///!  SP 800-90C</A> requirements.
    virtual void IncorporateEntropy(const byte *entropy, size_t entropyLength, const byte* additional, size_t additionaLength)=0;

    /// \brief Generate random array of bytes
    /// \param output the byte buffer
    /// \param size the length of the buffer, in bytes
    /// \throw NIST_DRBG::Err if a reseed is required
    /// \throw NIST_DRBG::Err if the size exceeds <tt>MAXIMUM_BYTES_PER_REQUEST</tt>
    virtual void GenerateBlock(byte *output, size_t size)=0;

    /// \brief Generate random array of bytes
    /// \param additional additional input to add to the generator
    /// \param additionaLength the size of the additional input buffer
    /// \param output the byte buffer
    /// \param size the length of the buffer, in bytes
    /// \throw NIST_DRBG::Err if a reseed is required
    /// \throw NIST_DRBG::Err if the size exceeds <tt>MAXIMUM_BYTES_PER_REQUEST</tt>
    /// \details GenerateBlock() is an overload provided to match NIST requirements. The byte
    ///  array for <tt>additional</tt> input is optional. If present the additional randomness
    ///  is mixed before generating the output bytes.
    virtual void GenerateBlock(const byte* additional, size_t additionaLength, byte *output, size_t size)=0;

    /// \brief Provides the security strength
    /// \return The security strength of the generator, in bytes
    /// \details The equivalent class constant is <tt>SECURITY_STRENGTH</tt>
    virtual unsigned int SecurityStrength() const=0;

    /// \brief Provides the seed length
    /// \return The seed size of the generator, in bytes
    /// \details The equivalent class constant is <tt>SEED_LENGTH</tt>. The size is
    ///  used to maintain internal state of <tt>V</tt> and <tt>C</tt>.
    virtual unsigned int SeedLength() const=0;

    /// \brief Provides the minimum entropy size
    /// \return The minimum entropy size required by the generator, in bytes
    /// \details The equivalent class constant is <tt>MINIMUM_ENTROPY</tt>. All NIST DRBGs must
    ///  be instaniated with at least <tt>MINIMUM_ENTROPY</tt> bytes of entropy. The bytes must
    ///  meet <A HREF="http://csrc.nist.gov/publications/PubsSPs.html">NIST SP 800-90B or
    ///  SP 800-90C</A> requirements.
    virtual unsigned int MinEntropyLength() const=0;

    /// \brief Provides the maximum entropy size
    /// \return The maximum entropy size that can be consumed by the generator, in bytes
    /// \details The equivalent class constant is <tt>MAXIMUM_ENTROPY</tt>. The bytes must
    ///  meet <A HREF="http://csrc.nist.gov/publications/PubsSPs.html">NIST SP 800-90B or
    ///  SP 800-90C</A> requirements. <tt>MAXIMUM_ENTROPY</tt> has been reduced from
    ///  2<sup>35</sup> to <tt>INT_MAX</tt> to fit the underlying C++ datatype.
    virtual unsigned int MaxEntropyLength() const=0;

    /// \brief Provides the minimum nonce size
    /// \return The minimum nonce size recommended for the generator, in bytes
    /// \details The equivalent class constant is <tt>MINIMUM_NONCE</tt>. If a nonce is not
    ///  required then <tt>MINIMUM_NONCE</tt> is 0. <tt>Hash_DRBG</tt> does not require a
    ///  nonce, while <tt>HMAC_DRBG</tt> and <tt>CTR_DRBG</tt> require a nonce.
    virtual unsigned int MinNonceLength() const=0;

    /// \brief Provides the maximum nonce size
    /// \return The maximum nonce that can be consumed by the generator, in bytes
    /// \details The equivalent class constant is <tt>MAXIMUM_NONCE</tt>. <tt>MAXIMUM_NONCE</tt>
    ///  has been reduced from 2<sup>35</sup> to <tt>INT_MAX</tt> to fit the underlying C++ datatype.
    ///  If a nonce is not required then <tt>MINIMUM_NONCE</tt> is 0. <tt>Hash_DRBG</tt> does not
    ///  require a nonce, while <tt>HMAC_DRBG</tt> and <tt>CTR_DRBG</tt> require a nonce.
    virtual unsigned int MaxNonceLength() const=0;

    /// \brief Provides the maximum size of a request to GenerateBlock
    /// \return The maximum size of a request to GenerateBlock(), in bytes
    /// \details The equivalent class constant is <tt>MAXIMUM_BYTES_PER_REQUEST</tt>
    virtual unsigned int MaxBytesPerRequest() const=0;

    /// \brief Provides the maximum number of requests before a reseed
    /// \return The maximum number of requests before a reseed, in bytes
    /// \details The equivalent class constant is <tt>MAXIMUM_REQUESTS_BEFORE_RESEED</tt>.
    ///  <tt>MAXIMUM_REQUESTS_BEFORE_RESEED</tt> has been reduced from 2<sup>48</sup> to <tt>INT_MAX</tt>
    ///  to fit the underlying C++ datatype.
    virtual unsigned int MaxRequestBeforeReseed() const=0;

protected:
    virtual void DRBG_Instantiate(const byte* entropy, size_t entropyLength,
        const byte* nonce, size_t nonceLength, const byte* personalization, size_t personalizationLength)=0;

    virtual void DRBG_Reseed(const byte* entropy, size_t entropyLength, const byte* additional, size_t additionaLength)=0;
};

// *************************************************************

/// \tparam HASH NIST approved hash derived from HashTransformation
/// \tparam STRENGTH security strength, in bytes
/// \tparam SEEDLENGTH seed length, in bytes
/// \brief Hash_DRBG from SP 800-90A Rev 1 (June 2015)
/// \details The NIST Hash DRBG is instantiated with a number of parameters. Two of the parameters,
///  Security Strength and Seed Length, depend on the hash and are specified as template parameters.
///  The remaining parameters are included in the class. The parameters and their values are listed
///  in NIST SP 800-90A Rev. 1, Table 2: Definitions for Hash-Based DRBG Mechanisms (p.38).
/// \details Some parameters have been reduce to fit C++ datatypes. For example, NIST allows upto
///  2<sup>48</sup> requests before a reseed. However, Hash_DRBG limits it to <tt>INT_MAX</tt> due
///  to the limited data range of an int.
/// \details You should reseed the generator after a fork() to avoid multiple generators
///  with the same internal state.
/// \sa <A HREF="http://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-90Ar1.pdf">Recommendation
///  for Random Number Generation Using Deterministic Random Bit Generators, Rev 1 (June 2015)</A>
/// \since Crypto++ 6.0
template <typename HASH=SHA256, unsigned int STRENGTH=128/8, unsigned int SEEDLENGTH=440/8>
class Hash_DRBG : public NIST_DRBG, public NotCopyable
{
public:
    CRYPTOPP_CONSTANT(SECURITY_STRENGTH=STRENGTH);
    CRYPTOPP_CONSTANT(SEED_LENGTH=SEEDLENGTH);
    CRYPTOPP_CONSTANT(MINIMUM_ENTROPY=STRENGTH);
    CRYPTOPP_CONSTANT(MINIMUM_NONCE=0);
    CRYPTOPP_CONSTANT(MINIMUM_ADDITIONAL=0);
    CRYPTOPP_CONSTANT(MINIMUM_PERSONALIZATION=0);
    CRYPTOPP_CONSTANT(MAXIMUM_ENTROPY=INT_MAX);
    CRYPTOPP_CONSTANT(MAXIMUM_NONCE=INT_MAX);
    CRYPTOPP_CONSTANT(MAXIMUM_ADDITIONAL=INT_MAX);
    CRYPTOPP_CONSTANT(MAXIMUM_PERSONALIZATION=INT_MAX);
    CRYPTOPP_CONSTANT(MAXIMUM_BYTES_PER_REQUEST=65536);
    CRYPTOPP_CONSTANT(MAXIMUM_REQUESTS_BEFORE_RESEED=INT_MAX);

    static std::string StaticAlgorithmName() { return std::string("Hash_DRBG(") + HASH::StaticAlgorithmName() + std::string(")"); }

    /// \brief Construct a Hash DRBG
    /// \param entropy the entropy to instantiate the generator
    /// \param entropyLength the size of the entropy buffer
    /// \param nonce additional input to instantiate the generator
    /// \param nonceLength the size of the nonce buffer
    /// \param personalization additional input to instantiate the generator
    /// \param personalizationLength the size of the personalization buffer
    /// \throw NIST_DRBG::Err if the generator is instantiated with insufficient entropy
    /// \details All NIST DRBGs must be instaniated with at least <tt>MINIMUM_ENTROPY</tt> bytes of entropy.
    ///  The byte array for <tt>entropy</tt> must meet <A HREF ="http://csrc.nist.gov/publications/PubsSPs.html">NIST
    ///  SP 800-90B or SP 800-90C</A> requirements.
    /// \details The <tt>nonce</tt> and <tt>personalization</tt> are optional byte arrays. If <tt>nonce</tt> is supplied,
    ///  then it should be at least <tt>MINIMUM_NONCE</tt> bytes of entropy.
    /// \details An example of instantiating a SHA256 generator is shown below.
    ///  The example provides more entropy than required for SHA256. The <tt>NonblockingRng</tt> meets the
    ///  requirements of <A HREF ="http://csrc.nist.gov/publications/PubsSPs.html">NIST SP 800-90B or SP 800-90C</A>.
    ///  RDRAND() and RDSEED() generators would work as well.
    /// <pre>
    ///   SecByteBlock entropy(48), result(128);
    ///   NonblockingRng prng;
    ///   RandomNumberSource rns(prng, entropy.size(), new ArraySink(entropy, entropy.size()));
    ///
    ///   Hash_DRBG<SHA256, 128/8, 440/8> drbg(entropy, 32, entropy+32, 16);
    ///   drbg.GenerateBlock(result, result.size());
    /// </pre>
    Hash_DRBG(const byte* entropy=NULLPTR, size_t entropyLength=STRENGTH, const byte* nonce=NULLPTR,
        size_t nonceLength=0, const byte* personalization=NULLPTR, size_t personalizationLength=0)
        : NIST_DRBG(), m_c(SEEDLENGTH), m_v(SEEDLENGTH), m_reseed(0)
    {
        if (m_c.data())  // GCC analyzer warning
            std::memset(m_c.data(), 0x00, m_c.size());
        if (m_v.data())  // GCC analyzer warning
            std::memset(m_v.data(), 0x00, m_v.size());

        if (entropy != NULLPTR && entropyLength != 0)
            DRBG_Instantiate(entropy, entropyLength, nonce, nonceLength, personalization, personalizationLength);
    }

    unsigned int SecurityStrength() const {return SECURITY_STRENGTH;}
    unsigned int SeedLength() const {return SEED_LENGTH;}
    unsigned int MinEntropyLength() const {return MINIMUM_ENTROPY;}
    unsigned int MaxEntropyLength() const {return MAXIMUM_ENTROPY;}
    unsigned int MinNonceLength() const {return MINIMUM_NONCE;}
    unsigned int MaxNonceLength() const {return MAXIMUM_NONCE;}
    unsigned int MaxBytesPerRequest() const {return MAXIMUM_BYTES_PER_REQUEST;}
    unsigned int MaxRequestBeforeReseed() const {return MAXIMUM_REQUESTS_BEFORE_RESEED;}

    void IncorporateEntropy(const byte *input, size_t length)
        {return DRBG_Reseed(input, length, NULLPTR, 0);}

    void IncorporateEntropy(const byte *entropy, size_t entropyLength, const byte* additional, size_t additionaLength)
        {return DRBG_Reseed(entropy, entropyLength, additional, additionaLength);}

    void GenerateBlock(byte *output, size_t size)
        {return Hash_Generate(NULLPTR, 0, output, size);}

    void GenerateBlock(const byte* additional, size_t additionaLength, byte *output, size_t size)
        {return Hash_Generate(additional, additionaLength, output, size);}

    std::string AlgorithmProvider() const
        {/*Hack*/HASH hash; return hash.AlgorithmProvider();}

protected:
    // 10.1.1.2 Instantiation of Hash_DRBG (p.39)
    void DRBG_Instantiate(const byte* entropy, size_t entropyLength, const byte* nonce, size_t nonceLength,
        const byte* personalization, size_t personalizationLength);

    // 10.1.1.3 Reseeding a Hash_DRBG Instantiation (p.40)
    void DRBG_Reseed(const byte* entropy, size_t entropyLength, const byte* additional, size_t additionaLength);

    // 10.1.1.4 Generating Pseudorandom Bits Using Hash_DRBG (p.41)
    void Hash_Generate(const byte* additional, size_t additionaLength, byte *output, size_t size);

    // 10.3.1 Derivation Function Using a Hash Function (Hash_df) (p.49)
    void Hash_Update(const byte* input1, size_t inlen1, const byte* input2, size_t inlen2,
        const byte* input3, size_t inlen3, const byte* input4, size_t inlen4, byte* output, size_t outlen);

private:
    HASH m_hash;
    SecByteBlock m_c, m_v, m_temp;
    word64 m_reseed;
};

// typedef Hash_DRBG<SHA1,   128/8, 440/8> Hash_SHA1_DRBG;
// typedef Hash_DRBG<SHA256, 128/8, 440/8> Hash_SHA256_DRBG;
// typedef Hash_DRBG<SHA384, 256/8, 888/8> Hash_SHA384_DRBG;
// typedef Hash_DRBG<SHA512, 256/8, 888/8> Hash_SHA512_DRBG;

// *************************************************************

/// \tparam HASH NIST approved hash derived from HashTransformation
/// \tparam STRENGTH security strength, in bytes
/// \tparam SEEDLENGTH seed length, in bytes
/// \brief HMAC_DRBG from SP 800-90A Rev 1 (June 2015)
/// \details The NIST HMAC DRBG is instantiated with a number of parameters. Two of the parameters,
///  Security Strength and Seed Length, depend on the hash and are specified as template parameters.
///  The remaining parameters are included in the class. The parameters and their values are listed
///  in NIST SP 800-90A Rev. 1, Table 2: Definitions for Hash-Based DRBG Mechanisms (p.38).
/// \details Some parameters have been reduce to fit C++ datatypes. For example, NIST allows upto 2<sup>48</sup> requests
///  before a reseed. However, HMAC_DRBG limits it to <tt>INT_MAX</tt> due to the limited data range of an int.
/// \details You should reseed the generator after a fork() to avoid multiple generators
///  with the same internal state.
/// \sa <A HREF="http://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-90Ar1.pdf">Recommendation
///  for Random Number Generation Using Deterministic Random Bit Generators, Rev 1 (June 2015)</A>
/// \since Crypto++ 6.0
template <typename HASH=SHA256, unsigned int STRENGTH=128/8, unsigned int SEEDLENGTH=440/8>
class HMAC_DRBG : public NIST_DRBG, public NotCopyable
{
public:
    CRYPTOPP_CONSTANT(SECURITY_STRENGTH=STRENGTH);
    CRYPTOPP_CONSTANT(SEED_LENGTH=SEEDLENGTH);
    CRYPTOPP_CONSTANT(MINIMUM_ENTROPY=STRENGTH);
    CRYPTOPP_CONSTANT(MINIMUM_NONCE=0);
    CRYPTOPP_CONSTANT(MINIMUM_ADDITIONAL=0);
    CRYPTOPP_CONSTANT(MINIMUM_PERSONALIZATION=0);
    CRYPTOPP_CONSTANT(MAXIMUM_ENTROPY=INT_MAX);
    CRYPTOPP_CONSTANT(MAXIMUM_NONCE=INT_MAX);
    CRYPTOPP_CONSTANT(MAXIMUM_ADDITIONAL=INT_MAX);
    CRYPTOPP_CONSTANT(MAXIMUM_PERSONALIZATION=INT_MAX);
    CRYPTOPP_CONSTANT(MAXIMUM_BYTES_PER_REQUEST=65536);
    CRYPTOPP_CONSTANT(MAXIMUM_REQUESTS_BEFORE_RESEED=INT_MAX);

    static std::string StaticAlgorithmName() { return std::string("HMAC_DRBG(") + HASH::StaticAlgorithmName() + std::string(")"); }

    /// \brief Construct a HMAC DRBG
    /// \param entropy the entropy to instantiate the generator
    /// \param entropyLength the size of the entropy buffer
    /// \param nonce additional input to instantiate the generator
    /// \param nonceLength the size of the nonce buffer
    /// \param personalization additional input to instantiate the generator
    /// \param personalizationLength the size of the personalization buffer
    /// \throw NIST_DRBG::Err if the generator is instantiated with insufficient entropy
    /// \details All NIST DRBGs must be instaniated with at least <tt>MINIMUM_ENTROPY</tt> bytes of entropy.
    ///  The byte array for <tt>entropy</tt> must meet <A HREF ="http://csrc.nist.gov/publications/PubsSPs.html">NIST
    ///  SP 800-90B or SP 800-90C</A> requirements.
    /// \details The <tt>nonce</tt> and <tt>personalization</tt> are optional byte arrays. If <tt>nonce</tt> is supplied,
    ///  then it should be at least <tt>MINIMUM_NONCE</tt> bytes of entropy.
    /// \details An example of instantiating a SHA256 generator is shown below.
    ///  The example provides more entropy than required for SHA256. The <tt>NonblockingRng</tt> meets the
    ///  requirements of <A HREF ="http://csrc.nist.gov/publications/PubsSPs.html">NIST SP 800-90B or SP 800-90C</A>.
    ///  RDRAND() and RDSEED() generators would work as well.
    /// <pre>
    ///   SecByteBlock entropy(48), result(128);
    ///   NonblockingRng prng;
    ///   RandomNumberSource rns(prng, entropy.size(), new ArraySink(entropy, entropy.size()));
    ///
    ///   HMAC_DRBG<SHA256, 128/8, 440/8> drbg(entropy, 32, entropy+32, 16);
    ///   drbg.GenerateBlock(result, result.size());
    /// </pre>
    HMAC_DRBG(const byte* entropy=NULLPTR, size_t entropyLength=STRENGTH, const byte* nonce=NULLPTR,
        size_t nonceLength=0, const byte* personalization=NULLPTR, size_t personalizationLength=0)
        : NIST_DRBG(), m_k(HASH::DIGESTSIZE), m_v(HASH::DIGESTSIZE), m_reseed(0)
    {
        if (m_k.data())  // GCC analyzer warning
            std::memset(m_k, 0x00, m_k.size());
        if (m_v.data())  // GCC analyzer warning
            std::memset(m_v, 0x00, m_v.size());

        if (entropy != NULLPTR && entropyLength != 0)
            DRBG_Instantiate(entropy, entropyLength, nonce, nonceLength, personalization, personalizationLength);
    }

    unsigned int SecurityStrength() const {return SECURITY_STRENGTH;}
    unsigned int SeedLength() const {return SEED_LENGTH;}
    unsigned int MinEntropyLength() const {return MINIMUM_ENTROPY;}
    unsigned int MaxEntropyLength() const {return MAXIMUM_ENTROPY;}
    unsigned int MinNonceLength() const {return MINIMUM_NONCE;}
    unsigned int MaxNonceLength() const {return MAXIMUM_NONCE;}
    unsigned int MaxBytesPerRequest() const {return MAXIMUM_BYTES_PER_REQUEST;}
    unsigned int MaxRequestBeforeReseed() const {return MAXIMUM_REQUESTS_BEFORE_RESEED;}

    void IncorporateEntropy(const byte *input, size_t length)
        {return DRBG_Reseed(input, length, NULLPTR, 0);}

    void IncorporateEntropy(const byte *entropy, size_t entropyLength, const byte* additional, size_t additionaLength)
        {return DRBG_Reseed(entropy, entropyLength, additional, additionaLength);}

    void GenerateBlock(byte *output, size_t size)
        {return HMAC_Generate(NULLPTR, 0, output, size);}

    void GenerateBlock(const byte* additional, size_t additionaLength, byte *output, size_t size)
        {return HMAC_Generate(additional, additionaLength, output, size);}

    std::string AlgorithmProvider() const
        {/*Hack*/HASH hash; return hash.AlgorithmProvider();}

protected:
    // 10.1.2.3 Instantiation of HMAC_DRBG (p.45)
    void DRBG_Instantiate(const byte* entropy, size_t entropyLength, const byte* nonce, size_t nonceLength,
        const byte* personalization, size_t personalizationLength);

    // 10.1.2.4 Reseeding a HMAC_DRBG Instantiation (p.46)
    void DRBG_Reseed(const byte* entropy, size_t entropyLength, const byte* additional, size_t additionaLength);

    // 10.1.2.5 Generating Pseudorandom Bits Using HMAC_DRBG (p.46)
    void HMAC_Generate(const byte* additional, size_t additionaLength, byte *output, size_t size);

    // 10.1.2.2 Derivation Function Using a HMAC Function (HMAC_Update) (p.44)
    void HMAC_Update(const byte* input1, size_t inlen1, const byte* input2, size_t inlen2, const byte* input3, size_t inlen3);

private:
    HMAC<HASH> m_hmac;
    SecByteBlock m_k, m_v;
    word64 m_reseed;
};

// typedef HMAC_DRBG<SHA1,   128/8, 440/8> HMAC_SHA1_DRBG;
// typedef HMAC_DRBG<SHA256, 128/8, 440/8> HMAC_SHA256_DRBG;
// typedef HMAC_DRBG<SHA384, 256/8, 888/8> HMAC_SHA384_DRBG;
// typedef HMAC_DRBG<SHA512, 256/8, 888/8> HMAC_SHA512_DRBG;

// *************************************************************

// 10.1.1.2 Instantiation of Hash_DRBG (p.39)
template <typename HASH, unsigned int STRENGTH, unsigned int SEEDLENGTH>
void Hash_DRBG<HASH, STRENGTH, SEEDLENGTH>::DRBG_Instantiate(const byte* entropy, size_t entropyLength, const byte* nonce, size_t nonceLength,
    const byte* personalization, size_t personalizationLength)
{
    //  SP 800-90A, 8.6.3: The entropy input shall have entropy that is equal to or greater than the security
    //  strength of the instantiation. Additional entropy may be provided in the nonce or the optional
    //  personalization string during instantiation, or in the additional input during reseeding and generation,
    //  but this is not required and does not increase the "official" security strength of the DRBG
    //  instantiation that is recorded in the internal state.
    CRYPTOPP_ASSERT(entropyLength >= MINIMUM_ENTROPY);
    if (entropyLength < MINIMUM_ENTROPY)
        throw NIST_DRBG::Err("Hash_DRBG", "Insufficient entropy during instantiate");

    // SP 800-90A, Section 9, says we should throw if we have too much entropy, too large a nonce,
    // or too large a persoanlization string. We warn in Debug builds, but do nothing in Release builds.
    CRYPTOPP_ASSERT(entropyLength <= MAXIMUM_ENTROPY);
    CRYPTOPP_ASSERT(nonceLength <= MAXIMUM_NONCE);
    CRYPTOPP_ASSERT(personalizationLength <= MAXIMUM_PERSONALIZATION);

    const byte zero = 0;
    SecByteBlock t1(SEEDLENGTH), t2(SEEDLENGTH);
    Hash_Update(entropy, entropyLength, nonce, nonceLength, personalization, personalizationLength, NULLPTR, 0, t1, t1.size());
    Hash_Update(&zero, 1, t1, t1.size(), NULLPTR, 0, NULLPTR, 0, t2, t2.size());

    m_v.swap(t1); m_c.swap(t2);
    m_reseed = 1;
}

// 10.1.1.3 Reseeding a Hash_DRBG Instantiation (p.40)
template <typename HASH, unsigned int STRENGTH, unsigned int SEEDLENGTH>
void Hash_DRBG<HASH, STRENGTH, SEEDLENGTH>::DRBG_Reseed(const byte* entropy, size_t entropyLength, const byte* additional, size_t additionaLength)
{
    //  SP 800-90A, 8.6.3: The entropy input shall have entropy that is equal to or greater than the security
    //  strength of the instantiation. Additional entropy may be provided in the nonce or the optional
    //  personalization string during instantiation, or in the additional input during reseeding and generation,
    //  but this is not required and does not increase the "official" security strength of the DRBG
    //  instantiation that is recorded in the internal state..
    CRYPTOPP_ASSERT(entropyLength >= MINIMUM_ENTROPY);
    if (entropyLength < MINIMUM_ENTROPY)
        throw NIST_DRBG::Err("Hash_DRBG", "Insufficient entropy during reseed");

    // SP 800-90A, Section 9, says we should throw if we have too much entropy, too large a nonce,
    // or too large a persoanlization string. We warn in Debug builds, but do nothing in Release builds.
    CRYPTOPP_ASSERT(entropyLength <= MAXIMUM_ENTROPY);
    CRYPTOPP_ASSERT(additionaLength <= MAXIMUM_ADDITIONAL);

    const byte zero = 0, one = 1;
    SecByteBlock t1(SEEDLENGTH), t2(SEEDLENGTH);
    Hash_Update(&one, 1, m_v, m_v.size(), entropy, entropyLength, additional, additionaLength, t1, t1.size());
    Hash_Update(&zero, 1, t1, t1.size(), NULLPTR, 0, NULLPTR, 0, t2, t2.size());

    m_v.swap(t1); m_c.swap(t2);
    m_reseed = 1;
}

// 10.1.1.4 Generating Pseudorandom Bits Using Hash_DRBG (p.41)
template <typename HASH, unsigned int STRENGTH, unsigned int SEEDLENGTH>
void Hash_DRBG<HASH, STRENGTH, SEEDLENGTH>::Hash_Generate(const byte* additional, size_t additionaLength, byte *output, size_t size)
{
    // Step 1
    if (static_cast<word64>(m_reseed) >= static_cast<word64>(MaxRequestBeforeReseed()))
        throw NIST_DRBG::Err("Hash_DRBG", "Reseed required");

    if (size > MaxBytesPerRequest())
        throw NIST_DRBG::Err("Hash_DRBG", "Request size exceeds limit");

    // SP 800-90A, Section 9, says we should throw if we have too much entropy, too large a nonce,
    // or too large a persoanlization string. We warn in Debug builds, but do nothing in Release builds.
    CRYPTOPP_ASSERT(additionaLength <= MAXIMUM_ADDITIONAL);

    // Step 2
    if (additional && additionaLength)
    {
        const byte two = 2;
        m_temp.New(HASH::DIGESTSIZE);

        m_hash.Update(&two, 1);
        m_hash.Update(m_v, m_v.size());
        m_hash.Update(additional, additionaLength);
        m_hash.Final(m_temp);

        CRYPTOPP_ASSERT(SEEDLENGTH >= HASH::DIGESTSIZE);
        int carry=0, j=HASH::DIGESTSIZE-1, i=SEEDLENGTH-1;
        while (j>=0)
        {
            carry = m_v[i] + m_temp[j] + carry;
            m_v[i] = static_cast<byte>(carry);
            i--; j--; carry >>= 8;
        }
        while (i>=0)
        {
            carry = m_v[i] + carry;
            m_v[i] = static_cast<byte>(carry);
            i--; carry >>= 8;
        }
    }

    // Step 3
    {
        m_temp.Assign(m_v);
        while (size)
        {
            m_hash.Update(m_temp, m_temp.size());
            size_t count = STDMIN(size, (size_t)HASH::DIGESTSIZE);
            m_hash.TruncatedFinal(output, count);

            IncrementCounterByOne(m_temp, static_cast<unsigned int>(m_temp.size()));
            size -= count; output += count;
        }
    }

    // Steps 4-7
    {
        const byte three = 3;
        m_temp.New(HASH::DIGESTSIZE);

        m_hash.Update(&three, 1);
        m_hash.Update(m_v, m_v.size());
        m_hash.Final(m_temp);

        CRYPTOPP_ASSERT(SEEDLENGTH >= HASH::DIGESTSIZE);
        CRYPTOPP_ASSERT(HASH::DIGESTSIZE >= sizeof(m_reseed));
        int carry=0, k=sizeof(m_reseed)-1, j=HASH::DIGESTSIZE-1, i=SEEDLENGTH-1;

        while (k>=0)
        {
            carry = m_v[i] + m_c[i] + m_temp[j] + GetByte<word64>(BIG_ENDIAN_ORDER, m_reseed, k) + carry;
            m_v[i] = static_cast<byte>(carry);
            i--; j--; k--; carry >>= 8;
        }

        while (j>=0)
        {
            carry = m_v[i] + m_c[i] + m_temp[j] + carry;
            m_v[i] = static_cast<byte>(carry);
            i--; j--; carry >>= 8;
        }

        while (i>=0)
        {
            carry = m_v[i] + m_c[i] + carry;
            m_v[i] = static_cast<byte>(carry);
            i--; carry >>= 8;
        }
    }

    m_reseed++;
}

// 10.3.1 Derivation Function Using a Hash Function (Hash_df) (p.49)
template <typename HASH, unsigned int STRENGTH, unsigned int SEEDLENGTH>
void Hash_DRBG<HASH, STRENGTH, SEEDLENGTH>::Hash_Update(const byte* input1, size_t inlen1, const byte* input2, size_t inlen2,
    const byte* input3, size_t inlen3, const byte* input4, size_t inlen4, byte* output, size_t outlen)
{
    byte counter = 1;
    word32 bits = ConditionalByteReverse(BIG_ENDIAN_ORDER, static_cast<word32>(outlen*8));

    while (outlen)
    {
        m_hash.Update(&counter, 1);
        m_hash.Update(reinterpret_cast<const byte*>(&bits), 4);

        if (input1 && inlen1)
            m_hash.Update(input1, inlen1);
        if (input2 && inlen2)
            m_hash.Update(input2, inlen2);
        if (input3 && inlen3)
            m_hash.Update(input3, inlen3);
        if (input4 && inlen4)
            m_hash.Update(input4, inlen4);

        size_t count = STDMIN(outlen, (size_t)HASH::DIGESTSIZE);
        m_hash.TruncatedFinal(output, count);

        output += count; outlen -= count;
        counter++;
    }
}

// *************************************************************

// 10.1.2.3 Instantiation of HMAC_DRBG (p.45)
template <typename HASH, unsigned int STRENGTH, unsigned int SEEDLENGTH>
void HMAC_DRBG<HASH, STRENGTH, SEEDLENGTH>::DRBG_Instantiate(const byte* entropy, size_t entropyLength, const byte* nonce, size_t nonceLength,
    const byte* personalization, size_t personalizationLength)
{
    //  SP 800-90A, 8.6.3: The entropy input shall have entropy that is equal to or greater than the security
    //  strength of the instantiation. Additional entropy may be provided in the nonce or the optional
    //  personalization string during instantiation, or in the additional input during reseeding and generation,
    //  but this is not required and does not increase the "official" security strength of the DRBG
    //  instantiation that is recorded in the internal state.
    CRYPTOPP_ASSERT(entropyLength >= MINIMUM_ENTROPY);
    if (entropyLength < MINIMUM_ENTROPY)
        throw NIST_DRBG::Err("HMAC_DRBG", "Insufficient entropy during instantiate");

    // SP 800-90A, Section 9, says we should throw if we have too much entropy, too large a nonce,
    // or too large a persoanlization string. We warn in Debug builds, but do nothing in Release builds.
    CRYPTOPP_ASSERT(entropyLength <= MAXIMUM_ENTROPY);
    CRYPTOPP_ASSERT(nonceLength <= MAXIMUM_NONCE);
    CRYPTOPP_ASSERT(personalizationLength <= MAXIMUM_PERSONALIZATION);

    std::fill(m_k.begin(), m_k.begin()+m_k.size(), byte(0));
    std::fill(m_v.begin(), m_v.begin()+m_v.size(), byte(1));

    HMAC_Update(entropy, entropyLength, nonce, nonceLength, personalization, personalizationLength);
    m_reseed = 1;
}

// 10.1.2.4 Reseeding a HMAC_DRBG Instantiation (p.46)
template <typename HASH, unsigned int STRENGTH, unsigned int SEEDLENGTH>
void HMAC_DRBG<HASH, STRENGTH, SEEDLENGTH>::DRBG_Reseed(const byte* entropy, size_t entropyLength, const byte* additional, size_t additionaLength)
{
    //  SP 800-90A, 8.6.3: The entropy input shall have entropy that is equal to or greater than the security
    //  strength of the instantiation. Additional entropy may be provided in the nonce or the optional
    //  personalization string during instantiation, or in the additional input during reseeding and generation,
    //  but this is not required and does not increase the "official" security strength of the DRBG
    //  instantiation that is recorded in the internal state..
    CRYPTOPP_ASSERT(entropyLength >= MINIMUM_ENTROPY);
    if (entropyLength < MINIMUM_ENTROPY)
        throw NIST_DRBG::Err("HMAC_DRBG", "Insufficient entropy during reseed");

    // SP 800-90A, Section 9, says we should throw if we have too much entropy, too large a nonce,
    // or too large a persoanlization string. We warn in Debug builds, but do nothing in Release builds.
    CRYPTOPP_ASSERT(entropyLength <= MAXIMUM_ENTROPY);
    CRYPTOPP_ASSERT(additionaLength <= MAXIMUM_ADDITIONAL);

    HMAC_Update(entropy, entropyLength, additional, additionaLength, NULLPTR, 0);
    m_reseed = 1;
}

// 10.1.2.5 Generating Pseudorandom Bits Using HMAC_DRBG (p.46)
template <typename HASH, unsigned int STRENGTH, unsigned int SEEDLENGTH>
void HMAC_DRBG<HASH, STRENGTH, SEEDLENGTH>::HMAC_Generate(const byte* additional, size_t additionaLength, byte *output, size_t size)
{
    // Step 1
    if (static_cast<word64>(m_reseed) >= static_cast<word64>(MaxRequestBeforeReseed()))
        throw NIST_DRBG::Err("HMAC_DRBG", "Reseed required");

    if (size > MaxBytesPerRequest())
        throw NIST_DRBG::Err("HMAC_DRBG", "Request size exceeds limit");

    // SP 800-90A, Section 9, says we should throw if we have too much entropy, too large a nonce,
    // or too large a persoanlization string. We warn in Debug builds, but do nothing in Release builds.
    CRYPTOPP_ASSERT(additionaLength <= MAXIMUM_ADDITIONAL);

    // Step 2
    if (additional && additionaLength)
        HMAC_Update(additional, additionaLength, NULLPTR, 0, NULLPTR, 0);

    // Step 3
    m_hmac.SetKey(m_k, m_k.size());

    while (size)
    {
        m_hmac.Update(m_v, m_v.size());
        m_hmac.TruncatedFinal(m_v, m_v.size());

        size_t count = STDMIN(size, (size_t)HASH::DIGESTSIZE);
        std::memcpy(output, m_v, count);
        size -= count; output += count;
    }

    HMAC_Update(additional, additionaLength, NULLPTR, 0, NULLPTR, 0);
    m_reseed++;
}

// 10.1.2.2 Derivation Function Using a HMAC Function (HMAC_Update) (p.44)
template <typename HASH, unsigned int STRENGTH, unsigned int SEEDLENGTH>
void HMAC_DRBG<HASH, STRENGTH, SEEDLENGTH>::HMAC_Update(const byte* input1, size_t inlen1, const byte* input2, size_t inlen2, const byte* input3, size_t inlen3)
{
    const byte zero = 0, one = 1;

    // Step 1
    m_hmac.SetKey(m_k, m_k.size());
    m_hmac.Update(m_v, m_v.size());
    m_hmac.Update(&zero, 1);

    if (input1 && inlen1)
        m_hmac.Update(input1, inlen1);
    if (input2 && inlen2)
        m_hmac.Update(input2, inlen2);
    if (input3 && inlen3)
        m_hmac.Update(input3, inlen3);

    m_hmac.TruncatedFinal(m_k, m_k.size());

    // Step 2
    m_hmac.SetKey(m_k, m_k.size());
    m_hmac.Update(m_v, m_v.size());

    m_hmac.TruncatedFinal(m_v, m_v.size());

    // Step 3
    if ((inlen1 | inlen2 | inlen3) == 0)
        return;

    // Step 4
    m_hmac.SetKey(m_k, m_k.size());
    m_hmac.Update(m_v, m_v.size());
    m_hmac.Update(&one, 1);

    if (input1 && inlen1)
        m_hmac.Update(input1, inlen1);
    if (input2 && inlen2)
        m_hmac.Update(input2, inlen2);
    if (input3 && inlen3)
        m_hmac.Update(input3, inlen3);

    m_hmac.TruncatedFinal(m_k, m_k.size());

    // Step 5
    m_hmac.SetKey(m_k, m_k.size());
    m_hmac.Update(m_v, m_v.size());

    m_hmac.TruncatedFinal(m_v, m_v.size());
}

NAMESPACE_END

#endif  // CRYPTOPP_NIST_DRBG_H
