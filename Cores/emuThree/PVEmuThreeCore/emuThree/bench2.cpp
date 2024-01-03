// bench2.cpp - originally written and placed in the public domain by Wei Dai
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

#include "vmac.h"
#include "hmac.h"
#include "ttmac.h"
#include "cmac.h"
#include "dmac.h"

#if CRYPTOPP_MSC_VERSION
# pragma warning(disable: 4355)
#endif

#if CRYPTOPP_MSC_VERSION
# pragma warning(disable: 4505 4355)
#endif

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(Test)

void BenchMarkKeying(SimpleKeyingInterface &c, size_t keyLength, const NameValuePairs &params)
{
	unsigned long iterations = 0;
	double timeTaken;

	clock_t start = ::clock();
	do
	{
		for (unsigned int i=0; i<1024; i++)
			c.SetKey(defaultKey, keyLength, params);
		timeTaken = double(::clock() - start) / CLOCK_TICKS_PER_SECOND;
		iterations += 1024;
	}
	while (timeTaken < g_allocatedTime);

	OutputResultKeying(iterations, timeTaken);
}

void BenchMark(const char *name, AuthenticatedSymmetricCipher &cipher, double timeTotal)
{
	if (cipher.NeedsPrespecifiedDataLengths())
		cipher.SpecifyDataLengths(0, cipher.MaxMessageLength(), 0);

	BenchMark(name, static_cast<StreamTransformation &>(cipher), timeTotal);
}

template <class T_FactoryOutput, class T_Interface>
void BenchMarkByName2(const char *factoryName, size_t keyLength=0, const char *displayName=NULLPTR, const NameValuePairs &params = g_nullNameValuePairs)
{
	std::string name(factoryName ? factoryName : "");
	member_ptr<T_FactoryOutput> obj(ObjectFactoryRegistry<T_FactoryOutput>::Registry().CreateObject(name.c_str()));

	if (keyLength == 0)
		keyLength = obj->DefaultKeyLength();

	if (displayName != NULLPTR)
		name = displayName;
	else if (keyLength != 0)
		name += " (" + IntToString(keyLength * 8) + "-bit key)";

	obj->SetKey(defaultKey, keyLength, CombinedNameValuePairs(params, MakeParameters(Name::IV(), ConstByteArrayParameter(defaultKey, obj->IVSize()), false)));
	BenchMark(name.c_str(), *static_cast<T_Interface *>(obj.get()), g_allocatedTime);
	BenchMarkKeying(*obj, keyLength, CombinedNameValuePairs(params, MakeParameters(Name::IV(), ConstByteArrayParameter(defaultKey, obj->IVSize()), false)));
}

template <class T_FactoryOutput>
void BenchMarkByName(const char *factoryName, size_t keyLength=0, const char *displayName=NULLPTR, const NameValuePairs &params = g_nullNameValuePairs)
{
	BenchMarkByName2<T_FactoryOutput,T_FactoryOutput>(factoryName, keyLength, displayName, params);
}

void BenchmarkSharedKeyedAlgorithms(double t, double hertz)
{
	g_allocatedTime = t;
	g_hertz = hertz;

	const char *cpb, *cpk;
	if (g_hertz > 1.0f)
	{
		cpb = "<TH>Cycles/Byte";
		cpk = "<TH>Cycles to<BR>Setup Key and IV";
	}
	else
	{
		cpb = cpk = "";
	}

	std::cout << "\n<TABLE>";
	std::cout << "\n<COLGROUP><COL style=\"text-align: left;\"><COL style=\"text-align: right;\"><COL style=";
	std::cout << "\"text-align: right;\"><COL style=\"text-align: right;\"><COL style=\"text-align: right;\">";
	std::cout << "\n<THEAD style=\"background: #F0F0F0\">";
	std::cout << "\n<TR><TH>Algorithm<TH>Provider<TH>MiB/Second" << cpb;
	std::cout << "<TH>Microseconds to<BR>Setup Key and IV" << cpk;

	std::cout << "\n<TBODY style=\"background: white;\">";
	{
#if CRYPTOPP_AESNI_AVAILABLE
		if (HasCLMUL())
			BenchMarkByName2<AuthenticatedSymmetricCipher, MessageAuthenticationCode>("AES/GCM", 0, "GMAC(AES)");
		else
#elif CRYPTOPP_ARM_PMULL_AVAILABLE
		if (HasPMULL())
			BenchMarkByName2<AuthenticatedSymmetricCipher, MessageAuthenticationCode>("AES/GCM", 0, "GMAC(AES)");
		else
#elif CRYPTOPP_POWER8_VMULL_AVAILABLE
		if (HasPMULL())
			BenchMarkByName2<AuthenticatedSymmetricCipher, MessageAuthenticationCode>("AES/GCM", 0, "GMAC(AES)");
		else
#endif
		{
			BenchMarkByName2<AuthenticatedSymmetricCipher, MessageAuthenticationCode>("AES/GCM", 0, "GMAC(AES) (2K tables)", MakeParameters(Name::TableSize(), 2048));
			BenchMarkByName2<AuthenticatedSymmetricCipher, MessageAuthenticationCode>("AES/GCM", 0, "GMAC(AES) (64K tables)", MakeParameters(Name::TableSize(), 64 * 1024));
		}

		BenchMarkByName<MessageAuthenticationCode>("VMAC(AES)-64");
		BenchMarkByName<MessageAuthenticationCode>("VMAC(AES)-128");
		BenchMarkByName<MessageAuthenticationCode>("HMAC(SHA-1)");
		BenchMarkByName<MessageAuthenticationCode>("HMAC(SHA-256)");
		BenchMarkByName<MessageAuthenticationCode>("Two-Track-MAC");
		BenchMarkByName<MessageAuthenticationCode>("CMAC(AES)");
		BenchMarkByName<MessageAuthenticationCode>("DMAC(AES)");
		BenchMarkByName<MessageAuthenticationCode>("Poly1305(AES)");
		BenchMarkByName<MessageAuthenticationCode>("Poly1305TLS");
		BenchMarkByName<MessageAuthenticationCode>("BLAKE2s");
		BenchMarkByName<MessageAuthenticationCode>("BLAKE2b");
		BenchMarkByName<MessageAuthenticationCode>("SipHash-2-4");
		BenchMarkByName<MessageAuthenticationCode>("SipHash-4-8");
	}

	std::cout << "\n<TBODY style=\"background: yellow;\">";
	{
		BenchMarkByName<SymmetricCipher>("Panama-LE");
		BenchMarkByName<SymmetricCipher>("Panama-BE");
		BenchMarkByName<SymmetricCipher>("Salsa20", 0, "Salsa20");
		BenchMarkByName<SymmetricCipher>("Salsa20", 0, "Salsa20/12", MakeParameters(Name::Rounds(), 12));
		BenchMarkByName<SymmetricCipher>("Salsa20", 0, "Salsa20/8", MakeParameters(Name::Rounds(), 8));
		BenchMarkByName<SymmetricCipher>("ChaCha", 0, "ChaCha20");
		BenchMarkByName<SymmetricCipher>("ChaCha", 0, "ChaCha12", MakeParameters(Name::Rounds(), 12));
		BenchMarkByName<SymmetricCipher>("ChaCha", 0, "ChaCha8", MakeParameters(Name::Rounds(), 8));
		BenchMarkByName<SymmetricCipher>("ChaChaTLS");
		BenchMarkByName<SymmetricCipher>("Sosemanuk");
		BenchMarkByName<SymmetricCipher>("Rabbit");
		BenchMarkByName<SymmetricCipher>("RabbitWithIV");
		BenchMarkByName<SymmetricCipher>("HC-128");
		BenchMarkByName<SymmetricCipher>("HC-256");
		BenchMarkByName<SymmetricCipher>("MARC4");
		BenchMarkByName<SymmetricCipher>("SEAL-3.0-LE");
		BenchMarkByName<SymmetricCipher>("WAKE-OFB-LE");
	}

	std::cout << "\n<TBODY style=\"background: white;\">";
	{
		BenchMarkByName<SymmetricCipher>("AES/CTR", 16);
		BenchMarkByName<SymmetricCipher>("AES/CTR", 24);
		BenchMarkByName<SymmetricCipher>("AES/CTR", 32);
		BenchMarkByName<SymmetricCipher>("AES/CBC", 16);
		BenchMarkByName<SymmetricCipher>("AES/CBC", 24);
		BenchMarkByName<SymmetricCipher>("AES/CBC", 32);
		BenchMarkByName<SymmetricCipher>("AES/XTS", 32);
		BenchMarkByName<SymmetricCipher>("AES/XTS", 48);
		BenchMarkByName<SymmetricCipher>("AES/XTS", 64);
		BenchMarkByName<SymmetricCipher>("AES/OFB", 16);
		BenchMarkByName<SymmetricCipher>("AES/CFB", 16);
		BenchMarkByName<SymmetricCipher>("AES/ECB", 16);
		BenchMarkByName<SymmetricCipher>("ARIA/CTR", 16);
		BenchMarkByName<SymmetricCipher>("ARIA/CTR", 32);
		BenchMarkByName<SymmetricCipher>("HIGHT/CTR");
		BenchMarkByName<SymmetricCipher>("Camellia/CTR", 16);
		BenchMarkByName<SymmetricCipher>("Camellia/CTR", 32);
		BenchMarkByName<SymmetricCipher>("Twofish/CTR");
		BenchMarkByName<SymmetricCipher>("Threefish-256(256)/CTR", 32);
		BenchMarkByName<SymmetricCipher>("Threefish-512(512)/CTR", 64);
		BenchMarkByName<SymmetricCipher>("Threefish-1024(1024)/CTR", 128);
		BenchMarkByName<SymmetricCipher>("Serpent/CTR");
		BenchMarkByName<SymmetricCipher>("CAST-128/CTR");
		BenchMarkByName<SymmetricCipher>("CAST-256/CTR", 32);
		BenchMarkByName<SymmetricCipher>("RC6/CTR");
		BenchMarkByName<SymmetricCipher>("MARS/CTR");
		BenchMarkByName<SymmetricCipher>("SHACAL-2/CTR", 16);
		BenchMarkByName<SymmetricCipher>("SHACAL-2/CTR", 64);
		BenchMarkByName<SymmetricCipher>("DES/CTR");
		BenchMarkByName<SymmetricCipher>("DES-XEX3/CTR");
		BenchMarkByName<SymmetricCipher>("DES-EDE3/CTR");
		BenchMarkByName<SymmetricCipher>("IDEA/CTR");
		BenchMarkByName<SymmetricCipher>("RC5/CTR", 0, "RC5 (r=16)");
		BenchMarkByName<SymmetricCipher>("Blowfish/CTR");
		BenchMarkByName<SymmetricCipher>("SKIPJACK/CTR");
		BenchMarkByName<SymmetricCipher>("SEED/CTR", 0, "SEED/CTR (1/2 K table)");
		BenchMarkByName<SymmetricCipher>("SM4/CTR");

		BenchMarkByName<SymmetricCipher>("Kalyna-128/CTR", 16, "Kalyna-128(128)/CTR (128-bit key)");
		BenchMarkByName<SymmetricCipher>("Kalyna-128/CTR", 32, "Kalyna-128(256)/CTR (256-bit key)");
		BenchMarkByName<SymmetricCipher>("Kalyna-256/CTR", 32, "Kalyna-256(256)/CTR (256-bit key)");
		BenchMarkByName<SymmetricCipher>("Kalyna-256/CTR", 64, "Kalyna-256(512)/CTR (512-bit key)");
		BenchMarkByName<SymmetricCipher>("Kalyna-512/CTR", 64, "Kalyna-512(512)/CTR (512-bit key)");
	}

	std::cout << "\n<TBODY style=\"background: yellow;\">";
	{
		BenchMarkByName<SymmetricCipher>("CHAM-64/CTR", 16, "CHAM-64(128)/CTR (128-bit key)");
		BenchMarkByName<SymmetricCipher>("CHAM-128/CTR", 16, "CHAM-128(128)/CTR (128-bit key)");
		BenchMarkByName<SymmetricCipher>("CHAM-128/CTR", 32, "CHAM-128(256)/CTR (256-bit key)");

		BenchMarkByName<SymmetricCipher>("LEA-128/CTR", 16, "LEA-128(128)/CTR (128-bit key)");
		BenchMarkByName<SymmetricCipher>("LEA-128/CTR", 24, "LEA-128(192)/CTR (192-bit key)");
		BenchMarkByName<SymmetricCipher>("LEA-128/CTR", 32, "LEA-128(256)/CTR (256-bit key)");

		BenchMarkByName<SymmetricCipher>("SIMECK-32/CTR", 8, "SIMECK-32(64)/CTR (64-bit key)");
		BenchMarkByName<SymmetricCipher>("SIMECK-64/CTR", 16, "SIMECK-64(128)/CTR (128-bit key)");

		BenchMarkByName<SymmetricCipher>("SIMON-64/CTR", 12, "SIMON-64(96)/CTR (96-bit key)");
		BenchMarkByName<SymmetricCipher>("SIMON-64/CTR", 16, "SIMON-64(128)/CTR (128-bit key)");
		BenchMarkByName<SymmetricCipher>("SIMON-128/CTR", 16, "SIMON-128(128)/CTR (128-bit key)");
		BenchMarkByName<SymmetricCipher>("SIMON-128/CTR", 24, "SIMON-128(192)/CTR (192-bit key)");
		BenchMarkByName<SymmetricCipher>("SIMON-128/CTR", 32, "SIMON-128(256)/CTR (256-bit key)");

		BenchMarkByName<SymmetricCipher>("SPECK-64/CTR", 12, "SPECK-64(96)/CTR (96-bit key)");
		BenchMarkByName<SymmetricCipher>("SPECK-64/CTR", 16, "SPECK-64(128)/CTR (128-bit key)");
		BenchMarkByName<SymmetricCipher>("SPECK-128/CTR", 16, "SPECK-128(128)/CTR (128-bit key)");
		BenchMarkByName<SymmetricCipher>("SPECK-128/CTR", 24, "SPECK-128(192)/CTR (192-bit key)");
		BenchMarkByName<SymmetricCipher>("SPECK-128/CTR", 32, "SPECK-128(256)/CTR (256-bit key)");

		BenchMarkByName<SymmetricCipher>("TEA/CTR");
		BenchMarkByName<SymmetricCipher>("XTEA/CTR");
	}

	std::cout << "\n<TBODY style=\"background: white;\">";
	{
#if CRYPTOPP_AESNI_AVAILABLE
		if (HasCLMUL())
			BenchMarkByName2<AuthenticatedSymmetricCipher, AuthenticatedSymmetricCipher>("AES/GCM", 0, "AES/GCM");
		else
#elif CRYPTOPP_ARM_PMULL_AVAILABLE
		if (HasPMULL())
			BenchMarkByName2<AuthenticatedSymmetricCipher, AuthenticatedSymmetricCipher>("AES/GCM", 0, "AES/GCM");
		else
#elif CRYPTOPP_POWER8_VMULL_AVAILABLE
		if (HasPMULL())
			BenchMarkByName2<AuthenticatedSymmetricCipher, AuthenticatedSymmetricCipher>("AES/GCM", 0, "AES/GCM");
		else
#endif
		{
			BenchMarkByName2<AuthenticatedSymmetricCipher, AuthenticatedSymmetricCipher>("AES/GCM", 0, "AES/GCM (2K tables)", MakeParameters(Name::TableSize(), 2048));
			BenchMarkByName2<AuthenticatedSymmetricCipher, AuthenticatedSymmetricCipher>("AES/GCM", 0, "AES/GCM (64K tables)", MakeParameters(Name::TableSize(), 64 * 1024));
		}
		BenchMarkByName2<AuthenticatedSymmetricCipher, AuthenticatedSymmetricCipher>("AES/CCM");
		BenchMarkByName2<AuthenticatedSymmetricCipher, AuthenticatedSymmetricCipher>("AES/EAX");
		BenchMarkByName2<AuthenticatedSymmetricCipher, AuthenticatedSymmetricCipher>("ChaCha20/Poly1305");
		BenchMarkByName2<AuthenticatedSymmetricCipher, AuthenticatedSymmetricCipher>("XChaCha20/Poly1305");
	}

	std::cout << "\n</TABLE>" << std::endl;
}

NAMESPACE_END  // Test
NAMESPACE_END  // CryptoPP
