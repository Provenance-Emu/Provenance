// validat8.cpp - originally written and placed in the public domain by Wei Dai
//                CryptoPP::Test namespace added by JW in February 2017.
//                Source files split in July 2018 to expedite compiles.

// Local Changes: Header include path

#include "pch.h"

#define CRYPTOPP_ENABLE_NAMESPACE_WEAK 1

#include "cryptlib.h"
#include "cpu.h"
#include "validate.h"

#include "asn.h"
#include "oids.h"

#include "luc.h"
#include "../externals/include/cryptopp/rsa.h"
#include "xtr.h"
#include "rabin.h"
#include "pubkey.h"
#include "elgamal.h"
#include "xtrcrypt.h"
#include "eccrypto.h"

#include "hex.h"
#include "base64.h"

#include <iostream>
#include <iomanip>
#include <sstream>

// Aggressive stack checking with VS2005 SP1 and above.
#if (_MSC_FULL_VER >= 140050727)
# pragma strict_gs_check (on)
#endif

#if CRYPTOPP_MSC_VERSION
# pragma warning(disable: 4505 4355)
#endif

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(Test)

ANONYMOUS_NAMESPACE_BEGIN

inline byte* C2B(char* ptr) {
    return reinterpret_cast<byte*>(ptr);
}

inline const byte* C2B(const char* ptr) {
    return reinterpret_cast<const byte*>(ptr);
}

inline bool operator==(const RSA::PrivateKey& lhs, const RSA::PrivateKey& rhs) {
	return lhs.GetModulus() == rhs.GetModulus() &&
		lhs.GetPublicExponent() == rhs.GetPublicExponent() &&
		lhs.GetPrivateExponent() == rhs.GetPrivateExponent();
}

inline bool operator!=(const RSA::PrivateKey& lhs, const RSA::PrivateKey& rhs) {
	return !operator==(lhs, rhs);
}

inline bool operator==(const RSA::PublicKey& lhs, const RSA::PublicKey& rhs) {
	return lhs.GetModulus() == rhs.GetModulus() &&
		lhs.GetPublicExponent() == rhs.GetPublicExponent();
}

inline bool operator!=(const RSA::PublicKey& lhs, const RSA::PublicKey& rhs) {
	return !operator==(lhs, rhs);
}

inline bool operator==(const LUC::PrivateKey& lhs, const LUC::PrivateKey& rhs) {
	return lhs.GetModulus() == rhs.GetModulus() &&
		lhs.GetPublicExponent() == rhs.GetPublicExponent() &&
		lhs.GetPrime1() == rhs.GetPrime1() &&
		lhs.GetPrime2() == rhs.GetPrime2() &&
		lhs.GetMultiplicativeInverseOfPrime2ModPrime1() == rhs.GetMultiplicativeInverseOfPrime2ModPrime1();
}

inline bool operator!=(const LUC::PrivateKey& lhs, const LUC::PrivateKey& rhs) {
	return !operator==(lhs, rhs);
}

inline bool operator==(const LUC::PublicKey& lhs, const LUC::PublicKey& rhs) {
	return lhs.GetModulus() == rhs.GetModulus() &&
		lhs.GetPublicExponent() == rhs.GetPublicExponent();
}

inline bool operator!=(const LUC::PublicKey& lhs, const LUC::PublicKey& rhs) {
	return !operator==(lhs, rhs);
}

inline bool operator==(const Rabin::PrivateKey& lhs, const Rabin::PrivateKey& rhs) {
	return lhs.GetModulus() == rhs.GetModulus() &&
		lhs.GetQuadraticResidueModPrime1() == rhs.GetQuadraticResidueModPrime1() &&
		lhs.GetQuadraticResidueModPrime2() == rhs.GetQuadraticResidueModPrime2() &&
		lhs.GetPrime1() == rhs.GetPrime1() &&
		lhs.GetPrime2() == rhs.GetPrime2() &&
		lhs.GetMultiplicativeInverseOfPrime2ModPrime1() == rhs.GetMultiplicativeInverseOfPrime2ModPrime1();
}

inline bool operator!=(const Rabin::PrivateKey& lhs, const Rabin::PrivateKey& rhs) {
	return !operator==(lhs, rhs);
}

inline bool operator==(const Rabin::PublicKey& lhs, const Rabin::PublicKey& rhs) {
	return lhs.GetModulus() == rhs.GetModulus() &&
		lhs.GetQuadraticResidueModPrime1() == rhs.GetQuadraticResidueModPrime1() &&
		lhs.GetQuadraticResidueModPrime2() == rhs.GetQuadraticResidueModPrime2();
}

inline bool operator!=(const Rabin::PublicKey& lhs, const Rabin::PublicKey& rhs) {
	return !operator==(lhs, rhs);
}

ANONYMOUS_NAMESPACE_END

bool ValidateRSA_Encrypt()
{
	// Must be large enough for RSA-3072 to test SHA3_256
	byte out[256], outPlain[128];
	bool pass = true, fail;

#if defined(CRYPTOPP_EXTENDED_VALIDATION)
	{
		FileSource keys(DataDir("TestData/rsa1024.dat").c_str(), true, new HexDecoder);
		RSA::PrivateKey rsaPriv; rsaPriv.Load(keys);
		RSA::PublicKey rsaPub(rsaPriv);

		const Integer& n = rsaPriv.GetModulus();
		const Integer& e = rsaPriv.GetPublicExponent();
		const Integer& d = rsaPriv.GetPrivateExponent();

		RSA::PrivateKey rsaPriv2;
		rsaPriv2.Initialize(n, e, d);

		fail = (rsaPriv != rsaPriv2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "RSA::PrivateKey initialization\n";

		RSA::PublicKey rsaPub2;
		rsaPub2.Initialize(n, e);

		fail = (rsaPub != rsaPub2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "RSA::PublicKey initialization\n";
	}
	{
		FileSource keys(DataDir("TestData/rsa1024.dat").c_str(), true, new HexDecoder);
		RSA::PrivateKey rsaPriv; rsaPriv.Load(keys);

		ByteQueue q;
		rsaPriv.DEREncodePrivateKey(q);

		RSA::PrivateKey rsaPriv2;
		rsaPriv2.BERDecodePrivateKey(q, true, q.MaxRetrievable());

		fail = (rsaPriv != rsaPriv2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "RSA::PrivateKey encoding and decoding\n";
	}
#endif

	{
		FileSource keys(DataDir("TestData/rsa1024.dat").c_str(), true, new HexDecoder);
		RSAES_PKCS1v15_Decryptor rsaPriv(keys);
		RSAES_PKCS1v15_Encryptor rsaPub(rsaPriv);

		fail = !CryptoSystemValidate(rsaPriv, rsaPub);
		pass = pass && !fail;
	}
	{
		RSAES<OAEP<SHA1> >::Decryptor rsaPriv(GlobalRNG(), 512);
		RSAES<OAEP<SHA1> >::Encryptor rsaPub(rsaPriv);

		fail = !CryptoSystemValidate(rsaPriv, rsaPub);
		pass = pass && !fail;
	}
	{
		const byte plain[] =
			"\x54\x85\x9b\x34\x2c\x49\xea\x2a";
		const byte encrypted[] =
			"\x14\xbd\xdd\x28\xc9\x83\x35\x19\x23\x80\xe8\xe5\x49\xb1\x58\x2a"
			"\x8b\x40\xb4\x48\x6d\x03\xa6\xa5\x31\x1f\x1f\xd5\xf0\xa1\x80\xe4"
			"\x17\x53\x03\x29\xa9\x34\x90\x74\xb1\x52\x13\x54\x29\x08\x24\x52"
			"\x62\x51";
		const byte oaepSeed[] =
			"\xaa\xfd\x12\xf6\x59\xca\xe6\x34\x89\xb4\x79\xe5\x07\x6d\xde\xc2"
			"\xf0\x6c\xb5\x8f";
		ByteQueue bq;
		bq.Put(oaepSeed, 20);
		FixedRNG rng(bq);

		FileSource privFile(DataDir("TestData/rsa400pv.dat").c_str(), true, new HexDecoder);
		FileSource pubFile(DataDir("TestData/rsa400pb.dat").c_str(), true, new HexDecoder);
		RSAES_OAEP_SHA_Decryptor rsaPriv;
		rsaPriv.AccessKey().BERDecodePrivateKey(privFile, false, 0);
		RSAES_OAEP_SHA_Encryptor rsaPub(pubFile);

		memset(out, 0, 50);
		memset(outPlain, 0, 8);
		rsaPub.Encrypt(rng, plain, 8, out);
		DecodingResult result = rsaPriv.FixedLengthDecrypt(GlobalRNG(), encrypted, outPlain);
		fail = !result.isValidCoding || (result.messageLength!=8) || memcmp(out, encrypted, 50) || memcmp(plain, outPlain, 8);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "PKCS 2.0 encryption and decryption\n";
	}

	return pass;
}

bool ValidateLUC_Encrypt()
{
	bool pass = true, fail;

#if defined(CRYPTOPP_EXTENDED_VALIDATION)
	{
		FileSource keys(DataDir("TestData/luc1024.dat").c_str(), true, new HexDecoder);
		LUC::PrivateKey lucPriv; lucPriv.BERDecode(keys);
		LUC::PublicKey lucPub(lucPriv);

		const Integer& n = lucPriv.GetModulus();
		const Integer& e = lucPriv.GetPublicExponent();
		const Integer& p = lucPriv.GetPrime1();
		const Integer& q = lucPriv.GetPrime2();
		const Integer& u = lucPriv.GetMultiplicativeInverseOfPrime2ModPrime1();

		LUC::PrivateKey lucPriv2;
		lucPriv2.Initialize(n, e, p, q, u);

		fail = (lucPriv != lucPriv2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "LUC::PrivateKey initialization\n";

		LUC::PublicKey lucPub2;
		lucPub2.Initialize(n, e);

		fail = (lucPub != lucPub2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "LUC::PublicKey initialization\n";
	}
	{
		FileSource keys(DataDir("TestData/luc1024.dat").c_str(), true, new HexDecoder);
		LUC::PrivateKey lucPriv; lucPriv.BERDecode(keys);

		ByteQueue q;
		lucPriv.DEREncode(q);

		LUC::PrivateKey lucPriv2;
		lucPriv2.BERDecode(q);

		fail = (lucPriv != lucPriv2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "LUC::PrivateKey encoding and decoding\n";
	}
	{
		FileSource keys(DataDir("TestData/luc1024.dat").c_str(), true, new HexDecoder);
		LUC::PrivateKey lucPriv; lucPriv.BERDecode(keys);
		LUC::PublicKey lucPub(lucPriv);

		ByteQueue q;
		lucPub.DEREncode(q);

		LUC::PublicKey lucPub2;
		lucPub2.BERDecode(q);

		fail = (lucPub != lucPub2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "LUC::PublicKey encoding and decoding\n";
	}
#endif

	LUCES_OAEP_SHA_Decryptor priv(GlobalRNG(), 512);
	LUCES_OAEP_SHA_Encryptor pub(priv);
	fail = !CryptoSystemValidate(priv, pub);
	pass = pass && !fail;

	return pass;
}

bool ValidateLUC_DL_Encrypt()
{
	std::cout << "\nLUC-IES validation suite running...\n\n";

	FileSource fc(DataDir("TestData/lucc512.dat").c_str(), true, new HexDecoder);
	LUC_IES<>::Decryptor privC(fc);
	LUC_IES<>::Encryptor pubC(privC);
	return CryptoSystemValidate(privC, pubC);
}

bool ValidateRabin_Encrypt()
{
	bool pass = true, fail;

#if defined(CRYPTOPP_EXTENDED_VALIDATION)
	{
		FileSource keys(DataDir("TestData/rabi1024.dat").c_str(), true, new HexDecoder);
		Rabin::PrivateKey rabinPriv; rabinPriv.BERDecode(keys);
		Rabin::PublicKey rabinPub(rabinPriv);

		const Integer& n = rabinPriv.GetModulus();
		const Integer& r = rabinPriv.GetQuadraticResidueModPrime1();
		const Integer& s = rabinPriv.GetQuadraticResidueModPrime2();
		const Integer& p = rabinPriv.GetPrime1();
		const Integer& q = rabinPriv.GetPrime2();
		const Integer& u = rabinPriv.GetMultiplicativeInverseOfPrime2ModPrime1();

		Rabin::PrivateKey rabinPriv2;
		rabinPriv2.Initialize(n, r, s, p, q, u);

		fail = (rabinPriv != rabinPriv2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "Rabin::PrivateKey initialization\n";

		Rabin::PublicKey rabinPub2;
		rabinPub2.Initialize(n, r, s);

		fail = (rabinPub != rabinPub2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "Rabin::PublicKey initialization\n";
	}
	{
		FileSource keys(DataDir("TestData/rabi1024.dat").c_str(), true, new HexDecoder);
		Rabin::PrivateKey rabinPriv; rabinPriv.BERDecode(keys);

		ByteQueue q;
		rabinPriv.DEREncode(q);

		Rabin::PrivateKey rabinPriv2;
		rabinPriv2.BERDecode(q);

		fail = (rabinPriv != rabinPriv2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "Rabin::PrivateKey encoding and decoding\n";
	}
	{
		FileSource keys(DataDir("TestData/rabi1024.dat").c_str(), true, new HexDecoder);
		Rabin::PrivateKey rabinPriv; rabinPriv.BERDecode(keys);
		Rabin::PublicKey rabinPub(rabinPriv);

		ByteQueue q;
		rabinPub.DEREncode(q);

		Rabin::PublicKey rabinPub2;
		rabinPub2.BERDecode(q);

		fail = (rabinPub != rabinPub2);
		pass = pass && !fail;

		std::cout << (fail ? "FAILED    " : "passed    ");
		std::cout << "Rabin::PublicKey encoding and decoding\n";
	}
#endif

	FileSource f(DataDir("TestData/rabi1024.dat").c_str(), true, new HexDecoder);
	RabinES<OAEP<SHA1> >::Decryptor priv(f);
	RabinES<OAEP<SHA1> >::Encryptor pub(priv);
	fail = !CryptoSystemValidate(priv, pub);
	pass = pass && !fail;

	return pass;
}

bool ValidateECP_Encrypt()
{
	ECIES<ECP>::Decryptor cpriv(GlobalRNG(), ASN1::secp192r1());
	ECIES<ECP>::Encryptor cpub(cpriv);
	ByteQueue bq;
	cpriv.GetKey().DEREncode(bq);
	cpub.AccessKey().AccessGroupParameters().SetEncodeAsOID(true);
	cpub.GetKey().DEREncode(bq);

	cpub.AccessKey().Precompute();
	cpriv.AccessKey().Precompute();
	bool pass = CryptoSystemValidate(cpriv, cpub);

	std::cout << "Turning on point compression..." << std::endl;
	cpriv.AccessKey().AccessGroupParameters().SetPointCompression(true);
	cpub.AccessKey().AccessGroupParameters().SetPointCompression(true);
	pass = CryptoSystemValidate(cpriv, cpub) && pass;

	return pass;
}

// https://github.com/weidai11/cryptopp/issues/856
// Not to be confused with NullHash in trunhash.h.
class NULL_Hash : public CryptoPP::IteratedHashWithStaticTransform
    <CryptoPP::word32, CryptoPP::BigEndian, 32, 0, NULL_Hash, 0>
{
public:
    static void InitState(HashWordType *state) {
        CRYPTOPP_UNUSED(state);
    }
    static void Transform(CryptoPP::word32 *digest, const CryptoPP::word32 *data) {
        CRYPTOPP_UNUSED(digest); CRYPTOPP_UNUSED(data);
    }
    static const char *StaticAlgorithmName() {
        return "NULL_Hash";
    }
};

// https://github.com/weidai11/cryptopp/issues/856
template <class EC, class HASH = SHA1, class COFACTOR_OPTION = NoCofactorMultiplication, bool DHAES_MODE = true, bool LABEL_OCTETS = false>
struct ECIES_NULLDigest
	: public DL_ES<
		DL_Keys_EC<EC>,
		DL_KeyAgreementAlgorithm_DH<typename EC::Point, COFACTOR_OPTION>,
		DL_KeyDerivationAlgorithm_P1363<typename EC::Point, DHAES_MODE, P1363_KDF2<HASH> >,
		DL_EncryptionAlgorithm_Xor<HMAC<NULL_Hash>, DHAES_MODE, LABEL_OCTETS>,
		ECIES<EC> >
{
	// TODO: fix this after name is standardized
	CRYPTOPP_STATIC_CONSTEXPR const char* CRYPTOPP_API StaticAlgorithmName() {return "ECIES-NULLDigest";}
};

bool ValidateECP_NULLDigest_Encrypt()
{
	ECIES_NULLDigest<ECP>::Decryptor cpriv(GlobalRNG(), ASN1::secp256k1());
	ECIES_NULLDigest<ECP>::Encryptor cpub(cpriv);
	ByteQueue bq;
	cpriv.GetKey().DEREncode(bq);
	cpub.AccessKey().AccessGroupParameters().SetEncodeAsOID(true);
	cpub.GetKey().DEREncode(bq);

	cpub.AccessKey().Precompute();
	cpriv.AccessKey().Precompute();
	bool pass = CryptoSystemValidate(cpriv, cpub);

	std::cout << "Turning on point compression..." << std::endl;
	cpriv.AccessKey().AccessGroupParameters().SetPointCompression(true);
	cpub.AccessKey().AccessGroupParameters().SetPointCompression(true);
	pass = CryptoSystemValidate(cpriv, cpub) && pass;

	return pass;
}

// Ensure interop with Crypto++ 5.6.4 and earlier
bool ValidateECP_Legacy_Encrypt()
{
	std::cout << "\nLegacy ECIES ECP validation suite running...\n\n";
	bool pass = true;
	{
		FileSource fc(DataDir("TestData/ecies_p160.dat").c_str(), true, new HexDecoder);
		ECIES<ECP,SHA1,NoCofactorMultiplication,false,true>::Decryptor privC(fc);
		ECIES<ECP,SHA1,NoCofactorMultiplication,false,true>::Encryptor pubC(privC);

		pass = CryptoSystemValidate(privC, pubC) && pass;

		// Test data generated by Crypto++ 5.6.2.
		// Also see https://github.com/weidai11/cryptopp/pull/857.
		const std::string plain = "Yoda said, Do or do not. There is no try.";
		const std::string cipher =
			"\x04\xF6\xC1\xB1\xFA\xAC\x8A\xD5\xD3\x96\xE7\x13\xAE\xBD\x0C\xCE"
			"\x15\xCF\x44\x54\x08\x63\xCC\xBF\x89\x4D\xD0\xB8\x38\xA1\x3A\xB2"
			"\x90\x75\x86\x82\x7F\x9D\x95\x26\xA5\x74\x13\x3A\x74\x63\x11\x71"
			"\x70\x4C\x01\xA4\x08\x04\x95\x69\x6A\x91\xF0\xC0\xA4\xBD\x1E\xAA"
			"\x59\x57\xB8\xA9\xD2\xF7\x7C\x98\xE3\xC5\xE3\xF4\x4F\xA7\x6E\x73"
			"\x83\xF3\x1E\x05\x73\xA4\xEE\x63\x55\xFD\x6D\x31\xBB\x9E\x36\x4C"
			"\x79\xD0\x76\xC0\x0D\xE9";

		std::string recover;
		recover.resize(privC.MaxPlaintextLength(cipher.size()));

		DecodingResult result = privC.Decrypt(GlobalRNG(), C2B(&cipher[0]), cipher.size(), C2B(&recover[0]));
		if (result.isValidCoding)
			recover.resize(result.messageLength);
		else
			recover.resize(0);

		pass = (plain == recover) && pass;
		std::cout << (pass ? "passed    " : "FAILED    ");
		std::cout << "decryption known answer\n";
	}
	return pass;
}

// Ensure interop with Crypto++ 5.6.4 and earlier
bool ValidateEC2N_Legacy_Encrypt()
{
	std::cout << "\nLegacy ECIES EC2N validation suite running...\n\n";
	bool pass = true;
	{
		FileSource fc(DataDir("TestData/ecies_t163.dat").c_str(), true, new HexDecoder);
		ECIES<EC2N,SHA1,NoCofactorMultiplication,false,true>::Decryptor privC(fc);
		ECIES<EC2N,SHA1,NoCofactorMultiplication,false,true>::Encryptor pubC(privC);

		pass = CryptoSystemValidate(privC, pubC) && pass;

		// Test data generated by Crypto++ 5.6.2.
		// Also see https://github.com/weidai11/cryptopp/pull/857.
		const std::string plain = "Yoda said, Do or do not. There is no try.";
		const std::string cipher =
			"\x04\x01\x3F\x64\x94\x6A\xBE\x2B\x7E\x48\x67\x63\xA2\xD4\x01\xEF"
			"\x2B\x13\x1C\x9A\x1B\x7C\x07\x4B\x89\x78\x6C\x65\x51\x1C\x1A\x4E"
			"\x20\x7F\xB5\xBF\x12\x3B\x6E\x0A\x87\xFD\xB7\x94\xEF\x4B\xED\x40"
			"\xD4\x7A\xCF\xB6\xFC\x9B\x6D\xB0\xB8\x43\x99\x7E\x37\xC1\xF0\xC0"
			"\x95\xD4\x80\xE1\x8B\x84\xAE\x64\x9F\xA5\xBA\x32\x95\x8A\xD1\xBE"
			"\x7F\xDE\x7E\xA9\xE6\x59\xBF\x89\xA6\xE9\x9F\x5B\x64\xB4\xDD\x0E"
			"\x76\xB6\x82\xF6\xA9\xAD\xB5\xC4";

		std::string recover;
		recover.resize(privC.MaxPlaintextLength(cipher.size()));

		DecodingResult result = privC.Decrypt(GlobalRNG(), C2B(&cipher[0]), cipher.size(), C2B(&recover[0]));
		if (result.isValidCoding)
			recover.resize(result.messageLength);
		else
			recover.resize(0);

		pass = (plain == recover) && pass;
		std::cout << (pass ? "passed    " : "FAILED    ");
		std::cout << "decryption known answer\n";
	}
	return pass;
}

bool ValidateEC2N_Encrypt()
{
	// DEREncode() changed to Save() at Issue 569.
	ECIES<EC2N>::Decryptor cpriv(GlobalRNG(), ASN1::sect193r1());
	ECIES<EC2N>::Encryptor cpub(cpriv);
	ByteQueue bq;
	cpriv.AccessMaterial().Save(bq);
	cpub.AccessKey().AccessGroupParameters().SetEncodeAsOID(true);
	cpub.AccessMaterial().Save(bq);
	bool pass = CryptoSystemValidate(cpriv, cpub);

	std::cout << "Turning on point compression..." << std::endl;
	cpriv.AccessKey().AccessGroupParameters().SetPointCompression(true);
	cpub.AccessKey().AccessGroupParameters().SetPointCompression(true);
	pass = CryptoSystemValidate(cpriv, cpub) && pass;

	return pass;
}

bool ValidateElGamal()
{
	std::cout << "\nElGamal validation suite running...\n\n";
	bool pass = true;
	{
		// Data from https://github.com/weidai11/cryptopp/issues/876.
		const std::string encodedPublicKey =
			"MHYwTwYGKw4HAgEBMEUCIQDebUvQDd9UPMmD27BJ ovZSIgWfexL0SWkfJQPMLsJvMwIgDy/kEthwO6Q+"
			"L8XHnzumnEKs+txH8QkQD+M/8u82ql0DIwACIAY6 rfW+BTcRZ9QAJovgoB8DgNLJ8ocqOeF4nEBB0DHH";
		StringSource decodedPublicKey(encodedPublicKey, true, new Base64Decoder);

		ElGamal::PublicKey publicKey;
		publicKey.Load(decodedPublicKey);
		pass = publicKey.Validate(GlobalRNG(), 3) && pass;
	}
	{
		// Data from https://github.com/weidai11/cryptopp/issues/876.
		const std::string encodedPrivateKey =
			"MHkCAQAwTwYGKw4HAgEBMEUCIQDebUvQDd9UPMmD 27BJovZSIgWfexL0SWkfJQPMLsJvMwIgDy/kEthw"
			"O6Q+L8XHnzumnEKs+txH8QkQD+M/8u82ql0EIwIh AJb0S4TZLvApTVjXZyocPJ5tUgWgRqScXm5vNqu2"
			"YqdM";
		StringSource decodedPrivateKey(encodedPrivateKey, true, new Base64Decoder);

		ElGamal::PrivateKey privateKey;
		privateKey.Load(decodedPrivateKey);
		pass = privateKey.Validate(GlobalRNG(), 3) && pass;
	}
	{
		FileSource fc(DataDir("TestData/elgc1024.dat").c_str(), true, new HexDecoder);
		ElGamalDecryptor privC(fc);
		ElGamalEncryptor pubC(privC);
		privC.AccessKey().Precompute();
		ByteQueue queue;
		privC.AccessKey().SavePrecomputation(queue);
		privC.AccessKey().LoadPrecomputation(queue);

		pass = CryptoSystemValidate(privC, pubC) && pass;
	}
	return pass;
}

bool ValidateDLIES()
{
	std::cout << "\nDLIES validation suite running...\n\n";
	bool pass = true;
	{
		FileSource fc(DataDir("TestData/dlie1024.dat").c_str(), true, new HexDecoder);
		DLIES<>::Decryptor privC(fc);
		DLIES<>::Encryptor pubC(privC);
		pass = CryptoSystemValidate(privC, pubC) && pass;
	}
	{
		std::cout << "Generating new encryption key..." << std::endl;
		DLIES<>::GroupParameters gp;
		gp.GenerateRandomWithKeySize(GlobalRNG(), 128);
		DLIES<>::Decryptor decryptor;
		decryptor.AccessKey().GenerateRandom(GlobalRNG(), gp);
		DLIES<>::Encryptor encryptor(decryptor);

		pass = CryptoSystemValidate(decryptor, encryptor) && pass;
	}
	return pass;
}

NAMESPACE_END  // Test
NAMESPACE_END  // CryptoPP
