// hmqv.h - written and placed in the public domain by Uri Blumenthal
//          Shamelessly based upon Wei Dai's MQV source files

#ifndef CRYPTOPP_HMQV_H
#define CRYPTOPP_HMQV_H

/// \file hmqv.h
/// \brief Classes for Hashed Menezes-Qu-Vanstone key agreement in GF(p)
/// \since Crypto++ 5.6.4

#include "gfpcrypt.h"
#include "algebra.h"
#include "sha.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Hashed Menezes-Qu-Vanstone in GF(p)
/// \details This implementation follows Hugo Krawczyk's <a href="http://eprint.iacr.org/2005/176">HMQV: A High-Performance
///   Secure Diffie-Hellman Protocol</a>. Note: this implements HMQV only. HMQV-C with Key Confirmation is not provided.
/// \sa MQV, HMQV, FHMQV, and AuthenticatedKeyAgreementDomain
/// \since Crypto++ 5.6.4
template <class GROUP_PARAMETERS, class COFACTOR_OPTION = typename GROUP_PARAMETERS::DefaultCofactorOption, class HASH = SHA512>
class HMQV_Domain: public AuthenticatedKeyAgreementDomain
{
public:
  typedef GROUP_PARAMETERS GroupParameters;
  typedef typename GroupParameters::Element Element;
  typedef HMQV_Domain<GROUP_PARAMETERS, COFACTOR_OPTION, HASH> Domain;

  virtual ~HMQV_Domain() {}

  /// \brief Construct a HMQV domain
  /// \param clientRole flag indicating initiator or recipient
  /// \details <tt>clientRole = true</tt> indicates initiator, and
  ///  <tt>clientRole = false</tt> indicates recipient or server.
  HMQV_Domain(bool clientRole = true)
    : m_role(clientRole ? RoleClient : RoleServer) {}

  /// \brief Construct a HMQV domain
  /// \param params group parameters and options
  /// \param clientRole flag indicating initiator or recipient
  /// \details <tt>clientRole = true</tt> indicates initiator, and
  ///  <tt>clientRole = false</tt> indicates recipient or server.
  HMQV_Domain(const GroupParameters &params, bool clientRole = true)
    : m_role(clientRole ? RoleClient : RoleServer), m_groupParameters(params) {}

  /// \brief Construct a HMQV domain
  /// \param bt BufferedTransformation with group parameters and options
  /// \param clientRole flag indicating initiator or recipient
  /// \details <tt>clientRole = true</tt> indicates initiator, and
  ///  <tt>clientRole = false</tt> indicates recipient or server.
  HMQV_Domain(BufferedTransformation &bt, bool clientRole = true)
    : m_role(clientRole ? RoleClient : RoleServer)
    {m_groupParameters.BERDecode(bt);}

  /// \brief Construct a HMQV domain
  /// \tparam T1 template parameter used as a constructor parameter
  /// \param v1 first parameter
  /// \param clientRole flag indicating initiator or recipient
  /// \details v1 is passed directly to the GROUP_PARAMETERS object.
  /// \details <tt>clientRole = true</tt> indicates initiator, and
  ///  <tt>clientRole = false</tt> indicates recipient or server.
  template <class T1>
  HMQV_Domain(T1 v1, bool clientRole = true)
    : m_role(clientRole ? RoleClient : RoleServer)
    {m_groupParameters.Initialize(v1);}

  /// \brief Construct a HMQV domain
  /// \tparam T1 template parameter used as a constructor parameter
  /// \tparam T2 template parameter used as a constructor parameter
  /// \param v1 first parameter
  /// \param v2 second parameter
  /// \param clientRole flag indicating initiator or recipient
  /// \details v1 and v2 are passed directly to the GROUP_PARAMETERS object.
  /// \details <tt>clientRole = true</tt> indicates initiator, and
  ///  <tt>clientRole = false</tt> indicates recipient or server.
  template <class T1, class T2>
  HMQV_Domain(T1 v1, T2 v2, bool clientRole = true)
    : m_role(clientRole ? RoleClient : RoleServer)
    {m_groupParameters.Initialize(v1, v2);}

  /// \brief Construct a HMQV domain
  /// \tparam T1 template parameter used as a constructor parameter
  /// \tparam T2 template parameter used as a constructor parameter
  /// \tparam T3 template parameter used as a constructor parameter
  /// \param v1 first parameter
  /// \param v2 second parameter
  /// \param v3 third parameter
  /// \param clientRole flag indicating initiator or recipient
  /// \details v1, v2 and v3 are passed directly to the GROUP_PARAMETERS object.
  /// \details <tt>clientRole = true</tt> indicates initiator, and
  ///  <tt>clientRole = false</tt> indicates recipient or server.
  template <class T1, class T2, class T3>
  HMQV_Domain(T1 v1, T2 v2, T3 v3, bool clientRole = true)
    : m_role(clientRole ? RoleClient : RoleServer)
    {m_groupParameters.Initialize(v1, v2, v3);}

  /// \brief Construct a HMQV domain
  /// \tparam T1 template parameter used as a constructor parameter
  /// \tparam T2 template parameter used as a constructor parameter
  /// \tparam T3 template parameter used as a constructor parameter
  /// \tparam T4 template parameter used as a constructor parameter
  /// \param v1 first parameter
  /// \param v2 second parameter
  /// \param v3 third parameter
  /// \param v4 third parameter
  /// \param clientRole flag indicating initiator or recipient
  /// \details v1, v2, v3 and v4 are passed directly to the GROUP_PARAMETERS object.
  /// \details <tt>clientRole = true</tt> indicates initiator, and
  ///  <tt>clientRole = false</tt> indicates recipient or server.
  template <class T1, class T2, class T3, class T4>
  HMQV_Domain(T1 v1, T2 v2, T3 v3, T4 v4, bool clientRole = true)
    : m_role(clientRole ? RoleClient : RoleServer)
    {m_groupParameters.Initialize(v1, v2, v3, v4);}

public:

  /// \brief Retrieves the group parameters for this domain
  /// \return the group parameters for this domain as a const reference
  const GroupParameters & GetGroupParameters() const {return m_groupParameters;}

  /// \brief Retrieves the group parameters for this domain
  /// \return the group parameters for this domain as a non-const reference
  GroupParameters & AccessGroupParameters() {return m_groupParameters;}

  /// \brief Retrieves the crypto parameters for this domain
  /// \return the crypto parameters for this domain as a non-const reference
  CryptoParameters & AccessCryptoParameters() {return AccessAbstractGroupParameters();}

  /// \brief Provides the size of the agreed value
  /// \return size of agreed value produced in this domain
  /// \details The length is calculated using <tt>GetEncodedElementSize(false)</tt>,
  ///  which means the element is encoded in a non-reversible format. A
  ///  non-reversible format means its a raw byte array, and it lacks presentation
  ///  format like an ASN.1 BIT_STRING or OCTET_STRING.
  unsigned int AgreedValueLength() const
    {return GetAbstractGroupParameters().GetEncodedElementSize(false);}

  /// \brief Provides the size of the static private key
  /// \return size of static private keys in this domain
  /// \details The length is calculated using the byte count of the subgroup order.
  unsigned int StaticPrivateKeyLength() const
    {return GetAbstractGroupParameters().GetSubgroupOrder().ByteCount();}

  /// \brief Provides the size of the static public key
  /// \return size of static public keys in this domain
  /// \details The length is calculated using <tt>GetEncodedElementSize(true)</tt>,
  ///  which means the element is encoded in a reversible format. A reversible
  ///  format means it has a presentation format, and its an ANS.1 encoded element
  ///  or point.
  unsigned int StaticPublicKeyLength() const
    {return GetAbstractGroupParameters().GetEncodedElementSize(true);}

  /// \brief Generate static private key in this domain
  /// \param rng a RandomNumberGenerator derived class
  /// \param privateKey a byte buffer for the generated private key in this domain
  /// \details The private key is a random scalar used as an exponent in the range
  ///  <tt>[1,MaxExponent()]</tt>.
  /// \pre <tt>COUNTOF(privateKey) == PrivateStaticKeyLength()</tt>
  void GenerateStaticPrivateKey(RandomNumberGenerator &rng, byte *privateKey) const
  {
    Integer x(rng, Integer::One(), GetAbstractGroupParameters().GetMaxExponent());
    x.Encode(privateKey, StaticPrivateKeyLength());
  }

  /// \brief Generate a static public key from a private key in this domain
  /// \param rng a RandomNumberGenerator derived class
  /// \param privateKey a byte buffer with the previously generated private key
  /// \param publicKey a byte buffer for the generated public key in this domain
  /// \details The public key is an element or point on the curve, and its stored
  ///  in a revrsible format. A reversible format means it has a presentation
  ///  format, and its an ANS.1 encoded element or point.
  /// \pre <tt>COUNTOF(publicKey) == PublicStaticKeyLength()</tt>
  void GenerateStaticPublicKey(RandomNumberGenerator &rng, const byte *privateKey, byte *publicKey) const
  {
    CRYPTOPP_UNUSED(rng);
    const DL_GroupParameters<Element> &params = GetAbstractGroupParameters();
    Integer x(privateKey, StaticPrivateKeyLength());
    Element y = params.ExponentiateBase(x);
    params.EncodeElement(true, y, publicKey);
  }

  /// \brief Provides the size of the ephemeral private key
  /// \return size of ephemeral private keys in this domain
  /// \details An ephemeral private key is a private key and public key.
  ///  The serialized size is different than a static private key.
  unsigned int EphemeralPrivateKeyLength() const {return StaticPrivateKeyLength() + StaticPublicKeyLength();}

  /// \brief Provides the size of the ephemeral public key
  /// \return size of ephemeral public keys in this domain
  /// \details An ephemeral public key is a public key.
  ///  The serialized size is the same as a static public key.
  unsigned int EphemeralPublicKeyLength() const{return StaticPublicKeyLength();}

  /// \brief Generate ephemeral private key in this domain
  /// \param rng a RandomNumberGenerator derived class
  /// \param privateKey a byte buffer for the generated private key in this domain
  /// \pre <tt>COUNTOF(privateKey) == EphemeralPrivateKeyLength()</tt>
  void GenerateEphemeralPrivateKey(RandomNumberGenerator &rng, byte *privateKey) const
  {
    const DL_GroupParameters<Element> &params = GetAbstractGroupParameters();
    Integer x(rng, Integer::One(), params.GetMaxExponent());
    x.Encode(privateKey, StaticPrivateKeyLength());
    Element y = params.ExponentiateBase(x);
    params.EncodeElement(true, y, privateKey+StaticPrivateKeyLength());
  }

  /// \brief Generate ephemeral public key from a private key in this domain
  /// \param rng a RandomNumberGenerator derived class
  /// \param privateKey a byte buffer with the previously generated private key
  /// \param publicKey a byte buffer for the generated public key in this domain
  /// \pre <tt>COUNTOF(publicKey) == EphemeralPublicKeyLength()</tt>
  void GenerateEphemeralPublicKey(RandomNumberGenerator &rng, const byte *privateKey, byte *publicKey) const
  {
    CRYPTOPP_UNUSED(rng);
    std::memcpy(publicKey, privateKey+StaticPrivateKeyLength(), EphemeralPublicKeyLength());
  }

  /// \brief Derive agreed value or shared secret
  /// \param agreedValue the shared secret
  /// \param staticPrivateKey your long term private key
  /// \param ephemeralPrivateKey your ephemeral private key
  /// \param staticOtherPublicKey couterparty's long term public key
  /// \param ephemeralOtherPublicKey couterparty's ephemeral public key
  /// \param validateStaticOtherPublicKey flag indicating validation
  /// \return true upon success, false in case of failure
  /// \details Agree() performs the authenticated key agreement. Agree()
  ///  derives a shared secret from your private keys and couterparty's
  ///  public keys. Each instance or run of the protocol should use a new
  ///  ephemeral key pair.
  /// \details The other's ephemeral public key will always be validated at
  ///  Level 1 to ensure it is a point on the curve.
  ///  <tt>validateStaticOtherPublicKey</tt> determines how thoroughly other's
  ///  static public key is validated. If you have previously validated the
  ///  couterparty's static public key, then use
  ///  <tt>validateStaticOtherPublicKey=false</tt> to save time.
  /// \pre <tt>COUNTOF(agreedValue) == AgreedValueLength()</tt>
  /// \pre <tt>COUNTOF(staticPrivateKey) == StaticPrivateKeyLength()</tt>
  /// \pre <tt>COUNTOF(ephemeralPrivateKey) == EphemeralPrivateKeyLength()</tt>
  /// \pre <tt>COUNTOF(staticOtherPublicKey) == StaticPublicKeyLength()</tt>
  /// \pre <tt>COUNTOF(ephemeralOtherPublicKey) == EphemeralPublicKeyLength()</tt>
  bool Agree(byte *agreedValue,
    const byte *staticPrivateKey, const byte *ephemeralPrivateKey,
    const byte *staticOtherPublicKey, const byte *ephemeralOtherPublicKey,
    bool validateStaticOtherPublicKey=true) const
  {
    const byte *XX = NULLPTR, *YY = NULLPTR, *AA = NULLPTR, *BB = NULLPTR;
    size_t xxs = 0, yys = 0, aas = 0, bbs = 0;

    // Depending on the role, this will hold either A's or B's static
    // (long term) public key. AA or BB will then point into tt.
    SecByteBlock tt(StaticPublicKeyLength());

    try
    {
      this->GetMaterial().DoQuickSanityCheck();
      const DL_GroupParameters<Element> &params = GetAbstractGroupParameters();

      if(m_role == RoleServer)
      {
        Integer b(staticPrivateKey, StaticPrivateKeyLength());
        Element B = params.ExponentiateBase(b);
        params.EncodeElement(true, B, tt);

        XX = ephemeralOtherPublicKey;
        xxs = EphemeralPublicKeyLength();
        YY = ephemeralPrivateKey + StaticPrivateKeyLength();
        yys = EphemeralPublicKeyLength();
        AA = staticOtherPublicKey;
        aas = StaticPublicKeyLength();
        BB = tt.BytePtr();
        bbs = tt.SizeInBytes();
      }
      else
      {
        Integer a(staticPrivateKey, StaticPrivateKeyLength());
        Element A = params.ExponentiateBase(a);
        params.EncodeElement(true, A, tt);

        XX = ephemeralPrivateKey + StaticPrivateKeyLength();
        xxs = EphemeralPublicKeyLength();
        YY = ephemeralOtherPublicKey;
        yys = EphemeralPublicKeyLength();
        AA = tt.BytePtr();
        aas = tt.SizeInBytes();
        BB = staticOtherPublicKey;
        bbs = StaticPublicKeyLength();
      }

      Element VV1 = params.DecodeElement(staticOtherPublicKey, validateStaticOtherPublicKey);
      Element VV2 = params.DecodeElement(ephemeralOtherPublicKey, true);

      const Integer& q = params.GetSubgroupOrder();
      const unsigned int len /*bytes*/ = (((q.BitCount()+1)/2 +7)/8);
      SecByteBlock dd(len), ee(len);

      // Compute $d = \hat{H}(X, \hat{B})$
      Hash(NULLPTR, XX, xxs, BB, bbs, dd.BytePtr(), dd.SizeInBytes());
      Integer d(dd.BytePtr(), dd.SizeInBytes());

      // Compute $e = \hat{H}(Y, \hat{A})$
      Hash(NULLPTR, YY, yys, AA, aas, ee.BytePtr(), ee.SizeInBytes());
      Integer e(ee.BytePtr(), ee.SizeInBytes());

      Element sigma;
      if(m_role == RoleServer)
      {
        Integer y(ephemeralPrivateKey, StaticPrivateKeyLength());
        Integer b(staticPrivateKey, StaticPrivateKeyLength());
        Integer s_B = (y + e * b) % q;

        Element A = params.DecodeElement(AA, false);
        Element X = params.DecodeElement(XX, false);

        Element t1 = params.ExponentiateElement(A, d);
        Element t2 = m_groupParameters.MultiplyElements(X, t1);

        // $\sigma_B}=(X \cdot A^{d})^{s_B}
        sigma = params.ExponentiateElement(t2, s_B);
      }
      else
      {
        Integer x(ephemeralPrivateKey, StaticPrivateKeyLength());
        Integer a(staticPrivateKey, StaticPrivateKeyLength());
        Integer s_A = (x + d * a) % q;

        Element B = params.DecodeElement(BB, false);
        Element Y = params.DecodeElement(YY, false);

        Element t3 = params.ExponentiateElement(B, e);
        Element t4 = m_groupParameters.MultiplyElements(Y, t3);

        // $\sigma_A}=(Y \cdot B^{e})^{s_A}
        sigma = params.ExponentiateElement(t4, s_A);
      }
      Hash(&sigma, NULLPTR, 0, NULLPTR, 0, agreedValue, AgreedValueLength());
    }
    catch (DL_BadElement &)
    {
      CRYPTOPP_ASSERT(0);
      return false;
    }
    return true;
  }

protected:
  // Hash invocation by client and server differ only in what keys
  // each provides.

  inline void Hash(const Element* sigma,
    const byte* e1, size_t e1len, // Ephemeral key and key length
    const byte* s1, size_t s1len, // Static key and key length
    byte* digest, size_t dlen) const
  {
    HASH hash;
    size_t idx = 0, req = dlen;
    size_t blk = STDMIN(dlen, (size_t)HASH::DIGESTSIZE);

    if(sigma)
    {
      if (e1len != 0 || s1len != 0) {
        CRYPTOPP_ASSERT(0);
      }
      //Integer x = GetAbstractGroupParameters().ConvertElementToInteger(*sigma);
      //SecByteBlock sbb(x.MinEncodedSize());
      //x.Encode(sbb.BytePtr(), sbb.SizeInBytes());
      SecByteBlock sbb(GetAbstractGroupParameters().GetEncodedElementSize(false));
      GetAbstractGroupParameters().EncodeElement(false, *sigma, sbb);
      hash.Update(sbb.BytePtr(), sbb.SizeInBytes());
    } else {
      if (e1len == 0 || s1len == 0) {
        CRYPTOPP_ASSERT(0);
      }
      hash.Update(e1, e1len);
      hash.Update(s1, s1len);
    }

    hash.TruncatedFinal(digest, blk);
    req -= blk;

    // All this to catch tail bytes for large curves and small hashes
    while(req != 0)
    {
      hash.Update(&digest[idx], (size_t)HASH::DIGESTSIZE);

      idx += (size_t)HASH::DIGESTSIZE;
      blk = STDMIN(req, (size_t)HASH::DIGESTSIZE);
      hash.TruncatedFinal(&digest[idx], blk);

      req -= blk;
    }
  }

private:

  // The paper uses Initiator and Recipient - make it classical.
  enum KeyAgreementRole { RoleServer = 1, RoleClient };

  DL_GroupParameters<Element> & AccessAbstractGroupParameters()
    {return m_groupParameters;}
  const DL_GroupParameters<Element> & GetAbstractGroupParameters() const
    {return m_groupParameters;}

  GroupParameters m_groupParameters;
  KeyAgreementRole m_role;
};

/// \brief Hashed Menezes-Qu-Vanstone in GF(p)
/// \details This implementation follows Hugo Krawczyk's <a href="http://eprint.iacr.org/2005/176">HMQV: A High-Performance
///   Secure Diffie-Hellman Protocol</a>. Note: this implements HMQV only. HMQV-C with Key Confirmation is not provided.
/// \sa HMQV, HMQV_Domain, FHMQV_Domain, AuthenticatedKeyAgreementDomain
/// \since Crypto++ 5.6.4
typedef HMQV_Domain<DL_GroupParameters_GFP_DefaultSafePrime> HMQV;

NAMESPACE_END

#endif
