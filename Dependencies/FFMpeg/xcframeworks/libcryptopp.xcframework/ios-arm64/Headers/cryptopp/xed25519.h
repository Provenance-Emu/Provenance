// xed25519.h - written and placed in public domain by Jeffrey Walton
//              Crypto++ specific implementation wrapped around Andrew
//              Moon's public domain curve25519-donna and ed25519-donna,
//              http://github.com/floodyberry/curve25519-donna and
//              http://github.com/floodyberry/ed25519-donna.

// Typically the key agreement classes encapsulate their data more
// than x25519 does below. They are a little more accessible
// due to crypto_box operations.

/// \file xed25519.h
/// \brief Classes for x25519 and ed25519 operations
/// \details This implementation integrates Andrew Moon's public domain code
///  for curve25519-donna and ed25519-donna.
/// \details Moving keys into and out of the library proceeds as follows.
///  If an Integer class is accepted or returned, then the data is in big
///  endian format. That is, the MSB is at byte position 0, and the LSB
///  is at byte position 31. The Integer will work as expected, just like
///  an int or a long.
/// \details If a byte array is accepted, then the byte array is in little
///  endian format. That is, the LSB is at byte position 0, and the MSB is
///  at byte position 31. This follows the implementation where byte 0 is
///  clamed with 248. That is my_arr[0] &= 248 to mask the lower 3 bits.
/// \details PKCS8 and X509 keys encoded using ASN.1 follow little endian
///  arrays. The format is specified in <A HREF=
///  "http:///tools.ietf.org/html/draft-ietf-curdle-pkix">draft-ietf-curdle-pkix</A>.
/// \details If you have a little endian array and you want to wrap it in
///  an Integer using big endian then you can perform the following:
/// <pre>Integer x(my_arr, SECRET_KEYLENGTH, UNSIGNED, LITTLE_ENDIAN_ORDER);</pre>
/// \sa Andrew Moon's x22519 GitHub <A
///  HREF="http://github.com/floodyberry/curve25519-donna">curve25519-donna</A>,
///  ed22519 GitHub <A
///  HREF="http://github.com/floodyberry/ed25519-donna">ed25519-donna</A>, and
///  <A HREF="http:///tools.ietf.org/html/draft-ietf-curdle-pkix">draft-ietf-curdle-pkix</A>
/// \since Crypto++ 8.0

#ifndef CRYPTOPP_XED25519_H
#define CRYPTOPP_XED25519_H

#include "cryptlib.h"
#include "pubkey.h"
#include "oids.h"

NAMESPACE_BEGIN(CryptoPP)

class Integer;
struct ed25519Signer;
struct ed25519Verifier;

// ******************** x25519 Agreement ************************* //

/// \brief x25519 with key validation
/// \since Crypto++ 8.0
class x25519 : public SimpleKeyAgreementDomain, public CryptoParameters, public PKCS8PrivateKey
{
public:
    /// \brief Size of the private key
    /// \details SECRET_KEYLENGTH is the size of the private key, in bytes.
    CRYPTOPP_CONSTANT(SECRET_KEYLENGTH = 32);
    /// \brief Size of the public key
    /// \details PUBLIC_KEYLENGTH is the size of the public key, in bytes.
    CRYPTOPP_CONSTANT(PUBLIC_KEYLENGTH = 32);
    /// \brief Size of the shared key
    /// \details SHARED_KEYLENGTH is the size of the shared key, in bytes.
    CRYPTOPP_CONSTANT(SHARED_KEYLENGTH = 32);

    virtual ~x25519() {}

    /// \brief Create a x25519 object
    /// \details This constructor creates an empty x25519 object. It is
    ///  intended for use in loading existing parameters, like CryptoBox
    ///  parameters. If you are performing key agreement you should use a
    ///   constructor that generates random parameters on construction.
    x25519() {}

    /// \brief Create a x25519 object
    /// \param y public key
    /// \param x private key
    /// \details This constructor creates a x25519 object using existing parameters.
    /// \note The public key is not validated.
    x25519(const byte y[PUBLIC_KEYLENGTH], const byte x[SECRET_KEYLENGTH]);

    /// \brief Create a x25519 object
    /// \param x private key
    /// \details This constructor creates a x25519 object using existing parameters.
    ///  The public key is calculated from the private key.
    x25519(const byte x[SECRET_KEYLENGTH]);

    /// \brief Create a x25519 object
    /// \param y public key
    /// \param x private key
    /// \details This constructor creates a x25519 object using existing parameters.
    /// \note The public key is not validated.
    x25519(const Integer &y, const Integer &x);

    /// \brief Create a x25519 object
    /// \param x private key
    /// \details This constructor creates a x25519 object using existing parameters.
    ///  The public key is calculated from the private key.
    x25519(const Integer &x);

    /// \brief Create a x25519 object
    /// \param rng RandomNumberGenerator derived class
    /// \details This constructor creates a new x25519 using the random number generator.
    x25519(RandomNumberGenerator &rng);

    /// \brief Create a x25519 object
    /// \param params public and private key
    /// \details This constructor creates a x25519 object using existing parameters.
    ///  The <tt>params</tt> can be created with <tt>Save</tt>.
    /// \note The public key is not validated.
    x25519(BufferedTransformation &params);

    /// \brief Create a x25519 object
    /// \param oid an object identifier
    /// \details This constructor creates a new x25519 using the specified OID. The public
    ///  and private points are uninitialized.
    x25519(const OID &oid);

    /// \brief Clamp a private key
    /// \param x private key
    /// \details ClampKeys() clamps a private key and then regenerates the
    ///  public key from the private key.
    void ClampKey(byte x[SECRET_KEYLENGTH]) const;

    /// \brief Determine if private key is clamped
    /// \param x private key
    bool IsClamped(const byte x[SECRET_KEYLENGTH]) const;

    /// \brief Test if a key has small order
    /// \param y public key
    bool IsSmallOrder(const byte y[PUBLIC_KEYLENGTH]) const;

    /// \brief Get the Object Identifier
    /// \return the Object Identifier
    /// \details The default OID is from RFC 8410 using <tt>id-X25519</tt>.
    ///  The default private key format is RFC 5208.
    OID GetAlgorithmID() const {
        return m_oid.Empty() ? ASN1::X25519() : m_oid;
    }

    /// \brief Set the Object Identifier
    /// \param oid the new Object Identifier
    void SetAlgorithmID(const OID& oid) {
        m_oid = oid;
    }

    // CryptoParameters
    bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
    bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
    void AssignFrom(const NameValuePairs &source);

    // CryptoParameters
    CryptoParameters & AccessCryptoParameters() {return *this;}

    /// \brief DER encode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \details Save() will write the OID associated with algorithm or scheme.
    ///  In the case of public and private keys, this function writes the
    ///  subjectPublicKeyInfo parts.
    /// \details The default OID is from RFC 8410 using <tt>id-X25519</tt>.
    ///  The default private key format is RFC 5208, which is the old format.
    ///  The old format provides the best interop, and keys will work
    ///  with OpenSSL.
    /// \sa <A HREF="http://tools.ietf.org/rfc/rfc5958.txt">RFC 5958, Asymmetric
    ///  Key Packages</A>
    void Save(BufferedTransformation &bt) const {
        DEREncode(bt, 0);
    }

    /// \brief DER encode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \param v1 flag indicating v1
    /// \details Save() will write the OID associated with algorithm or scheme.
    ///  In the case of public and private keys, this function writes the
    ///  subjectPublicKeyInfo parts.
    /// \details The default OID is from RFC 8410 using <tt>id-X25519</tt>.
    ///  The default private key format is RFC 5208.
    /// \details v1 means INTEGER 0 is written. INTEGER 0 means
    ///  RFC 5208 format, which is the old format. The old format provides
    ///  the best interop, and keys will work with OpenSSL. The other
    ///  option uses INTEGER 1. INTEGER 1 means RFC 5958 format,
    ///  which is the new format.
    /// \sa <A HREF="http://tools.ietf.org/rfc/rfc5958.txt">RFC 5958, Asymmetric
    ///  Key Packages</A>
    void Save(BufferedTransformation &bt, bool v1) const {
        DEREncode(bt, v1 ? 0 : 1);
    }

    /// \brief BER decode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \sa <A HREF="http://tools.ietf.org/rfc/rfc5958.txt">RFC 5958, Asymmetric
    ///  Key Packages</A>
    void Load(BufferedTransformation &bt) {
        BERDecode(bt);
    }

    // PKCS8PrivateKey
    void BERDecode(BufferedTransformation &bt);
    void DEREncode(BufferedTransformation &bt) const { DEREncode(bt, 0); }
    void BERDecodePrivateKey(BufferedTransformation &bt, bool parametersPresent, size_t size);
    void DEREncodePrivateKey(BufferedTransformation &bt) const;

    /// \brief DER encode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \param version indicates version
    /// \details DEREncode() will write the OID associated with algorithm or
    ///  scheme. In the case of public and private keys, this function writes
    ///  the subjectPublicKeyInfo parts.
    /// \details The default OID is from RFC 8410 using <tt>id-X25519</tt>.
    ///  The default private key format is RFC 5208.
    /// \details The value of version is written as the INTEGER. INTEGER 0 means
    ///  RFC 5208 format, which is the old format. The old format provides
    ///  the best interop, and keys will work with OpenSSL. The INTEGER 1
    ///  means RFC 5958 format, which is the new format.
    void DEREncode(BufferedTransformation &bt, int version) const;

    /// \brief Determine if OID is valid for this object
    /// \details BERDecodeAndCheckAlgorithmID() parses the OID from
    ///  <tt>bt</tt> and determines if it valid for this object. The
    ///  problem in practice is there are multiple OIDs available to
    ///  denote curve25519 operations. The OIDs include an old GNU
    ///  OID used by SSH, OIDs specified in draft-josefsson-pkix-newcurves,
    ///  and OIDs specified in draft-ietf-curdle-pkix.
    /// \details By default BERDecodeAndCheckAlgorithmID() accepts an
    ///  OID set by the user, <tt>ASN1::curve25519()</tt> and <tt>ASN1::X25519()</tt>.
    ///  <tt>ASN1::curve25519()</tt> is generic and says "this key is valid for
    ///  curve25519 operations". <tt>ASN1::X25519()</tt> is specific and says
    ///  "this key is valid for x25519 key exchange."
    void BERDecodeAndCheckAlgorithmID(BufferedTransformation& bt);

    // DL_PrivateKey
    void GenerateRandom(RandomNumberGenerator &rng, const NameValuePairs &params);

    // SimpleKeyAgreementDomain
    unsigned int AgreedValueLength() const {return SHARED_KEYLENGTH;}
    unsigned int PrivateKeyLength() const {return SECRET_KEYLENGTH;}
    unsigned int PublicKeyLength() const {return PUBLIC_KEYLENGTH;}

    // SimpleKeyAgreementDomain
    void GeneratePrivateKey(RandomNumberGenerator &rng, byte *privateKey) const;
    void GeneratePublicKey(RandomNumberGenerator &rng, const byte *privateKey, byte *publicKey) const;
    bool Agree(byte *agreedValue, const byte *privateKey, const byte *otherPublicKey, bool validateOtherPublicKey=true) const;

protected:
    // Create a public key from a private key
    void SecretToPublicKey(byte y[PUBLIC_KEYLENGTH], const byte x[SECRET_KEYLENGTH]) const;

protected:
    FixedSizeSecBlock<byte, SECRET_KEYLENGTH> m_sk;
    FixedSizeSecBlock<byte, PUBLIC_KEYLENGTH> m_pk;
    OID m_oid;  // preferred OID
};

// ****************** ed25519 Signer *********************** //

/// \brief ed25519 message accumulator
/// \details ed25519 buffers the entire message, and does not
///  digest the message incrementally. You should be careful with
///  large messages like files on-disk. The behavior is by design
///  because Bernstein feels small messages should be authenticated;
///  and larger messages will be digested by the application.
/// \details The accumulator is used for signing and verification.
///  The first 64-bytes of storage is reserved for the signature.
///  During signing the signature storage is unused. During
///  verification the first 64 bytes holds the signature. The
///  signature is provided by the PK_Verifier framework and the
///  call to PK_Signer::InputSignature. Member functions data()
///  and size() refer to the accumulated message. Member function
///  signature() refers to the signature with an implicit size of
///  SIGNATURE_LENGTH bytes.
/// \details Applications which digest large messages, like an ISO
///  disk file, should take care because the design effectively
///  disgorges the format operation from the signing operation.
///  Put another way, be careful to ensure what you are signing is
///  is in fact a digest of the intended message, and not a different
///  message digest supplied by an attacker.
struct ed25519_MessageAccumulator : public PK_MessageAccumulator
{
    CRYPTOPP_CONSTANT(RESERVE_SIZE=2048+64);
    CRYPTOPP_CONSTANT(SIGNATURE_LENGTH=64);

    /// \brief Create a message accumulator
    ed25519_MessageAccumulator() {
        Restart();
    }

    /// \brief Create a message accumulator
    /// \details ed25519 does not use a RNG. You can safely use
    ///  NullRNG() because IsProbablistic returns false.
    ed25519_MessageAccumulator(RandomNumberGenerator &rng) {
        CRYPTOPP_UNUSED(rng); Restart();
    }

    /// \brief Add data to the accumulator
    /// \param msg pointer to the data to accumulate
    /// \param len the size of the data, in bytes
    void Update(const byte* msg, size_t len) {
        if (msg && len)
            m_msg.insert(m_msg.end(), msg, msg+len);
    }

    /// \brief Reset the accumulator
    void Restart() {
        m_msg.reserve(RESERVE_SIZE);
        m_msg.resize(SIGNATURE_LENGTH);
    }

    /// \brief Retrieve pointer to signature buffer
    /// \return pointer to signature buffer
    byte* signature() {
        return &m_msg[0];
    }

    /// \brief Retrieve pointer to signature buffer
    /// \return pointer to signature buffer
    const byte* signature() const {
        return &m_msg[0];
    }

    /// \brief Retrieve pointer to data buffer
    /// \return pointer to data buffer
    const byte* data() const {
        return &m_msg[0]+SIGNATURE_LENGTH;
    }

    /// \brief Retrieve size of data buffer
    /// \return size of the data buffer, in bytes
    size_t size() const {
        return m_msg.size()-SIGNATURE_LENGTH;
    }

protected:
    // TODO: Find an equivalent Crypto++ structure.
    std::vector<byte, AllocatorWithCleanup<byte> > m_msg;
};

/// \brief Ed25519 private key
/// \details ed25519PrivateKey is somewhat of a hack. It needed to
///  provide DL_PrivateKey interface to fit into the existing
///  framework, but it lacks a lot of the internals of a true
///  DL_PrivateKey. The missing pieces include GroupParameters
///  and Point, which provide the low level field operations
///  found in traditional implementations like NIST curves over
///  prime and binary fields.
/// \details ed25519PrivateKey is also unusual because the
///  class members of interest are byte arrays and not Integers.
///  In addition, the byte arrays are little-endian meaning
///  LSB is at element 0 and the MSB is at element 31.
///  If you call GetPrivateExponent() then the little-endian byte
///  array is converted to a big-endian Integer() so it can be
///  returned the way a caller expects. And calling
///  SetPrivateExponent performs a similar internal conversion.
/// \since Crypto++ 8.0
struct ed25519PrivateKey : public PKCS8PrivateKey
{
    /// \brief Size of the private key
    /// \details SECRET_KEYLENGTH is the size of the private key, in bytes.
    CRYPTOPP_CONSTANT(SECRET_KEYLENGTH = 32);
    /// \brief Size of the public key
    /// \details PUBLIC_KEYLENGTH is the size of the public key, in bytes.
    CRYPTOPP_CONSTANT(PUBLIC_KEYLENGTH = 32);
    /// \brief Size of the signature
    /// \details SIGNATURE_LENGTH is the size of the signature, in bytes.
    ///  ed25519 is a DL-based signature scheme. The signature is the
    ///  concatenation of <tt>r || s</tt>.
    CRYPTOPP_CONSTANT(SIGNATURE_LENGTH = 64);

    virtual ~ed25519PrivateKey() {}

    // CryptoMaterial
    bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
    bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
    void AssignFrom(const NameValuePairs &source);

    // GroupParameters
    OID GetAlgorithmID() const {
        return m_oid.Empty() ? ASN1::Ed25519() : m_oid;
    }

    /// \brief DER encode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \details Save() will write the OID associated with algorithm or scheme.
    ///  In the case of public and private keys, this function writes the
    ///  subjectPublicKeyInfo parts.
    /// \details The default OID is from RFC 8410 using <tt>id-Ed25519</tt>.
    ///  The default private key format is RFC 5208, which is the old format.
    ///  The old format provides the best interop, and keys will work
    ///  with OpenSSL.
    /// \sa <A HREF="http://tools.ietf.org/rfc/rfc5958.txt">RFC 5958, Asymmetric
    ///  Key Packages</A>
    void Save(BufferedTransformation &bt) const {
        DEREncode(bt, 0);
    }

    /// \brief DER encode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \param v1 flag indicating v1
    /// \details Save() will write the OID associated with algorithm or scheme.
    ///  In the case of public and private keys, this function writes the
    ///  subjectPublicKeyInfo parts.
    /// \details The default OID is from RFC 8410 using <tt>id-Ed25519</tt>.
    ///  The default private key format is RFC 5208.
    /// \details v1 means INTEGER 0 is written. INTEGER 0 means
    ///  RFC 5208 format, which is the old format. The old format provides
    ///  the best interop, and keys will work with OpenSSL. The other
    ///  option uses INTEGER 1. INTEGER 1 means RFC 5958 format,
    ///  which is the new format.
    /// \sa <A HREF="http://tools.ietf.org/rfc/rfc5958.txt">RFC 5958, Asymmetric
    ///  Key Packages</A>
    void Save(BufferedTransformation &bt, bool v1) const {
        DEREncode(bt, v1 ? 0 : 1);
    }

    /// \brief BER decode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \sa <A HREF="http://tools.ietf.org/rfc/rfc5958.txt">RFC 5958, Asymmetric
    ///  Key Packages</A>
    void Load(BufferedTransformation &bt) {
        BERDecode(bt);
    }

    /// \brief Initializes a public key from this key
    /// \param pub reference to a public key
    void MakePublicKey(PublicKey &pub) const;

    // PKCS8PrivateKey
    void BERDecode(BufferedTransformation &bt);
    void DEREncode(BufferedTransformation &bt) const { DEREncode(bt, 0); }
    void BERDecodePrivateKey(BufferedTransformation &bt, bool parametersPresent, size_t size);
    void DEREncodePrivateKey(BufferedTransformation &bt) const;

    /// \brief DER encode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \param version indicates version
    /// \details DEREncode() will write the OID associated with algorithm or
    ///  scheme. In the case of public and private keys, this function writes
    ///  the subjectPublicKeyInfo parts.
    /// \details The default OID is from RFC 8410 using <tt>id-X25519</tt>.
    ///  The default private key format is RFC 5208.
    /// \details The value of version is written as the INTEGER. INTEGER 0 means
    ///  RFC 5208 format, which is the old format. The old format provides
    ///  the best interop, and keys will work with OpenSSL. The INTEGER 1
    ///  means RFC 5958 format, which is the new format.
    void DEREncode(BufferedTransformation &bt, int version) const;

    /// \brief Determine if OID is valid for this object
    /// \details BERDecodeAndCheckAlgorithmID() parses the OID from
    ///  <tt>bt</tt> and determines if it valid for this object. The
    ///  problem in practice is there are multiple OIDs available to
    ///  denote curve25519 operations. The OIDs include an old GNU
    ///  OID used by SSH, OIDs specified in draft-josefsson-pkix-newcurves,
    ///  and OIDs specified in draft-ietf-curdle-pkix.
    /// \details By default BERDecodeAndCheckAlgorithmID() accepts an
    ///  OID set by the user, <tt>ASN1::curve25519()</tt> and <tt>ASN1::Ed25519()</tt>.
    ///  <tt>ASN1::curve25519()</tt> is generic and says "this key is valid for
    ///  curve25519 operations". <tt>ASN1::Ed25519()</tt> is specific and says
    ///  "this key is valid for ed25519 signing."
    void BERDecodeAndCheckAlgorithmID(BufferedTransformation& bt);

    // PKCS8PrivateKey
    void GenerateRandom(RandomNumberGenerator &rng, const NameValuePairs &params);
    void SetPrivateExponent(const byte x[SECRET_KEYLENGTH]);
    void SetPrivateExponent(const Integer &x);
    const Integer& GetPrivateExponent() const;

    /// \brief Test if a key has small order
    /// \param y public key
    bool IsSmallOrder(const byte y[PUBLIC_KEYLENGTH]) const;

    /// \brief Retrieve private key byte array
    /// \return the private key byte array
    /// \details GetPrivateKeyBytePtr() is used by signing code to call ed25519_sign.
    const byte* GetPrivateKeyBytePtr() const {
        return m_sk.begin();
    }

    /// \brief Retrieve public key byte array
    /// \return the public key byte array
    /// \details GetPublicKeyBytePtr() is used by signing code to call ed25519_sign.
    const byte* GetPublicKeyBytePtr() const {
        return m_pk.begin();
    }

protected:
    // Create a public key from a private key
    void SecretToPublicKey(byte y[PUBLIC_KEYLENGTH], const byte x[SECRET_KEYLENGTH]) const;

protected:
    FixedSizeSecBlock<byte, SECRET_KEYLENGTH> m_sk;
    FixedSizeSecBlock<byte, PUBLIC_KEYLENGTH> m_pk;
    OID m_oid;  // preferred OID
    mutable Integer m_x;  // for DL_PrivateKey
};

/// \brief Ed25519 signature algorithm
/// \since Crypto++ 8.0
struct ed25519Signer : public PK_Signer
{
    /// \brief Size of the private key
    /// \details SECRET_KEYLENGTH is the size of the private key, in bytes.
    CRYPTOPP_CONSTANT(SECRET_KEYLENGTH = 32);
    /// \brief Size of the public key
    /// \details PUBLIC_KEYLENGTH is the size of the public key, in bytes.
    CRYPTOPP_CONSTANT(PUBLIC_KEYLENGTH = 32);
    /// \brief Size of the signature
    /// \details SIGNATURE_LENGTH is the size of the signature, in bytes.
    ///  ed25519 is a DL-based signature scheme. The signature is the
    ///  concatenation of <tt>r || s</tt>.
    CRYPTOPP_CONSTANT(SIGNATURE_LENGTH = 64);
    typedef Integer Element;

    virtual ~ed25519Signer() {}

    /// \brief Create an ed25519Signer object
    ed25519Signer() {}

    /// \brief Create an ed25519Signer object
    /// \param y public key
    /// \param x private key
    /// \details This constructor creates an ed25519Signer object using existing parameters.
    /// \note The public key is not validated.
    ed25519Signer(const byte y[PUBLIC_KEYLENGTH], const byte x[SECRET_KEYLENGTH]);

    /// \brief Create an ed25519Signer object
    /// \param x private key
    /// \details This constructor creates an ed25519Signer object using existing parameters.
    ///  The public key is calculated from the private key.
    ed25519Signer(const byte x[SECRET_KEYLENGTH]);

    /// \brief Create an ed25519Signer object
    /// \param y public key
    /// \param x private key
    /// \details This constructor creates an ed25519Signer object using existing parameters.
    /// \note The public key is not validated.
    ed25519Signer(const Integer &y, const Integer &x);

    /// \brief Create an ed25519Signer object
    /// \param x private key
    /// \details This constructor creates an ed25519Signer object using existing parameters.
    ///  The public key is calculated from the private key.
    ed25519Signer(const Integer &x);

    /// \brief Create an ed25519Signer object
    /// \param key PKCS8 private key
    /// \details This constructor creates an ed25519Signer object using existing private key.
    /// \note The keys are not validated.
    /// \since Crypto++ 8.6
    ed25519Signer(const PKCS8PrivateKey &key);

    /// \brief Create an ed25519Signer object
    /// \param rng RandomNumberGenerator derived class
    /// \details This constructor creates a new ed25519Signer using the random number generator.
    ed25519Signer(RandomNumberGenerator &rng);

    /// \brief Create an ed25519Signer object
    /// \param params public and private key
    /// \details This constructor creates an ed25519Signer object using existing parameters.
    ///  The <tt>params</tt> can be created with <tt>Save</tt>.
    /// \note The public key is not validated.
    ed25519Signer(BufferedTransformation &params);

    // DL_ObjectImplBase
    /// \brief Retrieves a reference to a Private Key
    /// \details AccessKey() retrieves a non-const reference to a private key.
    PrivateKey& AccessKey() { return m_key; }
    PrivateKey& AccessPrivateKey() { return m_key; }

    /// \brief Retrieves a reference to a Private Key
    /// \details AccessKey() retrieves a const reference to a private key.
    const PrivateKey& GetKey() const { return m_key; }
    const PrivateKey& GetPrivateKey() const { return m_key; }

    // DL_SignatureSchemeBase
    size_t SignatureLength() const { return SIGNATURE_LENGTH; }
    size_t MaxRecoverableLength() const { return 0; }
    size_t MaxRecoverableLengthFromSignatureLength(size_t signatureLength) const {
        CRYPTOPP_UNUSED(signatureLength); return 0;
    }

    bool IsProbabilistic() const { return false; }
    bool AllowNonrecoverablePart() const { return false; }
    bool RecoverablePartFirst() const { return false; }

    PK_MessageAccumulator* NewSignatureAccumulator(RandomNumberGenerator &rng) const {
        return new ed25519_MessageAccumulator(rng);
    }

    void InputRecoverableMessage(PK_MessageAccumulator &messageAccumulator, const byte *recoverableMessage, size_t recoverableMessageLength) const {
        CRYPTOPP_UNUSED(messageAccumulator); CRYPTOPP_UNUSED(recoverableMessage);
        CRYPTOPP_UNUSED(recoverableMessageLength);
        throw NotImplemented("ed25519Signer: this object does not support recoverable messages");
    }

    size_t SignAndRestart(RandomNumberGenerator &rng, PK_MessageAccumulator &messageAccumulator, byte *signature, bool restart) const;

    /// \brief Sign a stream
    /// \param rng a RandomNumberGenerator derived class
    /// \param stream an std::istream derived class
    /// \param signature a block of bytes for the signature
    /// \return actual signature length
    /// \details SignStream() handles large streams. The Stream functions were added to
    ///  ed25519 for signing and verifying files that are too large for a memory allocation.
    ///  The functions are not present in other library signers and verifiers.
    /// \details ed25519 is a deterministic signature scheme. <tt>IsProbabilistic()</tt>
    ///  returns false and the random number generator can be <tt>NullRNG()</tt>.
    /// \pre <tt>COUNTOF(signature) == MaxSignatureLength()</tt>
    /// \since Crypto++ 8.1
    size_t SignStream (RandomNumberGenerator &rng, std::istream& stream, byte *signature) const;

protected:
    ed25519PrivateKey m_key;
};

// ****************** ed25519 Verifier *********************** //

/// \brief Ed25519 public key
/// \details ed25519PublicKey is somewhat of a hack. It needed to
///  provide DL_PublicKey interface to fit into the existing
///  framework, but it lacks a lot of the internals of a true
///  DL_PublicKey. The missing pieces include GroupParameters
///  and Point, which provide the low level field operations
///  found in traditional implementations like NIST curves over
///  prime and binary fields.
/// \details ed25519PublicKey is also unusual because the
///  class members of interest are byte arrays and not Integers.
///  In addition, the byte arrays are little-endian meaning
///  LSB is at element 0 and the MSB is at element 31.
///  If you call GetPublicElement() then the little-endian byte
///  array is converted to a big-endian Integer() so it can be
///  returned the way a caller expects. And calling
///  SetPublicElement() performs a similar internal conversion.
/// \since Crypto++ 8.0
struct ed25519PublicKey : public X509PublicKey
{
    /// \brief Size of the public key
    /// \details PUBLIC_KEYLENGTH is the size of the public key, in bytes.
    CRYPTOPP_CONSTANT(PUBLIC_KEYLENGTH = 32);
    typedef Integer Element;

    virtual ~ed25519PublicKey() {}

    OID GetAlgorithmID() const {
        return m_oid.Empty() ? ASN1::Ed25519() : m_oid;
    }

    /// \brief DER encode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \details Save() will write the OID associated with algorithm or scheme.
    ///  In the case of public and private keys, this function writes the
    ///  subjectPublicKeyInfo parts.
    /// \details The default OID is from RFC 8410 using <tt>id-X25519</tt>.
    ///  The default private key format is RFC 5208, which is the old format.
    ///  The old format provides the best interop, and keys will work
    ///  with OpenSSL.
    void Save(BufferedTransformation &bt) const {
        DEREncode(bt);
    }

    /// \brief BER decode ASN.1 object
    /// \param bt BufferedTransformation object
    /// \sa <A HREF="http://tools.ietf.org/rfc/rfc5958.txt">RFC 5958, Asymmetric
    ///  Key Packages</A>
    void Load(BufferedTransformation &bt) {
        BERDecode(bt);
    }

    // X509PublicKey
    void BERDecode(BufferedTransformation &bt);
    void DEREncode(BufferedTransformation &bt) const;
    void BERDecodePublicKey(BufferedTransformation &bt, bool parametersPresent, size_t size);
    void DEREncodePublicKey(BufferedTransformation &bt) const;

    /// \brief Determine if OID is valid for this object
    /// \details BERDecodeAndCheckAlgorithmID() parses the OID from
    ///  <tt>bt</tt> and determines if it valid for this object. The
    ///  problem in practice is there are multiple OIDs available to
    ///  denote curve25519 operations. The OIDs include an old GNU
    ///  OID used by SSH, OIDs specified in draft-josefsson-pkix-newcurves,
    ///  and OIDs specified in draft-ietf-curdle-pkix.
    /// \details By default BERDecodeAndCheckAlgorithmID() accepts an
    ///  OID set by the user, <tt>ASN1::curve25519()</tt> and <tt>ASN1::Ed25519()</tt>.
    ///  <tt>ASN1::curve25519()</tt> is generic and says "this key is valid for
    ///  curve25519 operations". <tt>ASN1::Ed25519()</tt> is specific and says
    ///  "this key is valid for ed25519 signing."
    void BERDecodeAndCheckAlgorithmID(BufferedTransformation& bt);

    bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
    bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
    void AssignFrom(const NameValuePairs &source);

    // DL_PublicKey
    void SetPublicElement(const byte y[PUBLIC_KEYLENGTH]);
    void SetPublicElement(const Element &y);
    const Element& GetPublicElement() const;

    /// \brief Retrieve public key byte array
    /// \return the public key byte array
    /// \details GetPublicKeyBytePtr() is used by signing code to call ed25519_sign.
    const byte* GetPublicKeyBytePtr() const {
        return m_pk.begin();
    }

protected:
    FixedSizeSecBlock<byte, PUBLIC_KEYLENGTH> m_pk;
    OID m_oid;  // preferred OID
    mutable Integer m_y;  // for DL_PublicKey
};

/// \brief Ed25519 signature verification algorithm
/// \since Crypto++ 8.0
struct ed25519Verifier : public PK_Verifier
{
    CRYPTOPP_CONSTANT(PUBLIC_KEYLENGTH = 32);
    CRYPTOPP_CONSTANT(SIGNATURE_LENGTH = 64);
    typedef Integer Element;

    virtual ~ed25519Verifier() {}

    /// \brief Create an ed25519Verifier object
    ed25519Verifier() {}

    /// \brief Create an ed25519Verifier object
    /// \param y public key
    /// \details This constructor creates an ed25519Verifier object using existing parameters.
    /// \note The public key is not validated.
    ed25519Verifier(const byte y[PUBLIC_KEYLENGTH]);

    /// \brief Create an ed25519Verifier object
    /// \param y public key
    /// \details This constructor creates an ed25519Verifier object using existing parameters.
    /// \note The public key is not validated.
    ed25519Verifier(const Integer &y);

    /// \brief Create an ed25519Verifier object
    /// \param key X509 public key
    /// \details This constructor creates an ed25519Verifier object using an existing public key.
    /// \note The public key is not validated.
    /// \since Crypto++ 8.6
    ed25519Verifier(const X509PublicKey &key);

    /// \brief Create an ed25519Verifier object
    /// \param params public and private key
    /// \details This constructor creates an ed25519Verifier object using existing parameters.
    ///  The <tt>params</tt> can be created with <tt>Save</tt>.
    /// \note The public key is not validated.
    ed25519Verifier(BufferedTransformation &params);

    /// \brief Create an ed25519Verifier object
    /// \param signer ed25519 signer object
    /// \details This constructor creates an ed25519Verifier object using existing parameters.
    ///  The <tt>params</tt> can be created with <tt>Save</tt>.
    /// \note The public key is not validated.
    ed25519Verifier(const ed25519Signer& signer);

    // DL_ObjectImplBase
    /// \brief Retrieves a reference to a Public Key
    /// \details AccessKey() retrieves a non-const reference to a public key.
    PublicKey& AccessKey() { return m_key; }
    PublicKey& AccessPublicKey() { return m_key; }

    /// \brief Retrieves a reference to a Public Key
    /// \details GetKey() retrieves a const reference to a public key.
    const PublicKey& GetKey() const { return m_key; }
    const PublicKey& GetPublicKey() const { return m_key; }

    // DL_SignatureSchemeBase
    size_t SignatureLength() const { return SIGNATURE_LENGTH; }
    size_t MaxRecoverableLength() const { return 0; }
    size_t MaxRecoverableLengthFromSignatureLength(size_t signatureLength) const {
        CRYPTOPP_UNUSED(signatureLength); return 0;
    }

    bool IsProbabilistic() const { return false; }
    bool AllowNonrecoverablePart() const { return false; }
    bool RecoverablePartFirst() const { return false; }

    ed25519_MessageAccumulator* NewVerificationAccumulator() const {
        return new ed25519_MessageAccumulator;
    }

    void InputSignature(PK_MessageAccumulator &messageAccumulator, const byte *signature, size_t signatureLength) const {
        CRYPTOPP_ASSERT(signature != NULLPTR);
        CRYPTOPP_ASSERT(signatureLength == SIGNATURE_LENGTH);
        ed25519_MessageAccumulator& accum = static_cast<ed25519_MessageAccumulator&>(messageAccumulator);
        if (signature && signatureLength)
            std::memcpy(accum.signature(), signature, STDMIN((size_t)SIGNATURE_LENGTH, signatureLength));
    }

    bool VerifyAndRestart(PK_MessageAccumulator &messageAccumulator) const;

    /// \brief Check whether input signature is a valid signature for input message
    /// \param stream an std::istream derived class
    /// \param signature a pointer to the signature over the message
    /// \param signatureLen the size of the signature
    /// \return true if the signature is valid, false otherwise
    /// \details VerifyStream() handles large streams. The Stream functions were added to
    ///  ed25519 for signing and verifying files that are too large for a memory allocation.
    ///  The functions are not present in other library signers and verifiers.
    /// \since Crypto++ 8.1
    bool VerifyStream(std::istream& stream, const byte *signature, size_t signatureLen) const;

    DecodingResult RecoverAndRestart(byte *recoveredMessage, PK_MessageAccumulator &messageAccumulator) const {
        CRYPTOPP_UNUSED(recoveredMessage); CRYPTOPP_UNUSED(messageAccumulator);
        throw NotImplemented("ed25519Verifier: this object does not support recoverable messages");
    }

protected:
    ed25519PublicKey m_key;
};

/// \brief Ed25519 signature scheme
/// \sa <A HREF="http://cryptopp.com/wiki/Ed25519">Ed25519</A> on the Crypto++ wiki.
/// \since Crypto++ 8.0
struct ed25519
{
    /// \brief ed25519 Signer
    typedef ed25519Signer Signer;
    /// \brief ed25519 Verifier
    typedef ed25519Verifier Verifier;
};

NAMESPACE_END  // CryptoPP

#endif  // CRYPTOPP_XED25519_H
