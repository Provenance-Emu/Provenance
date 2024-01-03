// bench3.cpp - originally written and placed in the public domain by Wei Dai
//              CryptoPP::Test namespace added by JW in February 2017

// Local Changes: Header include path

#include "cryptlib.h"
#include "bench.h"
#include "validate.h"

#include "cpu.h"
#include "../externals/include/cryptopp/factory.h"
#include "algparam.h"
#include "argnames.h"
#include "smartptr.h"
#include "stdcpp.h"

#include "pubkey.h"
#include "gfpcrypt.h"
#include "eccrypto.h"
#include "pkcspad.h"

#include "files.h"
#include "filters.h"
#include "hex.h"
#include <rsa.h>
#include "nr.h"
#include "dsa.h"
#include "luc.h"
#include "rw.h"
#include "ecp.h"
#include "ec2n.h"
#include "asn.h"
#include "dh.h"
#include "mqv.h"
#include "hmqv.h"
#include "fhmqv.h"
#include "xed25519.h"
#include "xtrcrypt.h"
#include "esign.h"
#include "pssr.h"
#include "oids.h"
#include "randpool.h"
#include "stdcpp.h"
#include "hrtimer.h"

#if CRYPTOPP_MSC_VERSION
# pragma warning(disable: 4505 4355)
#endif

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(Test)

void BenchMarkEncryption(const char *name, PK_Encryptor &key, double timeTotal, bool pc = false)
{
	unsigned int len = 16;
	SecByteBlock plaintext(len), ciphertext(key.CiphertextLength(len));
	Test::GlobalRNG().GenerateBlock(plaintext, len);

	unsigned int i = 0;
	double timeTaken;

	ThreadUserTimer timer;
	timer.StartTimer();

	do
	{
		key.Encrypt(Test::GlobalRNG(), plaintext, len, ciphertext);
		++i; timeTaken = timer.ElapsedTimeAsDouble();
	}
	while (timeTaken < timeTotal);

	std::string provider = key.AlgorithmProvider();
	OutputResultOperations(name, provider.c_str(), "Encryption", pc, i, timeTaken);

	if (!pc && key.GetMaterial().SupportsPrecomputation())
	{
		key.AccessMaterial().Precompute(16);
		BenchMarkEncryption(name, key, timeTotal, true);
	}
}

void BenchMarkDecryption(const char *name, PK_Decryptor &priv, PK_Encryptor &pub, double timeTotal)
{
	unsigned int len = 16;
	SecByteBlock ciphertext(pub.CiphertextLength(len));
	SecByteBlock plaintext(pub.MaxPlaintextLength(ciphertext.size()));
	Test::GlobalRNG().GenerateBlock(plaintext, len);
	pub.Encrypt(Test::GlobalRNG(), plaintext, len, ciphertext);

	unsigned int i = 0;
	double timeTaken;

	ThreadUserTimer timer;
	timer.StartTimer();

	do
	{
		priv.Decrypt(Test::GlobalRNG(), ciphertext, ciphertext.size(), plaintext);
		++i; timeTaken = timer.ElapsedTimeAsDouble();
	}
	while (timeTaken < timeTotal);

	std::string provider = priv.AlgorithmProvider();
	OutputResultOperations(name, provider.c_str(), "Decryption", false, i, timeTaken);
}

void BenchMarkSigning(const char *name, PK_Signer &key, double timeTotal, bool pc=false)
{
	unsigned int len = 16;
	AlignedSecByteBlock message(len), signature(key.SignatureLength());
	Test::GlobalRNG().GenerateBlock(message, len);

	unsigned int i = 0;
	double timeTaken;

	ThreadUserTimer timer;
	timer.StartTimer();

	do
	{
		(void)key.SignMessage(Test::GlobalRNG(), message, len, signature);
		++i; timeTaken = timer.ElapsedTimeAsDouble();
	}
	while (timeTaken < timeTotal);

	std::string provider = key.AlgorithmProvider();
	OutputResultOperations(name, provider.c_str(), "Signature", pc, i, timeTaken);

	if (!pc && key.GetMaterial().SupportsPrecomputation())
	{
		key.AccessMaterial().Precompute(16);
		BenchMarkSigning(name, key, timeTotal, true);
	}
}

void BenchMarkVerification(const char *name, const PK_Signer &priv, PK_Verifier &pub, double timeTotal, bool pc=false)
{
	unsigned int len = 16;
	AlignedSecByteBlock message(len), signature(pub.SignatureLength());
	Test::GlobalRNG().GenerateBlock(message, len);
	priv.SignMessage(Test::GlobalRNG(), message, len, signature);

	unsigned int i = 0;
	double timeTaken;

	ThreadUserTimer timer;
	timer.StartTimer();

	do
	{
		(void)pub.VerifyMessage(message, len, signature, signature.size());
		++i; timeTaken = timer.ElapsedTimeAsDouble();
	}
	while (timeTaken < timeTotal);

	std::string provider = pub.AlgorithmProvider();
	OutputResultOperations(name, provider.c_str(), "Verification", pc, i, timeTaken);

	if (!pc && pub.GetMaterial().SupportsPrecomputation())
	{
		pub.AccessMaterial().Precompute(16);
		BenchMarkVerification(name, priv, pub, timeTotal, true);
	}
}

void BenchMarkKeyGen(const char *name, SimpleKeyAgreementDomain &d, double timeTotal, bool pc=false)
{
	SecByteBlock priv(d.PrivateKeyLength()), pub(d.PublicKeyLength());

	unsigned int i = 0;
	double timeTaken;

	ThreadUserTimer timer;
	timer.StartTimer();

	do
	{
		d.GenerateKeyPair(Test::GlobalRNG(), priv, pub);
		++i; timeTaken = timer.ElapsedTimeAsDouble();
	}
	while (timeTaken < timeTotal);

	std::string provider = d.AlgorithmProvider();
	OutputResultOperations(name, provider.c_str(), "Key-Pair Generation", pc, i, timeTaken);

	if (!pc && d.GetMaterial().SupportsPrecomputation())
	{
		d.AccessMaterial().Precompute(16);
		BenchMarkKeyGen(name, d, timeTotal, true);
	}
}

void BenchMarkKeyGen(const char *name, AuthenticatedKeyAgreementDomain &d, double timeTotal, bool pc=false)
{
	SecByteBlock priv(d.EphemeralPrivateKeyLength()), pub(d.EphemeralPublicKeyLength());

	unsigned int i = 0;
	double timeTaken;

	ThreadUserTimer timer;
	timer.StartTimer();

	do
	{
		d.GenerateEphemeralKeyPair(Test::GlobalRNG(), priv, pub);
		++i; timeTaken = timer.ElapsedTimeAsDouble();
	}
	while (timeTaken < timeTotal);

	std::string provider = d.AlgorithmProvider();
	OutputResultOperations(name, provider.c_str(), "Key-Pair Generation", pc, i, timeTaken);

	if (!pc && d.GetMaterial().SupportsPrecomputation())
	{
		d.AccessMaterial().Precompute(16);
		BenchMarkKeyGen(name, d, timeTotal, true);
	}
}

void BenchMarkAgreement(const char *name, SimpleKeyAgreementDomain &d, double timeTotal, bool pc=false)
{
	SecByteBlock priv1(d.PrivateKeyLength()), priv2(d.PrivateKeyLength());
	SecByteBlock pub1(d.PublicKeyLength()), pub2(d.PublicKeyLength());
	d.GenerateKeyPair(Test::GlobalRNG(), priv1, pub1);
	d.GenerateKeyPair(Test::GlobalRNG(), priv2, pub2);
	SecByteBlock val(d.AgreedValueLength());

	unsigned int i = 0;
	double timeTaken;

	ThreadUserTimer timer;
	timer.StartTimer();

	do
	{
		d.Agree(val, priv1, pub2);
		d.Agree(val, priv2, pub1);
		i+=2; timeTaken = timer.ElapsedTimeAsDouble();
	}
	while (timeTaken < timeTotal);

	std::string provider = d.AlgorithmProvider();
	OutputResultOperations(name, provider.c_str(), "Key Agreement", pc, i, timeTaken);
}

void BenchMarkAgreement(const char *name, AuthenticatedKeyAgreementDomain &d, double timeTotal, bool pc=false)
{
	SecByteBlock spriv1(d.StaticPrivateKeyLength()), spriv2(d.StaticPrivateKeyLength());
	SecByteBlock epriv1(d.EphemeralPrivateKeyLength()), epriv2(d.EphemeralPrivateKeyLength());
	SecByteBlock spub1(d.StaticPublicKeyLength()), spub2(d.StaticPublicKeyLength());
	SecByteBlock epub1(d.EphemeralPublicKeyLength()), epub2(d.EphemeralPublicKeyLength());
	d.GenerateStaticKeyPair(Test::GlobalRNG(), spriv1, spub1);
	d.GenerateStaticKeyPair(Test::GlobalRNG(), spriv2, spub2);
	d.GenerateEphemeralKeyPair(Test::GlobalRNG(), epriv1, epub1);
	d.GenerateEphemeralKeyPair(Test::GlobalRNG(), epriv2, epub2);
	SecByteBlock val(d.AgreedValueLength());

	unsigned int i = 0;
	double timeTaken;

	ThreadUserTimer timer;
	timer.StartTimer();

	do
	{
		d.Agree(val, spriv1, epriv1, spub2, epub2);
		d.Agree(val, spriv2, epriv2, spub1, epub1);
		i+=2; timeTaken = timer.ElapsedTimeAsDouble();
	}
	while (timeTaken < timeTotal);

	std::string provider = d.AlgorithmProvider();
	OutputResultOperations(name, provider.c_str(), "Key Agreement", pc, i, timeTaken);
}

template <class SCHEME>
void BenchMarkCrypto(const char *filename, const char *name, double timeTotal)
{
	FileSource f(DataDir(filename).c_str(), true, new HexDecoder);
	typename SCHEME::Decryptor priv(f);
	typename SCHEME::Encryptor pub(priv);
	BenchMarkEncryption(name, pub, timeTotal);
	BenchMarkDecryption(name, priv, pub, timeTotal);
}

template <class SCHEME>
void BenchMarkSignature(const char *filename, const char *name, double timeTotal)
{
	FileSource f(DataDir(filename).c_str(), true, new HexDecoder);
	typename SCHEME::Signer priv(f);
	typename SCHEME::Verifier pub(priv);
	BenchMarkSigning(name, priv, timeTotal);
	BenchMarkVerification(name, priv, pub, timeTotal);
}

template <class D>
void BenchMarkKeyAgreement(const char *filename, const char *name, double timeTotal)
{
	FileSource f(DataDir(filename).c_str(), true, new HexDecoder);
	D d(f);
	BenchMarkKeyGen(name, d, timeTotal);
	BenchMarkAgreement(name, d, timeTotal);
}

void BenchmarkPublicKeyAlgorithms(double t, double hertz)
{
	g_allocatedTime = t;
	g_hertz = hertz;

	const char *mco;
	if (g_hertz > 1.0f)
		mco = "<TH>Megacycles/Operation";
	else
		mco = "";

	std::cout << "\n<TABLE>";
	std::cout << "\n<COLGROUP><COL style=\"text-align: left;\"><COL style=";
	std::cout << "\"text-align: right;\"><COL style=\"text-align: right;\">";
	std::cout << "\n<THEAD style=\"background: #F0F0F0\">";
	std::cout << "\n<TR><TH>Operation<TH>Milliseconds/Operation" << mco;

	std::cout << "\n<TBODY style=\"background: white;\">";
	{
		BenchMarkCrypto<RSAES<OAEP<SHA1> > >("TestData/rsa1024.dat", "RSA 1024", t);
		BenchMarkCrypto<LUCES<OAEP<SHA1> > >("TestData/luc1024.dat", "LUC 1024", t);
		BenchMarkCrypto<DLIES<> >("TestData/dlie1024.dat", "DLIES 1024", t);
		BenchMarkCrypto<LUC_IES<> >("TestData/lucc512.dat", "LUCELG 512", t);
	}

	std::cout << "\n<TBODY style=\"background: yellow;\">";
	{
		BenchMarkCrypto<RSAES<OAEP<SHA1> > >("TestData/rsa2048.dat", "RSA 2048", t);
		BenchMarkCrypto<LUCES<OAEP<SHA1> > >("TestData/luc2048.dat", "LUC 2048", t);
		BenchMarkCrypto<DLIES<> >("TestData/dlie2048.dat", "DLIES 2048", t);
		BenchMarkCrypto<LUC_IES<> >("TestData/lucc1024.dat", "LUCELG 1024", t);
	}

	std::cout << "\n<TBODY style=\"background: white;\">";
	{
		BenchMarkSignature<RSASS<PSSR, SHA1> >("TestData/rsa1024.dat", "RSA 1024", t);
		BenchMarkSignature<RWSS<PSSR, SHA1> >("TestData/rw1024.dat", "RW 1024", t);
		BenchMarkSignature<LUCSS<PSSR, SHA1> >("TestData/luc1024.dat", "LUC 1024", t);
		BenchMarkSignature<NR<SHA1> >("TestData/nr1024.dat", "NR 1024", t);
		BenchMarkSignature<DSA>("TestData/dsa1024.dat", "DSA 1024", t);
		BenchMarkSignature<LUC_HMP<SHA1> >("TestData/lucs512.dat", "LUC-HMP 512", t);
		BenchMarkSignature<ESIGN<SHA1> >("TestData/esig1023.dat", "ESIGN 1023", t);
		BenchMarkSignature<ESIGN<SHA1> >("TestData/esig1536.dat", "ESIGN 1536", t);
	}

	std::cout << "\n<TBODY style=\"background: yellow;\">";
	{
		BenchMarkSignature<RSASS<PSSR, SHA1> >("TestData/rsa2048.dat", "RSA 2048", t);
		BenchMarkSignature<RWSS<PSSR, SHA1> >("TestData/rw2048.dat", "RW 2048", t);
		BenchMarkSignature<LUCSS<PSSR, SHA1> >("TestData/luc2048.dat", "LUC 2048", t);
		BenchMarkSignature<NR<SHA1> >("TestData/nr2048.dat", "NR 2048", t);
		BenchMarkSignature<LUC_HMP<SHA1> >("TestData/lucs1024.dat", "LUC-HMP 1024", t);
		BenchMarkSignature<ESIGN<SHA1> >("TestData/esig2046.dat", "ESIGN 2046", t);
	}

	std::cout << "\n<TBODY style=\"background: white;\">";
	{
		BenchMarkKeyAgreement<XTR_DH>("TestData/xtrdh171.dat", "XTR-DH 171", t);
		BenchMarkKeyAgreement<XTR_DH>("TestData/xtrdh342.dat", "XTR-DH 342", t);
		BenchMarkKeyAgreement<DH>("TestData/dh1024.dat", "DH 1024", t);
		BenchMarkKeyAgreement<DH>("TestData/dh2048.dat", "DH 2048", t);
		BenchMarkKeyAgreement<LUC_DH>("TestData/lucd512.dat", "LUCDIF 512", t);
		BenchMarkKeyAgreement<LUC_DH>("TestData/lucd1024.dat", "LUCDIF 1024", t);
		BenchMarkKeyAgreement<MQV>("TestData/mqv1024.dat", "MQV 1024", t);
		BenchMarkKeyAgreement<MQV>("TestData/mqv2048.dat", "MQV 2048", t);
	}

	std::cout << "\n</TABLE>" << std::endl;
}

void BenchmarkEllipticCurveAlgorithms(double t, double hertz)
{
	g_allocatedTime = t;
	g_hertz = hertz;

	const char *mco;
	if (g_hertz > 1.0f)
		mco = "<TH>Megacycles/Operation";
	else
		mco = "";

	std::cout << "\n<TABLE>";
	std::cout << "\n<COLGROUP><COL style=\"text-align: left;\"><COL style=";
	std::cout << "\"text-align: right;\"><COL style=\"text-align: right;\">";
	std::cout << "\n<THEAD style=\"background: #F0F0F0\">";
	std::cout << "\n<TR><TH>Operation<TH>Milliseconds/Operation" << mco;

	std::cout << "\n<TBODY style=\"background: white;\">";
	{
		ed25519::Signer sign(Test::GlobalRNG());
		ed25519::Verifier verify(sign);
		x25519 agree(Test::GlobalRNG());

		BenchMarkSigning("ed25519", sign, t);
		BenchMarkVerification("ed25519", sign, verify, t);
		BenchMarkKeyGen("x25519", agree, t);
		BenchMarkAgreement("x25519", agree, t);
	}

#if 0
	std::cout << "\n<TBODY style=\"background: yellow;\">";
	{
		BenchMarkKeyAgreement<ECMQV160>("TestData/mqv160.dat", "MQV P-160", t);
		BenchMarkKeyAgreement<ECMQV256>("TestData/mqv256.dat", "MQV P-256", t);
		BenchMarkKeyAgreement<ECMQV384>("TestData/mqv384.dat", "MQV P-384", t);
		BenchMarkKeyAgreement<ECMQV512>("TestData/mqv512.dat", "MQV P-521", t);

		BenchMarkKeyAgreement<ECHMQV160>("TestData/hmqv160.dat", "HMQV P-160", t);
		BenchMarkKeyAgreement<ECHMQV256>("TestData/hmqv256.dat", "HMQV P-256", t);
		BenchMarkKeyAgreement<ECHMQV384>("TestData/hmqv384.dat", "HMQV P-384", t);
		BenchMarkKeyAgreement<ECHMQV512>("TestData/hmqv512.dat", "HMQV P-521", t);

		BenchMarkKeyAgreement<ECFHMQV160>("TestData/fhmqv160.dat", "FHMQV P-160", t);
		BenchMarkKeyAgreement<ECFHMQV256>("TestData/fhmqv256.dat", "FHMQV P-256", t);
		BenchMarkKeyAgreement<ECFHMQV384>("TestData/fhmqv384.dat", "FHMQV P-384", t);
		BenchMarkKeyAgreement<ECFHMQV512>("TestData/fhmqv512.dat", "FHMQV P-521", t);
	}
#endif

	std::cout << "\n<TBODY style=\"background: yellow;\">";
	{
		ECIES<ECP>::Decryptor cpriv(Test::GlobalRNG(), ASN1::secp256k1());
		ECIES<ECP>::Encryptor cpub(cpriv);
		ECDSA<ECP, SHA1>::Signer spriv(cpriv);
		ECDSA<ECP, SHA1>::Verifier spub(spriv);
		ECDSA_RFC6979<ECP, SHA1>::Signer spriv2(cpriv);
		ECDSA_RFC6979<ECP, SHA1>::Verifier spub2(spriv2);
		ECGDSA<ECP, SHA1>::Signer spriv3(Test::GlobalRNG(), ASN1::secp256k1());
		ECGDSA<ECP, SHA1>::Verifier spub3(spriv3);
		ECDH<ECP>::Domain ecdhc(ASN1::secp256k1());
		ECMQV<ECP>::Domain ecmqvc(ASN1::secp256k1());

		BenchMarkEncryption("ECIES over GF(p) 256", cpub, t);
		BenchMarkDecryption("ECIES over GF(p) 256", cpriv, cpub, t);
		BenchMarkSigning("ECDSA over GF(p) 256", spriv, t);
		BenchMarkVerification("ECDSA over GF(p) 256", spriv, spub, t);
		BenchMarkSigning("ECDSA-RFC6979 over GF(p) 256", spriv2, t);
		BenchMarkVerification("ECDSA-RFC6979 over GF(p) 256", spriv2, spub2, t);
		BenchMarkSigning("ECGDSA over GF(p) 256", spriv3, t);
		BenchMarkVerification("ECGDSA over GF(p) 256", spriv3, spub3, t);
		BenchMarkKeyGen("ECDHC over GF(p) 256", ecdhc, t);
		BenchMarkAgreement("ECDHC over GF(p) 256", ecdhc, t);
		BenchMarkKeyGen("ECMQVC over GF(p) 256", ecmqvc, t);
		BenchMarkAgreement("ECMQVC over GF(p) 256", ecmqvc, t);
	}

	std::cout << "\n<TBODY style=\"background: white;\">";
	{
		ECIES<EC2N>::Decryptor cpriv(Test::GlobalRNG(), ASN1::sect233r1());
		ECIES<EC2N>::Encryptor cpub(cpriv);
		ECDSA<EC2N, SHA1>::Signer spriv(cpriv);
		ECDSA<EC2N, SHA1>::Verifier spub(spriv);
		ECDSA_RFC6979<EC2N, SHA1>::Signer spriv2(cpriv);
		ECDSA_RFC6979<EC2N, SHA1>::Verifier spub2(spriv2);
		ECGDSA<EC2N, SHA1>::Signer spriv3(Test::GlobalRNG(), ASN1::sect233r1());
		ECGDSA<EC2N, SHA1>::Verifier spub3(spriv3);
		ECDH<EC2N>::Domain ecdhc(ASN1::sect233r1());
		ECMQV<EC2N>::Domain ecmqvc(ASN1::sect233r1());

		BenchMarkEncryption("ECIES over GF(2^n) 233", cpub, t);
		BenchMarkDecryption("ECIES over GF(2^n) 233", cpriv, cpub, t);
		BenchMarkSigning("ECDSA over GF(2^n) 233", spriv, t);
		BenchMarkVerification("ECDSA over GF(2^n) 233", spriv, spub, t);
		BenchMarkSigning("ECDSA-RFC6979 over GF(2^n) 233", spriv2, t);
		BenchMarkVerification("ECDSA-RFC6979 over GF(2^n) 233", spriv2, spub2, t);
		BenchMarkSigning("ECGDSA over GF(2^n) 233", spriv3, t);
		BenchMarkVerification("ECGDSA over GF(2^n) 233", spriv3, spub3, t);
		BenchMarkKeyGen("ECDHC over GF(2^n) 233", ecdhc, t);
		BenchMarkAgreement("ECDHC over GF(2^n) 233", ecdhc, t);
		BenchMarkKeyGen("ECMQVC over GF(2^n) 233", ecmqvc, t);
		BenchMarkAgreement("ECMQVC over GF(2^n) 233", ecmqvc, t);
	}

	std::cout << "\n</TABLE>" << std::endl;
}

NAMESPACE_END  // Test
NAMESPACE_END  // CryptoPP
