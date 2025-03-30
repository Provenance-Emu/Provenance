// dh.h - originally written and placed in the public domain by Wei Dai

/// \file dh.h
/// \brief Classes for Diffie-Hellman key exchange

#ifndef CRYPTOPP_DH_H
#define CRYPTOPP_DH_H

#include "cryptlib.h"
#include "gfpcrypt.h"
#include "algebra.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Diffie-Hellman domain
/// \tparam GROUP_PARAMETERS group parameters
/// \tparam COFACTOR_OPTION cofactor multiplication option
/// \details A Diffie-Hellman domain is a set of parameters that must be shared
///   by two parties in a key agreement protocol, along with the algorithms
///   for generating key pairs and deriving agreed values.
/// \details For COFACTOR_OPTION, see CofactorMultiplicationOption.
/// \sa DL_SimpleKeyAgreementDomainBase
/// \since Crypto++ 1.0
template <class GROUP_PARAMETERS, class COFACTOR_OPTION = typename GROUP_PARAMETERS::DefaultCofactorOption>
class DH_Domain : public DL_SimpleKeyAgreementDomainBase<typename GROUP_PARAMETERS::Element>
{
	typedef DL_SimpleKeyAgreementDomainBase<typename GROUP_PARAMETERS::Element> Base;

public:
	typedef GROUP_PARAMETERS GroupParameters;
	typedef typename GroupParameters::Element Element;
	typedef DL_KeyAgreementAlgorithm_DH<Element, COFACTOR_OPTION> DH_Algorithm;
	typedef DH_Domain<GROUP_PARAMETERS, COFACTOR_OPTION> Domain;

	virtual ~DH_Domain() {}

	/// \brief Construct a Diffie-Hellman domain
	DH_Domain() {}

	/// \brief Construct a Diffie-Hellman domain
	/// \param params group parameters and options
	DH_Domain(const GroupParameters &params)
		: m_groupParameters(params) {}

	/// \brief Construct a Diffie-Hellman domain
	/// \param bt BufferedTransformation with group parameters and options
	DH_Domain(BufferedTransformation &bt)
		{m_groupParameters.BERDecode(bt);}

	/// \brief Create a Diffie-Hellman domain
	/// \tparam T2 template parameter used as a constructor parameter
	/// \param v1 RandomNumberGenerator derived class
	/// \param v2 second parameter
	/// \details v1 and v2 are passed directly to the GROUP_PARAMETERS object.
	template <class T2>
	DH_Domain(RandomNumberGenerator &v1, const T2 &v2)
		{m_groupParameters.Initialize(v1, v2);}

	/// \brief Create a Diffie-Hellman domain
	/// \tparam T2 template parameter used as a constructor parameter
	/// \tparam T3 template parameter used as a constructor parameter
	/// \param v1 RandomNumberGenerator derived class
	/// \param v2 second parameter
	/// \param v3 third parameter
	/// \details v1, v2 and v3 are passed directly to the GROUP_PARAMETERS object.
	template <class T2, class T3>
	DH_Domain(RandomNumberGenerator &v1, const T2 &v2, const T3 &v3)
		{m_groupParameters.Initialize(v1, v2, v3);}

	/// \brief Create a Diffie-Hellman domain
	/// \tparam T2 template parameter used as a constructor parameter
	/// \tparam T3 template parameter used as a constructor parameter
	/// \tparam T4 template parameter used as a constructor parameter
	/// \param v1 RandomNumberGenerator derived class
	/// \param v2 second parameter
	/// \param v3 third parameter
	/// \param v4 fourth parameter
	/// \details v1, v2, v3 and v4 are passed directly to the GROUP_PARAMETERS object.
	template <class T2, class T3, class T4>
	DH_Domain(RandomNumberGenerator &v1, const T2 &v2, const T3 &v3, const T4 &v4)
		{m_groupParameters.Initialize(v1, v2, v3, v4);}

	/// \brief Construct a Diffie-Hellman domain
	/// \tparam T1 template parameter used as a constructor parameter
	/// \tparam T2 template parameter used as a constructor parameter
	/// \param v1 first parameter
	/// \param v2 second parameter
	/// \details v1 and v2 are passed directly to the GROUP_PARAMETERS object.
	template <class T1, class T2>
	DH_Domain(const T1 &v1, const T2 &v2)
		{m_groupParameters.Initialize(v1, v2);}

	/// \brief Construct a Diffie-Hellman domain
	/// \tparam T1 template parameter used as a constructor parameter
	/// \tparam T2 template parameter used as a constructor parameter
	/// \tparam T3 template parameter used as a constructor parameter
	/// \param v1 first parameter
	/// \param v2 second parameter
	/// \param v3 third parameter
	/// \details v1, v2 and v3 are passed directly to the GROUP_PARAMETERS object.
	template <class T1, class T2, class T3>
	DH_Domain(const T1 &v1, const T2 &v2, const T3 &v3)
		{m_groupParameters.Initialize(v1, v2, v3);}

	/// \brief Construct a Diffie-Hellman domain
	/// \tparam T1 template parameter used as a constructor parameter
	/// \tparam T2 template parameter used as a constructor parameter
	/// \tparam T3 template parameter used as a constructor parameter
	/// \tparam T4 template parameter used as a constructor parameter
	/// \param v1 first parameter
	/// \param v2 second parameter
	/// \param v3 third parameter
	/// \param v4 fourth parameter
	/// \details v1, v2, v3 and v4 are passed directly to the GROUP_PARAMETERS object.
	template <class T1, class T2, class T3, class T4>
	DH_Domain(const T1 &v1, const T2 &v2, const T3 &v3, const T4 &v4)
		{m_groupParameters.Initialize(v1, v2, v3, v4);}

	/// \brief Retrieves the group parameters for this domain
	/// \return the group parameters for this domain as a const reference
	const GroupParameters & GetGroupParameters() const {return m_groupParameters;}
	/// \brief Retrieves the group parameters for this domain
	/// \return the group parameters for this domain as a non-const reference
	GroupParameters & AccessGroupParameters() {return m_groupParameters;}

	/// \brief Generate a public key from a private key in this domain
	/// \param rng RandomNumberGenerator derived class
	/// \param privateKey byte buffer with the previously generated private key
	/// \param publicKey byte buffer for the generated public key in this domain
	/// \details If using a FIPS 140-2 validated library on Windows, then this class will perform
	///   a self test to ensure the key pair is pairwise consistent. Non-FIPS and non-Windows
	///   builds of the library do not provide FIPS validated cryptography, so the code should be
	///   removed by the optimizer.
	/// \pre <tt>COUNTOF(publicKey) == PublicKeyLength()</tt>
	void GeneratePublicKey(RandomNumberGenerator &rng, const byte *privateKey, byte *publicKey) const
	{
		Base::GeneratePublicKey(rng, privateKey, publicKey);

		if (FIPS_140_2_ComplianceEnabled())
		{
			SecByteBlock privateKey2(this->PrivateKeyLength());
			this->GeneratePrivateKey(rng, privateKey2);

			SecByteBlock publicKey2(this->PublicKeyLength());
			Base::GeneratePublicKey(rng, privateKey2, publicKey2);

			SecByteBlock agreedValue(this->AgreedValueLength()), agreedValue2(this->AgreedValueLength());
			bool agreed1 = this->Agree(agreedValue, privateKey, publicKey2);
			bool agreed2 = this->Agree(agreedValue2, privateKey2, publicKey);

			if (!agreed1 || !agreed2 || agreedValue != agreedValue2)
				throw SelfTestFailure(this->AlgorithmName() + ": pairwise consistency test failed");
		}
	}

	static std::string CRYPTOPP_API StaticAlgorithmName()
		{return GroupParameters::StaticAlgorithmNamePrefix() + DH_Algorithm::StaticAlgorithmName();}
	std::string AlgorithmName() const {return StaticAlgorithmName();}

private:
	const DL_KeyAgreementAlgorithm<Element> & GetKeyAgreementAlgorithm() const
		{return Singleton<DH_Algorithm>().Ref();}
	DL_GroupParameters<Element> & AccessAbstractGroupParameters()
		{return m_groupParameters;}

	GroupParameters m_groupParameters;
};

CRYPTOPP_DLL_TEMPLATE_CLASS DH_Domain<DL_GroupParameters_GFP_DefaultSafePrime>;

/// \brief Diffie-Hellman in GF(p)
/// \details DH() class is a typedef of DH_Domain(). The documentation that follows
///   does not exist. Rather the documentation was created in response to <a href="https://github.com/weidai11/cryptopp/issues/328">Issue
///   328, Diffie-Hellman example code not compiling</a>.
/// \details Generally speaking, a DH() object is ephemeral and is intended to execute one instance of the Diffie-Hellman protocol. The
///   private and public key parts are not intended to be set or persisted. Rather, a new set of domain parameters are generated each
///   time an object is created.
/// \details Once a DH() object is created, once can retrieve the ephemeral public key for the other party with code similar to the
///   following.
/// <pre>   AutoSeededRandomPool prng;
///   Integer p, q, g;
///   PrimeAndGenerator pg;
///
///   pg.Generate(1, prng, 512, 511);
///   p = pg.Prime();
///   q = pg.SubPrime();
///   g = pg.Generator();
///
///   DH dh(p, q, g);
///   SecByteBlock t1(dh.PrivateKeyLength()), t2(dh.PublicKeyLength());
///   dh.GenerateKeyPair(prng, t1, t2);
///   Integer k1(t1, t1.size()), k2(t2, t2.size());
///
///   cout << "Private key:\n";
///   cout << hex << k1 << endl;
///
///   cout << "Public key:\n";
///   cout << hex << k2 << endl;</pre>
///
/// \details Output of the program above will be similar to the following.
/// <pre>   $ ./cryptest.exe
///   Private key:
///   72b45a42371545e9d4880f48589aefh
///   Public key:
///   45fdb13f97b1840626f0250cec1dba4a23b894100b51fb5d2dd13693d789948f8bfc88f9200014b2
///   ba8dd8a6debc471c69ef1e2326c61184a2eca88ec866346bh</pre>
/// \sa <a href="http://www.cryptopp.com/wiki/Diffie-Hellman">Diffie-Hellman on the Crypto++ wiki</a> and
///   <a href="http://www.weidai.com/scan-mirror/ka.html#DH">Diffie-Hellman</a> in GF(p) with key validation
/// \since Crypto++ 1.0
#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
struct DH : public DH_Domain<DL_GroupParameters_GFP_DefaultSafePrime>
{
	typedef DH_Domain<DL_GroupParameters_GFP_DefaultSafePrime> GroupParameters;
	typedef GroupParameters::Element Element;

	virtual ~DH() {}

	/// \brief Create an uninitialized Diffie-Hellman object
	DH() : DH_Domain() {}

	/// \brief Initialize a Diffie-Hellman object
	/// \param bt BufferedTransformation with group parameters and options
	DH(BufferedTransformation &bt) : DH_Domain(bt) {}

	/// \brief Initialize a Diffie-Hellman object
	/// \param params group parameters and options
	DH(const GroupParameters &params) : DH_Domain(params) {}

	/// \brief Create a Diffie-Hellman object
	/// \param rng a RandomNumberGenerator derived class
	/// \param modulusBits the size of the modulus, in bits
	/// \details This function overload of Initialize() creates a new Diffie-Hellman object because it
	///   takes a RandomNumberGenerator() as a parameter.
	DH(RandomNumberGenerator &rng, unsigned int modulusBits) : DH_Domain(rng, modulusBits) {}

	/// \brief Initialize a Diffie-Hellman object
	/// \param p the modulus
	/// \param g the generator
	DH(const Integer &p, const Integer &g) : DH_Domain(p, g) {}

	/// \brief Initialize a Diffie-Hellman object
	/// \param p the modulus
	/// \param q the subgroup order
	/// \param g the generator
	DH(const Integer &p, const Integer &q, const Integer &g) : DH_Domain(p, q, g) {}

	/// \brief Creates a Diffie-Hellman object
	/// \param rng a RandomNumberGenerator derived class
	/// \param modulusBits the size of the modulus, in bits
	/// \details This function overload of Initialize() creates a new Diffie-Hellman object because it
	///   takes a RandomNumberGenerator() as a parameter.
	void Initialize(RandomNumberGenerator &rng, unsigned int modulusBits)
		{AccessGroupParameters().Initialize(rng, modulusBits);}

	/// \brief Initialize a Diffie-Hellman object
	/// \param p the modulus
	/// \param g the generator
	void Initialize(const Integer &p, const Integer &g)
		{AccessGroupParameters().Initialize(p, g);}

	/// \brief Initialize a Diffie-Hellman object
	/// \param p the modulus
	/// \param q the subgroup order
	/// \param g the generator
	void Initialize(const Integer &p, const Integer &q, const Integer &g)
		{AccessGroupParameters().Initialize(p, q, g);}
};
#else
// The real DH class is a typedef.
typedef DH_Domain<DL_GroupParameters_GFP_DefaultSafePrime> DH;
#endif

NAMESPACE_END

#endif
