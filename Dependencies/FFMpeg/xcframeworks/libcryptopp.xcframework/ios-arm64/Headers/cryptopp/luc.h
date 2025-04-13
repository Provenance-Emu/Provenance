// luc.h - originally written and placed in the public domain by Wei Dai

/// \file luc.h
/// \brief Classes for the LUC cryptosystem
/// \details This class is here for historical and pedagogical interest. It has no practical advantages over other
///   trapdoor functions and probably shouldn't	be used in production software. The discrete log based LUC schemes
///   defined later in this .h file may be of more practical interest.
/// \since Crypto++ 2.1

#ifndef CRYPTOPP_LUC_H
#define CRYPTOPP_LUC_H

#include "cryptlib.h"
#include "gfpcrypt.h"
#include "integer.h"
#include "algebra.h"
#include "secblock.h"

#if CRYPTOPP_MSC_VERSION
# pragma warning(push)
# pragma warning(disable: 4127 4189)
#endif

#include "pkcspad.h"
#include "integer.h"
#include "oaep.h"
#include "dh.h"

#include <limits.h>

NAMESPACE_BEGIN(CryptoPP)

/// \brief The LUC function.
/// \details This class is here for historical and pedagogical interest. It has no practical advantages over other
///   trapdoor functions and probably shouldn't	be used in production software. The discrete log based LUC schemes
///   defined later in this .h file may be of more practical interest.
/// \since Crypto++ 2.1
class LUCFunction : public TrapdoorFunction, public PublicKey
{
	typedef LUCFunction ThisClass;

public:
	virtual ~LUCFunction() {}

	/// \brief Initialize a LUC public key with {n,e}
	/// \param n the modulus
	/// \param e the public exponent
	void Initialize(const Integer &n, const Integer &e)
		{m_n = n; m_e = e;}

	void BERDecode(BufferedTransformation &bt);
	void DEREncode(BufferedTransformation &bt) const;

	Integer ApplyFunction(const Integer &x) const;
	Integer PreimageBound() const {return m_n;}
	Integer ImageBound() const {return m_n;}

	bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
	bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
	void AssignFrom(const NameValuePairs &source);

	// non-derived interface
	const Integer & GetModulus() const {return m_n;}
	const Integer & GetPublicExponent() const {return m_e;}

	void SetModulus(const Integer &n) {m_n = n;}
	void SetPublicExponent(const Integer &e) {m_e = e;}

protected:
	Integer m_n, m_e;
};

/// \brief The LUC inverse function.
/// \details This class is here for historical and pedagogical interest. It has no practical advantages over other
///   trapdoor functions and probably shouldn't	be used in production software. The discrete log based LUC schemes
///   defined later in this .h file may be of more practical interest.
/// \since Crypto++ 2.1
class InvertibleLUCFunction : public LUCFunction, public TrapdoorFunctionInverse, public PrivateKey
{
	typedef InvertibleLUCFunction ThisClass;

public:
	virtual ~InvertibleLUCFunction() {}

	/// \brief Create a LUC private key
	/// \param rng a RandomNumberGenerator derived class
	/// \param modulusBits the size of the modulus, in bits
	/// \param eStart the desired starting public exponent
	/// \details Initialize() creates a new keypair using a starting public exponent of 17.
	/// \details This function overload of Initialize() creates a new keypair because it
	///   takes a RandomNumberGenerator() as a parameter. If you have an existing keypair,
	///   then use one of the other Initialize() overloads.
	void Initialize(RandomNumberGenerator &rng, unsigned int modulusBits, const Integer &eStart=17);

	/// \brief Initialize a LUC private key with {n,e,p,q,dp,dq,u}
	/// \param n modulus
	/// \param e public exponent
	/// \param p first prime factor
	/// \param q second prime factor
	/// \param u q<sup>-1</sup> mod p
	/// \details This Initialize() function overload initializes a private key from existing parameters.
	void Initialize(const Integer &n, const Integer &e, const Integer &p, const Integer &q, const Integer &u)
		{m_n = n; m_e = e; m_p = p; m_q = q; m_u = u;}

	void BERDecode(BufferedTransformation &bt);
	void DEREncode(BufferedTransformation &bt) const;

	Integer CalculateInverse(RandomNumberGenerator &rng, const Integer &x) const;

	bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
	bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
	void AssignFrom(const NameValuePairs &source);
	/*! parameters: (ModulusSize, PublicExponent (default 17)) */
	void GenerateRandom(RandomNumberGenerator &rng, const NameValuePairs &alg);

	// non-derived interface
	const Integer& GetPrime1() const {return m_p;}
	const Integer& GetPrime2() const {return m_q;}
	const Integer& GetMultiplicativeInverseOfPrime2ModPrime1() const {return m_u;}

	void SetPrime1(const Integer &p) {m_p = p;}
	void SetPrime2(const Integer &q) {m_q = q;}
	void SetMultiplicativeInverseOfPrime2ModPrime1(const Integer &u) {m_u = u;}

protected:
	Integer m_p, m_q, m_u;
};

/// \brief LUC cryptosystem
/// \since Crypto++ 2.1
struct LUC
{
	static std::string StaticAlgorithmName() {return "LUC";}
	typedef LUCFunction PublicKey;
	typedef InvertibleLUCFunction PrivateKey;
};

/// \brief LUC encryption scheme
/// \tparam STANDARD signature standard
/// \details This class is here for historical and pedagogical interest. It has no practical advantages over other
///   trapdoor functions and probably shouldn't	be used in production software. The discrete log based LUC schemes
///   defined later in this .h file may be of more practical interest.
/// \since Crypto++ 2.1
template <class STANDARD>
struct LUCES : public TF_ES<LUC, STANDARD>
{
};

/// \brief LUC signature scheme with appendix
/// \tparam STANDARD signature standard
/// \tparam H hash transformation
/// \details This class is here for historical and pedagogical interest. It has no practical advantages over other
///   trapdoor functions and probably shouldn't	be used in production software. The discrete log based LUC schemes
///   defined later in this .h file may be of more practical interest.
/// \since Crypto++ 2.1
template <class STANDARD, class H>
struct LUCSS : public TF_SS<LUC, STANDARD, H>
{
};

// analogous to the RSA schemes defined in PKCS #1 v2.0
typedef LUCES<OAEP<SHA1> >::Decryptor LUCES_OAEP_SHA_Decryptor;
typedef LUCES<OAEP<SHA1> >::Encryptor LUCES_OAEP_SHA_Encryptor;

typedef LUCSS<PKCS1v15, SHA1>::Signer LUCSSA_PKCS1v15_SHA_Signer;
typedef LUCSS<PKCS1v15, SHA1>::Verifier LUCSSA_PKCS1v15_SHA_Verifier;

// ********************************************************

/// \brief LUC GroupParameters precomputation
/// \details No actual precomputation is performed
/// \since Crypto++ 2.1
class DL_GroupPrecomputation_LUC : public DL_GroupPrecomputation<Integer>
{
public:
	virtual ~DL_GroupPrecomputation_LUC() {}

	const AbstractGroup<Element> & GetGroup() const {CRYPTOPP_ASSERT(false); throw 0;}
	Element BERDecodeElement(BufferedTransformation &bt) const {return Integer(bt);}
	void DEREncodeElement(BufferedTransformation &bt, const Element &v) const {v.DEREncode(bt);}

	// non-inherited
	void SetModulus(const Integer &v) {m_p = v;}
	const Integer & GetModulus() const {return m_p;}

private:
	Integer m_p;
};

/// \brief LUC Precomputation
/// \since Crypto++ 2.1
class DL_BasePrecomputation_LUC : public DL_FixedBasePrecomputation<Integer>
{
public:
	virtual ~DL_BasePrecomputation_LUC() {}

	// DL_FixedBasePrecomputation
	bool IsInitialized() const {return m_g.NotZero();}
	void SetBase(const DL_GroupPrecomputation<Element> &group, const Integer &base)
		{CRYPTOPP_UNUSED(group); m_g = base;}
	const Integer & GetBase(const DL_GroupPrecomputation<Element> &group) const
		{CRYPTOPP_UNUSED(group); return m_g;}
	void Precompute(const DL_GroupPrecomputation<Element> &group, unsigned int maxExpBits, unsigned int storage)
		{CRYPTOPP_UNUSED(group); CRYPTOPP_UNUSED(maxExpBits); CRYPTOPP_UNUSED(storage);}
	void Load(const DL_GroupPrecomputation<Element> &group, BufferedTransformation &storedPrecomputation)
		{CRYPTOPP_UNUSED(group); CRYPTOPP_UNUSED(storedPrecomputation);}
	void Save(const DL_GroupPrecomputation<Element> &group, BufferedTransformation &storedPrecomputation) const
		{CRYPTOPP_UNUSED(group); CRYPTOPP_UNUSED(storedPrecomputation);}
	Integer Exponentiate(const DL_GroupPrecomputation<Element> &group, const Integer &exponent) const;
	Integer CascadeExponentiate(const DL_GroupPrecomputation<Element> &group, const Integer &exponent, const DL_FixedBasePrecomputation<Integer> &pc2, const Integer &exponent2) const
		{
			CRYPTOPP_UNUSED(group); CRYPTOPP_UNUSED(exponent); CRYPTOPP_UNUSED(pc2); CRYPTOPP_UNUSED(exponent2);
			// shouldn't be called
			throw NotImplemented("DL_BasePrecomputation_LUC: CascadeExponentiate not implemented");
		}

private:
	Integer m_g;
};

/// \brief LUC GroupParameters specialization
/// \since Crypto++ 2.1
class DL_GroupParameters_LUC : public DL_GroupParameters_IntegerBasedImpl<DL_GroupPrecomputation_LUC, DL_BasePrecomputation_LUC>
{
public:
	virtual ~DL_GroupParameters_LUC() {}

	// DL_GroupParameters
	bool IsIdentity(const Integer &element) const {return element == Integer::Two();}
	void SimultaneousExponentiate(Element *results, const Element &base, const Integer *exponents, unsigned int exponentsCount) const;
	Element MultiplyElements(const Element &a, const Element &b) const
	{
		CRYPTOPP_UNUSED(a); CRYPTOPP_UNUSED(b);
		throw NotImplemented("LUC_GroupParameters: MultiplyElements can not be implemented");
	}
	Element CascadeExponentiate(const Element &element1, const Integer &exponent1, const Element &element2, const Integer &exponent2) const
	{
		CRYPTOPP_UNUSED(element1); CRYPTOPP_UNUSED(exponent1); CRYPTOPP_UNUSED(element2); CRYPTOPP_UNUSED(exponent2);
		throw NotImplemented("LUC_GroupParameters: MultiplyElements can not be implemented");
	}

	// NameValuePairs interface
	bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const
	{
		return GetValueHelper<DL_GroupParameters_IntegerBased>(this, name, valueType, pValue).Assignable();
	}

private:
	int GetFieldType() const {return 2;}
};

/// \brief GF(p) group parameters that default to safe primes
/// \since Crypto++ 2.1
class DL_GroupParameters_LUC_DefaultSafePrime : public DL_GroupParameters_LUC
{
public:
	typedef NoCofactorMultiplication DefaultCofactorOption;

protected:
	unsigned int GetDefaultSubgroupOrderSize(unsigned int modulusSize) const {return modulusSize-1;}
};

/// \brief LUC HMP signature algorithm
/// \since Crypto++ 2.1
class DL_Algorithm_LUC_HMP : public DL_ElgamalLikeSignatureAlgorithm<Integer>
{
public:
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "LUC-HMP";}

	virtual ~DL_Algorithm_LUC_HMP() {}

	void Sign(const DL_GroupParameters<Integer> &params, const Integer &x, const Integer &k, const Integer &e, Integer &r, Integer &s) const;
	bool Verify(const DL_GroupParameters<Integer> &params, const DL_PublicKey<Integer> &publicKey, const Integer &e, const Integer &r, const Integer &s) const;

	size_t RLen(const DL_GroupParameters<Integer> &params) const
		{return params.GetGroupOrder().ByteCount();}
};

/// \brief LUC signature keys
/// \since Crypto++ 2.1
struct DL_SignatureKeys_LUC
{
	typedef DL_GroupParameters_LUC GroupParameters;
	typedef DL_PublicKey_GFP<GroupParameters> PublicKey;
	typedef DL_PrivateKey_GFP<GroupParameters> PrivateKey;
};

/// \brief LUC-HMP, based on "Digital signature schemes based on Lucas functions" by Patrick Horster, Markus Michels, Holger Petersen
/// \tparam H hash transformation
/// \details This class is here for historical and pedagogical interest. It has no practical advantages over other
///   trapdoor functions and probably shouldn't	be used in production software. The discrete log based LUC schemes
///   defined later in this .h file may be of more practical interest.
/// \since Crypto++ 2.1
template <class H>
struct LUC_HMP : public DL_SS<DL_SignatureKeys_LUC, DL_Algorithm_LUC_HMP, DL_SignatureMessageEncodingMethod_DSA, H>
{
};

/// \brief LUC encryption keys
/// \since Crypto++ 2.1
struct DL_CryptoKeys_LUC
{
	typedef DL_GroupParameters_LUC_DefaultSafePrime GroupParameters;
	typedef DL_PublicKey_GFP<GroupParameters> PublicKey;
	typedef DL_PrivateKey_GFP<GroupParameters> PrivateKey;
};

/// \brief LUC Integrated Encryption Scheme
/// \tparam COFACTOR_OPTION cofactor multiplication option
/// \tparam HASH HashTransformation derived class used for key drivation and MAC computation
/// \tparam DHAES_MODE flag indicating if the MAC includes additional context parameters such as <em>u·V</em>, <em>v·U</em> and label
/// \tparam LABEL_OCTETS flag indicating if the label size is specified in octets or bits
/// \sa CofactorMultiplicationOption
/// \since Crypto++ 2.1, Crypto++ 5.7 for Bouncy Castle and Botan compatibility
template <class HASH = SHA1, class COFACTOR_OPTION = NoCofactorMultiplication, bool DHAES_MODE = true, bool LABEL_OCTETS = false>
struct LUC_IES
	: public DL_ES<
		DL_CryptoKeys_LUC,
		DL_KeyAgreementAlgorithm_DH<Integer, COFACTOR_OPTION>,
		DL_KeyDerivationAlgorithm_P1363<Integer, DHAES_MODE, P1363_KDF2<HASH> >,
		DL_EncryptionAlgorithm_Xor<HMAC<HASH>, DHAES_MODE, LABEL_OCTETS>,
		LUC_IES<> >
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "LUC-IES";}	// non-standard name
};

// ********************************************************

/// \brief LUC-DH
typedef DH_Domain<DL_GroupParameters_LUC_DefaultSafePrime> LUC_DH;

NAMESPACE_END

#if CRYPTOPP_MSC_VERSION
# pragma warning(pop)
#endif

#endif
