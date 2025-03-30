// rabin.h - originally written and placed in the public domain by Wei Dai

/// \file rabin.h
/// \brief Classes for Rabin encryption and signature schemes

#ifndef CRYPTOPP_RABIN_H
#define CRYPTOPP_RABIN_H

#include "cryptlib.h"
#include "oaep.h"
#include "pssr.h"
#include "integer.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Rabin trapdoor function using the public key
/// \since Crypto++ 2.0
class RabinFunction : public TrapdoorFunction, public PublicKey
{
	typedef RabinFunction ThisClass;

public:

	/// \brief Initialize a Rabin public key
	/// \param n the modulus
	/// \param r element r
	/// \param s element s
	void Initialize(const Integer &n, const Integer &r, const Integer &s)
		{m_n = n; m_r = r; m_s = s;}

	void BERDecode(BufferedTransformation &bt);
	void DEREncode(BufferedTransformation &bt) const;

	Integer ApplyFunction(const Integer &x) const;
	Integer PreimageBound() const {return m_n;}
	Integer ImageBound() const {return m_n;}

	bool Validate(RandomNumberGenerator &rng, unsigned int level) const;
	bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const;
	void AssignFrom(const NameValuePairs &source);

	const Integer& GetModulus() const {return m_n;}
	const Integer& GetQuadraticResidueModPrime1() const {return m_r;}
	const Integer& GetQuadraticResidueModPrime2() const {return m_s;}

	void SetModulus(const Integer &n) {m_n = n;}
	void SetQuadraticResidueModPrime1(const Integer &r) {m_r = r;}
	void SetQuadraticResidueModPrime2(const Integer &s) {m_s = s;}

protected:
	Integer m_n, m_r, m_s;
};

/// \brief Rabin trapdoor function using the private key
/// \since Crypto++ 2.0
class InvertibleRabinFunction : public RabinFunction, public TrapdoorFunctionInverse, public PrivateKey
{
	typedef InvertibleRabinFunction ThisClass;

public:

	/// \brief Initialize a Rabin private key
	/// \param n modulus
	/// \param r element r
	/// \param s element s
	/// \param p first prime factor
	/// \param q second prime factor
	/// \param u q<sup>-1</sup> mod p
	/// \details This Initialize() function overload initializes a private key from existing parameters.
	void Initialize(const Integer &n, const Integer &r, const Integer &s, const Integer &p, const Integer &q, const Integer &u)
		{m_n = n; m_r = r; m_s = s; m_p = p; m_q = q; m_u = u;}

	/// \brief Create a Rabin private key
	/// \param rng a RandomNumberGenerator derived class
	/// \param keybits the size of the key, in bits
	/// \details This function overload of Initialize() creates a new private key because it
	///   takes a RandomNumberGenerator() as a parameter. If you have an existing keypair,
	///   then use one of the other Initialize() overloads.
	void Initialize(RandomNumberGenerator &rng, unsigned int keybits)
		{GenerateRandomWithKeySize(rng, keybits);}

	void BERDecode(BufferedTransformation &bt);
	void DEREncode(BufferedTransformation &bt) const;

	Integer CalculateInverse(RandomNumberGenerator &rng, const Integer &x) const;

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

protected:
	Integer m_p, m_q, m_u;
};

/// \brief Rabin keys
struct Rabin
{
	static std::string StaticAlgorithmName() {return "Rabin-Crypto++Variant";}
	typedef RabinFunction PublicKey;
	typedef InvertibleRabinFunction PrivateKey;
};

/// \brief Rabin encryption scheme
/// \tparam STANDARD encryption standard
template <class STANDARD>
struct RabinES : public TF_ES<Rabin, STANDARD>
{
};

/// \brief Rabin signature scheme
/// \tparam STANDARD signature standard
/// \tparam H hash transformation
template <class STANDARD, class H>
struct RabinSS : public TF_SS<Rabin, STANDARD, H>
{
};

// More typedefs for backwards compatibility
class SHA1;
typedef RabinES<OAEP<SHA1> >::Decryptor RabinDecryptor;
typedef RabinES<OAEP<SHA1> >::Encryptor RabinEncryptor;

NAMESPACE_END

#endif
