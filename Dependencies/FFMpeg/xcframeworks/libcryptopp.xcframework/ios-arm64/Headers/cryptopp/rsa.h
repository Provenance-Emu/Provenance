// rsa.h - originally written and placed in the public domain by Wei Dai

/// \file rsa.h
/// \brief Classes for the RSA cryptosystem
/// \details This file contains classes that implement the RSA
///   ciphers and signature schemes as defined in PKCS #1 v2.0.

#ifndef CRYPTOPP_RSA_H
#define CRYPTOPP_RSA_H

#include "cryptlib.h"
#include "pubkey.h"
#include "integer.h"
#include "pkcspad.h"
#include "oaep.h"
#include "emsa2.h"
#include "asn.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief RSA trapdoor function using the public key
/// \since Crypto++ 1.0
class CRYPTOPP_DLL RSAFunction : public TrapdoorFunction, public X509PublicKey
{
	typedef RSAFunction ThisClass;

public:
	/// \brief Initialize a RSA public key
	/// \param n the modulus
	/// \param e the public exponent
	void Initialize(const Integer &n, const Integer &e)
		{m_n = n; m_e = e;}

	// X509PublicKey
	OID GetAlgorithmID() const;
	void BERDecodePublicKey(BufferedTransformation &bt, bool parametersPresent, size_t size);
	void DEREncodePublicKey(BufferedTransformation &bt) const;

	// CryptoMaterial
	bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
	bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
	void AssignFrom(const NameValuePairs &source);

	// TrapdoorFunction
	Integer ApplyFunction(const Integer &x) const;
	Integer PreimageBound() const {return m_n;}
	Integer ImageBound() const {return m_n;}

	// non-derived
	const Integer & GetModulus() const {return m_n;}
	const Integer & GetPublicExponent() const {return m_e;}

	void SetModulus(const Integer &n) {m_n = n;}
	void SetPublicExponent(const Integer &e) {m_e = e;}

protected:
	Integer m_n, m_e;
};

/// \brief RSA trapdoor function using the private key
/// \since Crypto++ 1.0
class CRYPTOPP_DLL InvertibleRSAFunction : public RSAFunction, public TrapdoorFunctionInverse, public PKCS8PrivateKey
{
	typedef InvertibleRSAFunction ThisClass;

public:
	/// \brief Create a RSA private key
	/// \param rng a RandomNumberGenerator derived class
	/// \param modulusBits the size of the modulus, in bits
	/// \param e the desired public exponent
	/// \details Initialize() creates a new keypair using a public exponent of 17.
	/// \details This function overload of Initialize() creates a new private key because it
	///   takes a RandomNumberGenerator() as a parameter. If you have an existing keypair,
	///   then use one of the other Initialize() overloads.
	void Initialize(RandomNumberGenerator &rng, unsigned int modulusBits, const Integer &e = 17);

	/// \brief Initialize a RSA private key
	/// \param n modulus
	/// \param e public exponent
	/// \param d private exponent
	/// \param p first prime factor
	/// \param q second prime factor
	/// \param dp d mod p
	/// \param dq d mod q
	/// \param u q<sup>-1</sup> mod p
	/// \details This Initialize() function overload initializes a private key from existing parameters.
	void Initialize(const Integer &n, const Integer &e, const Integer &d, const Integer &p, const Integer &q, const Integer &dp, const Integer &dq, const Integer &u)
		{m_n = n; m_e = e; m_d = d; m_p = p; m_q = q; m_dp = dp; m_dq = dq; m_u = u;}

	/// \brief Initialize a RSA private key
	/// \param n modulus
	/// \param e public exponent
	/// \param d private exponent
	/// \details This Initialize() function overload initializes a private key from existing parameters.
	///   Initialize() will factor n using d and populate {p,q,dp,dq,u}.
	void Initialize(const Integer &n, const Integer &e, const Integer &d);

	// PKCS8PrivateKey
	void BERDecode(BufferedTransformation &bt)
		{PKCS8PrivateKey::BERDecode(bt);}
	void DEREncode(BufferedTransformation &bt) const
		{PKCS8PrivateKey::DEREncode(bt);}
	void Load(BufferedTransformation &bt)
		{PKCS8PrivateKey::BERDecode(bt);}
	void Save(BufferedTransformation &bt) const
		{PKCS8PrivateKey::DEREncode(bt);}
	OID GetAlgorithmID() const {return RSAFunction::GetAlgorithmID();}
	void BERDecodePrivateKey(BufferedTransformation &bt, bool parametersPresent, size_t size);
	void DEREncodePrivateKey(BufferedTransformation &bt) const;

	// TrapdoorFunctionInverse
	Integer CalculateInverse(RandomNumberGenerator &rng, const Integer &x) const;

	// GeneratableCryptoMaterial
	bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
	// parameters: (ModulusSize, PublicExponent (default 17))
	void GenerateRandom(RandomNumberGenerator &rng, const NameValuePairs &alg);
	bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
	void AssignFrom(const NameValuePairs &source);

	// non-derived interface
	const Integer& GetPrime1() const {return m_p;}
	const Integer& GetPrime2() const {return m_q;}
	const Integer& GetPrivateExponent() const {return m_d;}
	const Integer& GetModPrime1PrivateExponent() const {return m_dp;}
	const Integer& GetModPrime2PrivateExponent() const {return m_dq;}
	const Integer& GetMultiplicativeInverseOfPrime2ModPrime1() const {return m_u;}

	void SetPrime1(const Integer &p) {m_p = p;}
	void SetPrime2(const Integer &q) {m_q = q;}
	void SetPrivateExponent(const Integer &d) {m_d = d;}
	void SetModPrime1PrivateExponent(const Integer &dp) {m_dp = dp;}
	void SetModPrime2PrivateExponent(const Integer &dq) {m_dq = dq;}
	void SetMultiplicativeInverseOfPrime2ModPrime1(const Integer &u) {m_u = u;}

protected:
	Integer m_d, m_p, m_q, m_dp, m_dq, m_u;
};

/// \brief RSA trapdoor function using the public key
/// \since Crypto++ 1.0
class CRYPTOPP_DLL RSAFunction_ISO : public RSAFunction
{
public:
	Integer ApplyFunction(const Integer &x) const;
	Integer PreimageBound() const {return ++(m_n>>1);}
};

/// \brief RSA trapdoor function using the private key
/// \since Crypto++ 1.0
class CRYPTOPP_DLL InvertibleRSAFunction_ISO : public InvertibleRSAFunction
{
public:
	Integer CalculateInverse(RandomNumberGenerator &rng, const Integer &x) const;
	Integer PreimageBound() const {return ++(m_n>>1);}
};

/// \brief RSA algorithm
/// \since Crypto++ 1.0
struct CRYPTOPP_DLL RSA
{
	CRYPTOPP_STATIC_CONSTEXPR const char* CRYPTOPP_API StaticAlgorithmName() {return "RSA";}
	typedef RSAFunction PublicKey;
	typedef InvertibleRSAFunction PrivateKey;
};

/// \brief RSA encryption algorithm
/// \tparam STANDARD signature standard
/// \sa <a href="http://www.weidai.com/scan-mirror/ca.html#RSA">RSA cryptosystem</a>
/// \since Crypto++ 1.0
template <class STANDARD>
struct RSAES : public TF_ES<RSA, STANDARD>
{
};

/// \brief RSA signature algorithm
/// \tparam STANDARD signature standard
/// \tparam H hash transformation
/// \details See documentation of PKCS1v15 for a list of hash functions that can be used with it.
/// \sa <a href="http://www.weidai.com/scan-mirror/sig.html#RSA">RSA signature scheme with appendix</a>
/// \since Crypto++ 1.0
template <class STANDARD, class H>
struct RSASS : public TF_SS<RSA, STANDARD, H>
{
};

/// \brief RSA algorithm
/// \since Crypto++ 1.0
struct CRYPTOPP_DLL RSA_ISO
{
	CRYPTOPP_STATIC_CONSTEXPR const char* CRYPTOPP_API StaticAlgorithmName() {return "RSA-ISO";}
	typedef RSAFunction_ISO PublicKey;
	typedef InvertibleRSAFunction_ISO PrivateKey;
};

/// \brief RSA signature algorithm
/// \tparam H hash transformation
/// \since Crypto++ 1.0
template <class H>
struct RSASS_ISO : public TF_SS<RSA_ISO, P1363_EMSA2, H>
{
};

/// \brief \ref RSAES<STANDARD> "RSAES<PKCS1v15>::Decryptor" typedef
/// \details RSA encryption scheme defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
DOCUMENTED_TYPEDEF(RSAES<PKCS1v15>::Decryptor, RSAES_PKCS1v15_Decryptor);
/// \brief \ref RSAES<STANDARD> "RSAES<PKCS1v15>::Encryptor" typedef
/// \details RSA encryption scheme defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
DOCUMENTED_TYPEDEF(RSAES<PKCS1v15>::Encryptor, RSAES_PKCS1v15_Encryptor);

/// \brief \ref RSAES<STANDARD> "RSAES<OAEP<SHA1>>::Decryptor" typedef
/// \details RSA encryption scheme defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
DOCUMENTED_TYPEDEF(RSAES<OAEP<SHA1> >::Decryptor, RSAES_OAEP_SHA_Decryptor);
/// \brief \ref RSAES<STANDARD> "RSAES<OAEP<SHA1>>::Encryptor" typedef
/// \details RSA encryption scheme defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
DOCUMENTED_TYPEDEF(RSAES<OAEP<SHA1> >::Encryptor, RSAES_OAEP_SHA_Encryptor);

/// \brief \ref RSAES<STANDARD> "RSAES<OAEP<SHA256>>::Decryptor" typedef
/// \details RSA encryption scheme defined in PKCS #1 v2.0
/// \since Crypto++ 8.8
DOCUMENTED_TYPEDEF(RSAES<OAEP<SHA256> >::Decryptor, RSAES_OAEP_SHA256_Decryptor);
/// \brief \ref RSAES<STANDARD> "RSAES<OAEP<SHA256>>::Encryptor" typedef
/// \details RSA encryption scheme defined in PKCS #1 v2.0
/// \since Crypto++ 8.8
DOCUMENTED_TYPEDEF(RSAES<OAEP<SHA256> >::Encryptor, RSAES_OAEP_SHA256_Encryptor);

#ifdef CRYPTOPP_DOXYGEN_PROCESSING
/// \brief \ref RSASS<STANDARD,HASH> "RSASS<PKCS1v15,SHA1>::Signer" typedef
/// \details RSA signature schemes defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
class RSASSA_PKCS1v15_SHA_Signer : public RSASS<PKCS1v15,SHA1>::Signer {};
/// \brief \ref RSASS<STANDARD,HASH> "RSASS<PKCS1v15,SHA1>::Verifier" typedef
/// \details RSA signature schemes defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
class RSASSA_PKCS1v15_SHA_Verifier : public RSASS<PKCS1v15,SHA1>::Verifier {};

/// \brief \ref RSASS<STANDARD,HASH> "RSASS<PKCS1v15,SHA256>::Signer" typedef
/// \details RSA signature schemes defined in PKCS #1 v2.0
/// \since Crypto++ 8.8
class RSASSA_PKCS1v15_SHA256_Signer : public RSASS<PKCS1v15,SHA256>::Signer {};
/// \brief \ref RSASS<STANDARD,HASH> "RSASS<PKCS1v15,SHA256>::Verifier" typedef
/// \details RSA signature schemes defined in PKCS #1 v2.0
/// \since Crypto++ 8.8
class RSASSA_PKCS1v15_SHA256_Verifier : public RSASS<PKCS1v15,SHA256>::Verifier {};

namespace Weak {

/// \brief \ref RSASS<STANDARD,HASH> "RSASS<PKCS1v15, Weak::MD2>::Signer" typedef
/// \details RSA signature schemes defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
class RSASSA_PKCS1v15_MD2_Signer : public RSASS<PKCS1v15, Weak1::MD2>::Signer {};
/// \brief \ref RSASS<STANDARD,HASH> "RSASS<PKCS1v15, Weak::MD2>::Verifier" typedef
/// \details RSA signature schemes defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
class RSASSA_PKCS1v15_MD2_Verifier : public RSASS<PKCS1v15, Weak1::MD2>::Verifier {};

/// \brief \ref RSASS<STANDARD,HASH> "RSASS<PKCS1v15, Weak::MD5>::Signer" typedef
/// \details RSA signature schemes defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
class RSASSA_PKCS1v15_MD5_Signer : public RSASS<PKCS1v15, Weak1::MD5>::Signer {};
/// \brief \ref RSASS<STANDARD,HASH> "RSASS<PKCS1v15, Weak::MD5>::Verifier" typedef
/// \details RSA signature schemes defined in PKCS #1 v2.0
/// \since Crypto++ 1.0
class RSASSA_PKCS1v15_MD5_Verifier : public RSASS<PKCS1v15, Weak1::MD5>::Verifier {};
}

#else
typedef RSASS<PKCS1v15,SHA1>::Signer RSASSA_PKCS1v15_SHA_Signer;
typedef RSASS<PKCS1v15,SHA1>::Verifier RSASSA_PKCS1v15_SHA_Verifier;

typedef RSASS<PKCS1v15,SHA256>::Signer RSASSA_PKCS1v15_SHA256_Signer;
typedef RSASS<PKCS1v15,SHA256>::Verifier RSASSA_PKCS1v15_SHA256_Verifier;

namespace Weak {
	typedef RSASS<PKCS1v15, Weak1::MD2>::Signer RSASSA_PKCS1v15_MD2_Signer;
	typedef RSASS<PKCS1v15, Weak1::MD2>::Verifier RSASSA_PKCS1v15_MD2_Verifier;
	typedef RSASS<PKCS1v15, Weak1::MD5>::Signer RSASSA_PKCS1v15_MD5_Signer;
	typedef RSASS<PKCS1v15, Weak1::MD5>::Verifier RSASSA_PKCS1v15_MD5_Verifier;
}
#endif // CRYPTOPP_DOXYGEN_PROCESSING

NAMESPACE_END

#endif
