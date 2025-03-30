// rw.h - originally written and placed in the public domain by Wei Dai

/// \file rw.h
/// \brief Classes for Rabin-Williams signature scheme
/// \details The implementation provides Rabin-Williams signature schemes as defined in
///   IEEE P1363. It uses Bernstein's tweaked square roots in place of square roots to
///   speedup calculations.
/// \sa <A HREF="http://cr.yp.to/sigs/rwsota-20080131.pdf">RSA signatures and Rabin–Williams
///   signatures: the state of the art (20080131)</A>, Section 6, <em>The tweaks e and f</em>.
/// \since Crypto++ 3.0

#ifndef CRYPTOPP_RW_H
#define CRYPTOPP_RW_H

#include "cryptlib.h"
#include "pubkey.h"
#include "integer.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Rabin-Williams trapdoor function using the public key
/// \since Crypto++ 3.0, Tweaked roots using <em>e</em> and <em>f</em> since Crypto++ 5.6.4
class CRYPTOPP_DLL RWFunction : public TrapdoorFunction, public PublicKey
{
	typedef RWFunction ThisClass;

public:

	/// \brief Initialize a Rabin-Williams public key
	/// \param n the modulus
	void Initialize(const Integer &n)
		{m_n = n;}

	void BERDecode(BufferedTransformation &bt);
	void DEREncode(BufferedTransformation &bt) const;

	void Save(BufferedTransformation &bt) const
		{DEREncode(bt);}
	void Load(BufferedTransformation &bt)
		{BERDecode(bt);}

	Integer ApplyFunction(const Integer &x) const;
	Integer PreimageBound() const {return ++(m_n>>1);}
	Integer ImageBound() const {return m_n;}

	bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
	bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
	void AssignFrom(const NameValuePairs &source);

	const Integer& GetModulus() const {return m_n;}
	void SetModulus(const Integer &n) {m_n = n;}

protected:
	Integer m_n;
};

/// \brief Rabin-Williams trapdoor function using the private key
/// \since Crypto++ 3.0, Tweaked roots using <em>e</em> and <em>f</em> since Crypto++ 5.6.4
class CRYPTOPP_DLL InvertibleRWFunction : public RWFunction, public TrapdoorFunctionInverse, public PrivateKey
{
	typedef InvertibleRWFunction ThisClass;

public:
	/// \brief Construct an InvertibleRWFunction
	InvertibleRWFunction() : m_precompute(false) {}

	/// \brief Initialize a Rabin-Williams private key
	/// \param n modulus
	/// \param p first prime factor
	/// \param q second prime factor
	/// \param u q<sup>-1</sup> mod p
	/// \details This Initialize() function overload initializes a private key from existing parameters.
	void Initialize(const Integer &n, const Integer &p, const Integer &q, const Integer &u);

	/// \brief Create a Rabin-Williams private key
	/// \param rng a RandomNumberGenerator derived class
	/// \param modulusBits the size of the modulus, in bits
	/// \details This function overload of Initialize() creates a new private key because it
	///   takes a RandomNumberGenerator() as a parameter. If you have an existing keypair,
	///   then use one of the other Initialize() overloads.
	void Initialize(RandomNumberGenerator &rng, unsigned int modulusBits)
		{GenerateRandomWithKeySize(rng, modulusBits);}

	void BERDecode(BufferedTransformation &bt);
	void DEREncode(BufferedTransformation &bt) const;

	void Save(BufferedTransformation &bt) const
		{DEREncode(bt);}
	void Load(BufferedTransformation &bt)
		{BERDecode(bt);}

	Integer CalculateInverse(RandomNumberGenerator &rng, const Integer &x) const;

	// GeneratibleCryptoMaterial
	bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
	bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
	void AssignFrom(const NameValuePairs &source);
	/*! parameters: (ModulusSize) */
	void GenerateRandom(RandomNumberGenerator &rng, const NameValuePairs &alg);

	const Integer& GetPrime1() const {return m_p;}
	const Integer& GetPrime2() const {return m_q;}
	const Integer& GetMultiplicativeInverseOfPrime2ModPrime1() const {return m_u;}

	void SetPrime1(const Integer &p) {m_p = p;}
	void SetPrime2(const Integer &q) {m_q = q;}
	void SetMultiplicativeInverseOfPrime2ModPrime1(const Integer &u) {m_u = u;}

	virtual bool SupportsPrecomputation() const {return true;}
	virtual void Precompute(unsigned int unused = 0) {CRYPTOPP_UNUSED(unused); PrecomputeTweakedRoots();}
	virtual void Precompute(unsigned int unused = 0) const {CRYPTOPP_UNUSED(unused); PrecomputeTweakedRoots();}

	virtual void LoadPrecomputation(BufferedTransformation &storedPrecomputation);
	virtual void SavePrecomputation(BufferedTransformation &storedPrecomputation) const;

protected:
	void PrecomputeTweakedRoots() const;

protected:
	Integer m_p, m_q, m_u;

	mutable Integer m_pre_2_9p, m_pre_2_3q, m_pre_q_p;
	mutable bool m_precompute;
};

/// \brief Rabin-Williams keys
/// \since Crypto++ 3.0
struct RW
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "RW";}
	typedef RWFunction PublicKey;
	typedef InvertibleRWFunction PrivateKey;
};

/// \brief Rabin-Williams signature scheme
/// \tparam STANDARD signature standard
/// \tparam H hash transformation
/// \since Crypto++ 3.0
template <class STANDARD, class H>
struct RWSS : public TF_SS<RW, STANDARD, H>
{
};

NAMESPACE_END

#endif
