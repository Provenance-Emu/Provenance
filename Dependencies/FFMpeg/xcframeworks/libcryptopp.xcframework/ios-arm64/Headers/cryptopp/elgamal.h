// elgamal.h - originally written and placed in the public domain by Wei Dai

/// \file elgamal.h
/// \brief Classes and functions for ElGamal key agreement and encryption schemes

#ifndef CRYPTOPP_ELGAMAL_H
#define CRYPTOPP_ELGAMAL_H

#include "cryptlib.h"
#include "modexppc.h"
#include "integer.h"
#include "gfpcrypt.h"
#include "pubkey.h"
#include "misc.h"
#include "oids.h"
#include "dsa.h"
#include "asn.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief ElGamal key agreement and encryption schemes base class
/// \since Crypto++ 1.0
class CRYPTOPP_NO_VTABLE ElGamalBase :
	public DL_KeyAgreementAlgorithm_DH<Integer, NoCofactorMultiplication>,
	public DL_KeyDerivationAlgorithm<Integer>,
	public DL_SymmetricEncryptionAlgorithm
{
public:
	virtual ~ElGamalBase() {}

	void Derive(const DL_GroupParameters<Integer> &groupParams, byte *derivedKey, size_t derivedLength, const Integer &agreedElement, const Integer &ephemeralPublicKey, const NameValuePairs &derivationParams) const
	{
		CRYPTOPP_UNUSED(groupParams); CRYPTOPP_UNUSED(ephemeralPublicKey);
		CRYPTOPP_UNUSED(derivationParams);
		agreedElement.Encode(derivedKey, derivedLength);
	}

	size_t GetSymmetricKeyLength(size_t plainTextLength) const
	{
		CRYPTOPP_UNUSED(plainTextLength);
		return GetGroupParameters().GetModulus().ByteCount();
	}

	size_t GetSymmetricCiphertextLength(size_t plainTextLength) const
	{
		unsigned int len = GetGroupParameters().GetModulus().ByteCount();
		if (plainTextLength <= GetMaxSymmetricPlaintextLength(len))
			return len;
		else
			return 0;
	}

	size_t GetMaxSymmetricPlaintextLength(size_t cipherTextLength) const
	{
		unsigned int len = GetGroupParameters().GetModulus().ByteCount();
		CRYPTOPP_ASSERT(len >= 3);

		if (cipherTextLength == len)
			return STDMIN(255U, len-3);
		else
			return 0;
	}

	void SymmetricEncrypt(RandomNumberGenerator &rng, const byte *key, const byte *plainText, size_t plainTextLength, byte *cipherText, const NameValuePairs &parameters) const
	{
		CRYPTOPP_UNUSED(parameters);
		const Integer &p = GetGroupParameters().GetModulus();
		unsigned int modulusLen = p.ByteCount();

		SecByteBlock block(modulusLen-1);
		rng.GenerateBlock(block, modulusLen-2-plainTextLength);
		std::memcpy(block+modulusLen-2-plainTextLength, plainText, plainTextLength);
		block[modulusLen-2] = (byte)plainTextLength;

		a_times_b_mod_c(Integer(key, modulusLen), Integer(block, modulusLen-1), p).Encode(cipherText, modulusLen);
	}

	DecodingResult SymmetricDecrypt(const byte *key, const byte *cipherText, size_t cipherTextLength, byte *plainText, const NameValuePairs &parameters) const
	{
		CRYPTOPP_UNUSED(parameters);
		const Integer &p = GetGroupParameters().GetModulus();
		unsigned int modulusLen = p.ByteCount();

		if (cipherTextLength != modulusLen)
			return DecodingResult();

		Integer m = a_times_b_mod_c(Integer(cipherText, modulusLen), Integer(key, modulusLen).InverseMod(p), p);

		m.Encode(plainText, 1);
		unsigned int plainTextLength = plainText[0];
		if (plainTextLength > GetMaxSymmetricPlaintextLength(modulusLen))
			return DecodingResult();
		m >>= 8;
		m.Encode(plainText, plainTextLength);
		return DecodingResult(plainTextLength);
	}

	virtual const DL_GroupParameters_GFP & GetGroupParameters() const =0;
};

/// \brief ElGamal key agreement and encryption schemes default implementation
/// \tparam BASE Base class implementation
/// \tparam SCHEME_OPTIONS Scheme options
/// \tparam KEY ElGamal key classes
/// \since Crypto++ 1.0
template <class BASE, class SCHEME_OPTIONS, class KEY>
class ElGamalObjectImpl :
	public DL_ObjectImplBase<BASE, SCHEME_OPTIONS, KEY>,
	public ElGamalBase
{
public:
	virtual ~ElGamalObjectImpl() {}

	size_t FixedMaxPlaintextLength() const {return this->MaxPlaintextLength(FixedCiphertextLength());}
	size_t FixedCiphertextLength() const {return this->CiphertextLength(0);}

	const DL_GroupParameters_GFP & GetGroupParameters() const {return this->GetKey().GetGroupParameters();}

	DecodingResult FixedLengthDecrypt(RandomNumberGenerator &rng, const byte *cipherText, byte *plainText) const
		{return Decrypt(rng, cipherText, FixedCiphertextLength(), plainText);}

protected:
	const DL_KeyAgreementAlgorithm<Integer> & GetKeyAgreementAlgorithm() const {return *this;}
	const DL_KeyDerivationAlgorithm<Integer> & GetKeyDerivationAlgorithm() const {return *this;}
	const DL_SymmetricEncryptionAlgorithm & GetSymmetricEncryptionAlgorithm() const {return *this;}
};

/// \brief ElGamal Public Key adapter
/// \tparam BASE PublicKey derived class
/// \details DL_PublicKey_ElGamal provides an override for GetAlgorithmID()
///  to utilize 1.3.14.7.2.1.1. Prior to DL_PublicKey_ElGamal, the ElGamal
///  keys [mistakenly] used the OID from DSA due to DL_GroupParmaters_GFP().
///  If you need to <tt>Load</tt> an ElGamal key with the wrong OID then
///  see <A HREF="https://www.cryptopp.com/wiki/ElGamal">ElGamal</A> on
///  the Crypto++ wiki.
/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/876">Issue 876</A>,
///  <A HREF="https://github.com/weidai11/cryptopp/issues/567">Issue 567</A>
/// \since Crypto++ 8.3
template <class BASE>
struct DL_PublicKey_ElGamal : public BASE
{
	virtual ~DL_PublicKey_ElGamal() {}

	/// \brief Retrieves the OID of the algorithm
	/// \return OID of the algorithm
	/// \details DL_PrivateKey_ElGamal provides an override for GetAlgorithmID()
	///  to utilize 1.3.14.7.2.1.1. Prior to DL_PrivateKey_ElGamal, the ElGamal
	///  keys [mistakenly] used the OID from DSA due to DL_GroupParmaters_GFP().
	///  If you need to <tt>Load</tt> an ElGamal key with the wrong OID then
	///  see <A HREF="https://www.cryptopp.com/wiki/ElGamal">ElGamal</A> on
	///  the Crypto++ wiki.
	/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/876">Issue 876</A>,
	///  <A HREF="https://github.com/weidai11/cryptopp/issues/567">Issue 567</A>
	virtual OID GetAlgorithmID() const {
		return ASN1::elGamal();
	}
};

/// \brief ElGamal Private Key adapter
/// \tparam BASE PrivateKey derived class
/// \details DL_PrivateKey_ElGamal provides an override for GetAlgorithmID()
///  to utilize 1.3.14.7.2.1.1. Prior to DL_PrivateKey_ElGamal, the ElGamal
///  keys [mistakenly] used the OID from DSA due to DL_GroupParmaters_GFP().
///  If you need to <tt>Load</tt> an ElGamal key with the wrong OID then
///  see <A HREF="https://www.cryptopp.com/wiki/ElGamal">ElGamal</A> on
///  the Crypto++ wiki.
/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/876">Issue 876</A>,
///  <A HREF="https://github.com/weidai11/cryptopp/issues/567">Issue 567</A>
/// \since Crypto++ 8.3
template <class BASE>
struct DL_PrivateKey_ElGamal : public BASE
{
	virtual ~DL_PrivateKey_ElGamal() {}

	/// \brief Retrieves the OID of the algorithm
	/// \return OID of the algorithm
	/// \details DL_PrivateKey_ElGamal provides an override for GetAlgorithmID()
	///  to utilize 1.3.14.7.2.1.1. Prior to DL_PrivateKey_ElGamal, the ElGamal
	///  keys [mistakenly] used the OID from DSA due to DL_GroupParmaters_GFP().
	///  If you need to <tt>Load</tt> an ElGamal key with the wrong OID then
	///  see <A HREF="https://www.cryptopp.com/wiki/ElGamal">ElGamal</A> on
	///  the Crypto++ wiki.
	/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/876">Issue 876</A>,
	///  <A HREF="https://github.com/weidai11/cryptopp/issues/567">Issue 567</A>
	virtual OID GetAlgorithmID() const {
		return ASN1::elGamal();
	}

	/// \brief Check the key for errors
	/// \param rng RandomNumberGenerator for objects which use randomized testing
	/// \param level level of thoroughness
	/// \return true if the tests succeed, false otherwise
	/// \details There are four levels of thoroughness:
	///   <ul>
	///   <li>0 - using this object won't cause a crash or exception
	///   <li>1 - this object will probably function, and encrypt, sign, other
	///           operations correctly
	///   <li>2 - ensure this object will function correctly, and perform
	///           reasonable security checks
	///   <li>3 - perform reasonable security checks, and do checks that may
	///           take a long time
	///   </ul>
	/// \details Level 0 does not require a RandomNumberGenerator. A NullRNG() can
	///  be used for level 0. Level 1 may not check for weak keys and such.
	///  Levels 2 and 3 are recommended.
	bool Validate(RandomNumberGenerator &rng, unsigned int level) const
	{
		// Validate() formerly used DL_PrivateKey_GFP implementation through
		// inheritance. However, it would reject keys from other libraries
		// like BouncyCastle. The failure was x < q. According to ElGamal's
		// paper and the HAC, the private key is selected in over [1,p-1],
		// Later Tsiounis and Yung showed the lower limit as [1,q-1] in
		// "On the Security of EIGamal Based Encryption". As such, Crypto++
		// will generate a key in the range [1,q-1], but accept a key
		// in [1,p-1]. Thanks to JPM for finding the reference. Also see
		// https://github.com/weidai11/cryptopp/commit/a5a684d92986.

		CRYPTOPP_ASSERT(this->GetAbstractGroupParameters().Validate(rng, level));
		bool pass = this->GetAbstractGroupParameters().Validate(rng, level);

		const Integer &p = this->GetGroupParameters().GetModulus();
		const Integer &q = this->GetAbstractGroupParameters().GetSubgroupOrder();
		const Integer &x = this->GetPrivateExponent();

		// Changed to x < p-1 based on ElGamal's paper and the HAC.
		CRYPTOPP_ASSERT(x.IsPositive());
		CRYPTOPP_ASSERT(x < p-1);
		pass = pass && x.IsPositive() && x < p-1;

		if (level >= 1)
		{
			// Minimum security level due to Tsiounis and Yung.
			CRYPTOPP_ASSERT(Integer::Gcd(x, q) == Integer::One());
			pass = pass && Integer::Gcd(x, q) == Integer::One();
		}
		return pass;
	}
};

/// \brief ElGamal key agreement and encryption schemes keys
/// \details ElGamalKeys provide the algorithm implementation ElGamal key
///  agreement and encryption schemes.
/// \details The ElGamalKeys class used <tt>DL_PrivateKey_GFP_OldFormat</tt>
///  and <tt>DL_PublicKey_GFP_OldFormat</tt> for the <tt>PrivateKey</tt> and
///  <tt>PublicKey</tt> from about Crypto++ 1.0 through Crypto++ 5.6.5. At
///  Crypto++ 6.0 the serialization format was cutover to standard PKCS8 and
///  X509 encodings.
/// \details The ElGamalKeys class [mistakenly] used the OID for DSA from
///  about Crypto++ 1.0 through Crypto++ 8.2. At Crypto++ 8.3 the OID was
///  fixed and now uses ElGamal encryption, which is 1.3.14.7.2.1.1.
///  If you need to <tt>Load</tt> an ElGamal key with the wrong OID then
///  see <A HREF="https://www.cryptopp.com/wiki/ElGamal">ElGamal</A> on
///  the Crypto++ wiki.
/// \details At Crypto++ 8.6 ElGamalKeys were changed to use DL_CryptoKeys_ElGamal
///  due to Issue 1069 and CVE-2021-40530. DL_CryptoKeys_ElGamal group parameters
///  use the subgroup order, and not an estimated work factor.
/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/876">Issue 876</A>,
///  <A HREF="https://github.com/weidai11/cryptopp/issues/567">Issue 567</A>,
///  <A HREF="https://github.com/weidai11/cryptopp/issues/1059">Issue 1059</A>
/// \since Crypto++ 1.0
struct ElGamalKeys
{
	/// \brief Implements DL_GroupParameters interface
	typedef DL_CryptoKeys_ElGamal::GroupParameters GroupParameters;
	/// \brief Implements DL_PrivateKey interface
	typedef DL_PrivateKey_ElGamal<DL_CryptoKeys_ElGamal::PrivateKey> PrivateKey;
	/// \brief Implements DL_PublicKey interface
	typedef DL_PublicKey_ElGamal<DL_CryptoKeys_ElGamal::PublicKey> PublicKey;
};

/// \brief ElGamal encryption scheme with non-standard padding
/// \details ElGamal provide the algorithm implementation ElGamal key
///  agreement and encryption schemes.
/// \details The ElGamal class [mistakenly] used the OID for DSA from about
///  Crypto++ 1.0 through Crypto++ 8.2. At Crypto++ 8.3 the OID was fixed
///  and now uses ElGamal encryption, which is 1.3.14.7.2.1.1.
///  If you need to <tt>Load</tt> an ElGamal key with the wrong OID then
///  see <A HREF="https://www.cryptopp.com/wiki/ElGamal">ElGamal</A> on
///  the Crypto++ wiki.
/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/876">Issue 876</A>,
///  <A HREF="https://github.com/weidai11/cryptopp/issues/567">Issue 567</A>
/// \since Crypto++ 1.0
struct ElGamal
{
	typedef DL_CryptoSchemeOptions<ElGamal, ElGamalKeys, int, int, int> SchemeOptions;
	typedef SchemeOptions::PrivateKey PrivateKey;
	typedef SchemeOptions::PublicKey PublicKey;

	/// \brief The algorithm name
	/// \return the algorithm name
	/// \details StaticAlgorithmName returns the algorithm's name as a static
	///  member function.
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "ElgamalEnc/Crypto++Padding";}

	/// \brief Implements DL_GroupParameters interface
	typedef SchemeOptions::GroupParameters GroupParameters;
	/// \brief Implements PK_Encryptor interface
	typedef PK_FinalTemplate<ElGamalObjectImpl<DL_EncryptorBase<Integer>, SchemeOptions, SchemeOptions::PublicKey> > Encryptor;
	/// \brief Implements PK_Encryptor interface
	typedef PK_FinalTemplate<ElGamalObjectImpl<DL_DecryptorBase<Integer>, SchemeOptions, SchemeOptions::PrivateKey> > Decryptor;
};

typedef ElGamal::Encryptor ElGamalEncryptor;
typedef ElGamal::Decryptor ElGamalDecryptor;

NAMESPACE_END

#endif
