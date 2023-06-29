// bench1.cpp - originally written and placed in the public domain by Wei Dai
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

#include "osrng.h"
#include "drbg.h"
#include "darn.h"
#include "mersenne.h"
#include "rdrand.h"
#include "padlkrng.h"

#include <iostream>
#include <iomanip>
#include <sstream>

#if CRYPTOPP_MSC_VERSION
# pragma warning(disable: 4355)
#endif

#if CRYPTOPP_MSC_VERSION
# pragma warning(disable: 4505 4355)
#endif

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(Test)

#ifdef CLOCKS_PER_SEC
const double CLOCK_TICKS_PER_SECOND = (double)CLOCKS_PER_SEC;
#elif defined(CLK_TCK)
const double CLOCK_TICKS_PER_SECOND = (double)CLK_TCK;
#else
const double CLOCK_TICKS_PER_SECOND = 1000000.0;
#endif

extern const byte defaultKey[] = "0123456789" // 168 + NULL
	"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	"00000000000000000000000000000000000000000000000000000"
	"00000000000000000000000000000000000000000000000000000";

double g_allocatedTime = 0.0, g_hertz = 0.0, g_logTotal = 0.0;
unsigned int g_logCount = 0;
time_t g_testBegin, g_testEnd;

inline std::string HertzToString(double hertz)
{
	std::ostringstream oss;
	oss.precision(3);

	if (hertz >= 0.999e+9)
		oss << hertz / 1e+9 << " GHz";
	else if (hertz >= 0.999e+6)
		oss << hertz / 1e+6 << " MHz";
	else if (hertz >= 0.999e+3)
		oss << hertz / 1e+3 << " KHz";
	else
		oss << hertz << " Hz";

	return oss.str();
}

void OutputResultBytes(const char *name, const char *provider, double length, double timeTaken)
{
	std::ostringstream oss;

	// Coverity finding
	if (length < 0.000001f) length = 0.000001f;
	if (timeTaken < 0.000001f) timeTaken = 0.000001f;

	double mbs = length / timeTaken / (1024*1024);
	oss << "\n<TR><TD>" << name << "<TD>" << provider;
	oss << std::setiosflags(std::ios::fixed);
	oss << "<TD>" << std::setprecision(0) << std::setiosflags(std::ios::fixed) << mbs;
	if (g_hertz > 1.0f)
	{
		const double cpb = timeTaken * g_hertz / length;
		if (cpb < 24.0f)
			oss << "<TD>" << std::setprecision(2) << std::setiosflags(std::ios::fixed) << cpb;
		else
			oss << "<TD>" << std::setprecision(1) << std::setiosflags(std::ios::fixed) << cpb;
	}
	g_logTotal += log(mbs);
	g_logCount++;

	std::cout << oss.str();
}

void OutputResultKeying(double iterations, double timeTaken)
{
	std::ostringstream oss;

	// Coverity finding
	if (iterations < 0.000001f) iterations = 0.000001f;
	if (timeTaken < 0.000001f) timeTaken = 0.000001f;

	oss << "<TD>" << std::setprecision(3) << std::setiosflags(std::ios::fixed) << (1000*1000*timeTaken/iterations);

	// Coverity finding
	if (g_hertz > 1.0f)
		oss << "<TD>" << std::setprecision(0) << std::setiosflags(std::ios::fixed) << timeTaken * g_hertz / iterations;

	std::cout << oss.str();
}

void OutputResultOperations(const char *name, const char *provider, const char *operation, bool pc, unsigned long iterations, double timeTaken)
{
	CRYPTOPP_UNUSED(provider);
	std::ostringstream oss;

	// Coverity finding
	if (!iterations) iterations++;
	if (timeTaken < 0.000001f) timeTaken = 0.000001f;

	oss << "\n<TR><TD>" << name << " " << operation << (pc ? " with precomputation" : "");
	//oss << "<TD>" << provider;
	oss << "<TD>" << std::setprecision(3) << std::setiosflags(std::ios::fixed) << (1000*timeTaken/iterations);

	// Coverity finding
	if (g_hertz > 1.0f)
	{
		const double t = timeTaken * g_hertz / iterations / 1000000;
		oss << "<TD>" << std::setprecision(3) << std::setiosflags(std::ios::fixed) << t;
	}

	g_logTotal += log(iterations/timeTaken);
	g_logCount++;

	std::cout << oss.str();
}

/*
void BenchMark(const char *name, BlockTransformation &cipher, double timeTotal)
{
	const int BUF_SIZE = RoundUpToMultipleOf(2048U, cipher.OptimalNumberOfParallelBlocks() * cipher.BlockSize());
	AlignedSecByteBlock buf(BUF_SIZE);
	buf.SetMark(16);

	const int nBlocks = BUF_SIZE / cipher.BlockSize();
	unsigned long i=0, blocks=1;
	double timeTaken;

	clock_t start = ::clock();
	do
	{
		blocks *= 2;
		for (; i<blocks; i++)
			cipher.ProcessAndXorMultipleBlocks(buf, NULLPTR, buf, nBlocks);
		timeTaken = double(::clock() - start) / CLOCK_TICKS_PER_SECOND;
	}
	while (timeTaken < 2.0/3*timeTotal);

	OutputResultBytes(name, double(blocks) * BUF_SIZE, timeTaken);
}
*/

void BenchMark(const char *name, StreamTransformation &cipher, double timeTotal)
{
	const int BUF_SIZE=RoundUpToMultipleOf(2048U, cipher.OptimalBlockSize());
	AlignedSecByteBlock buf(BUF_SIZE);
	Test::GlobalRNG().GenerateBlock(buf, BUF_SIZE);
	buf.SetMark(16);

	unsigned long i=0, blocks=1;
	double timeTaken;

	clock_t start = ::clock();
	do
	{
		blocks *= 2;
		for (; i<blocks; i++)
			cipher.ProcessString(buf, BUF_SIZE);
		timeTaken = double(::clock() - start) / CLOCK_TICKS_PER_SECOND;
	}
	while (timeTaken < 2.0/3*timeTotal);

	std::string provider = cipher.AlgorithmProvider();
	OutputResultBytes(name, provider.c_str(), double(blocks) * BUF_SIZE, timeTaken);
}

void BenchMark(const char *name, HashTransformation &ht, double timeTotal)
{
	const int BUF_SIZE=2048U;
	AlignedSecByteBlock buf(BUF_SIZE);
	Test::GlobalRNG().GenerateBlock(buf, BUF_SIZE);
	buf.SetMark(16);

	unsigned long i=0, blocks=1;
	double timeTaken;

	clock_t start = ::clock();
	do
	{
		blocks *= 2;
		for (; i<blocks; i++)
			ht.Update(buf, BUF_SIZE);
		timeTaken = double(::clock() - start) / CLOCK_TICKS_PER_SECOND;
	}
	while (timeTaken < 2.0/3*timeTotal);

	std::string provider = ht.AlgorithmProvider();
	OutputResultBytes(name, provider.c_str(), double(blocks) * BUF_SIZE, timeTaken);
}

void BenchMark(const char *name, BufferedTransformation &bt, double timeTotal)
{
	const int BUF_SIZE=2048U;
	AlignedSecByteBlock buf(BUF_SIZE);
	Test::GlobalRNG().GenerateBlock(buf, BUF_SIZE);
	buf.SetMark(16);

	unsigned long i=0, blocks=1;
	double timeTaken;

	clock_t start = ::clock();
	do
	{
		blocks *= 2;
		for (; i<blocks; i++)
			bt.Put(buf, BUF_SIZE);
		timeTaken = double(::clock() - start) / CLOCK_TICKS_PER_SECOND;
	}
	while (timeTaken < 2.0/3*timeTotal);

	std::string provider = bt.AlgorithmProvider();
	OutputResultBytes(name, provider.c_str(), double(blocks) * BUF_SIZE, timeTaken);
}

void BenchMark(const char *name, RandomNumberGenerator &rng, double timeTotal)
{
	const int BUF_SIZE = 2048U;
	AlignedSecByteBlock buf(BUF_SIZE);
	Test::GlobalRNG().GenerateBlock(buf, BUF_SIZE);
	buf.SetMark(16);

	SymmetricCipher * cipher = dynamic_cast<SymmetricCipher*>(&rng);
	if (cipher != NULLPTR)
	{
		const size_t size = cipher->DefaultKeyLength();
		if (cipher->IsResynchronizable())
			cipher->SetKeyWithIV(buf, size, buf+size);
		else
			cipher->SetKey(buf, size);
	}

	unsigned long long blocks = 1;
	double timeTaken;

	clock_t start = ::clock();
	do
	{
		rng.GenerateBlock(buf, buf.size());
		blocks++;
		timeTaken = double(::clock() - start) / CLOCK_TICKS_PER_SECOND;
	} while (timeTaken < timeTotal);

	std::string provider = rng.AlgorithmProvider();
	OutputResultBytes(name, provider.c_str(), double(blocks) * BUF_SIZE, timeTaken);
}

// Hack, but we probably need a KeyedRandomNumberGenerator interface
//  and a few methods to generalize keying a RNG. X917RNG, Hash_DRBG,
//  HMAC_DRBG, AES/CFB RNG and a few others could use it. "A few others"
//  includes BLAKE2, ChaCha and Poly1305 when used as a RNG.
void BenchMark(const char *name, NIST_DRBG &rng, double timeTotal)
{
	const int BUF_SIZE = 2048U;
	AlignedSecByteBlock buf(BUF_SIZE);
	Test::GlobalRNG().GenerateBlock(buf, BUF_SIZE);
	buf.SetMark(16);

	rng.IncorporateEntropy(buf, rng.MinEntropyLength());
	unsigned long long blocks = 1;
	double timeTaken;

	clock_t start = ::clock();
	do
	{
		rng.GenerateBlock(buf, buf.size());
		blocks++;
		timeTaken = double(::clock() - start) / CLOCK_TICKS_PER_SECOND;
	} while (timeTaken < timeTotal);

	std::string provider = rng.AlgorithmProvider();
	OutputResultBytes(name, provider.c_str(), double(blocks) * BUF_SIZE, timeTaken);
}

template <class T>
void BenchMarkByNameKeyLess(const char *factoryName, const char *displayName = NULLPTR, const NameValuePairs &params = g_nullNameValuePairs)
{
	CRYPTOPP_UNUSED(params);
	std::string name = factoryName;
	if (displayName)
		name = displayName;

	member_ptr<T> obj(ObjectFactoryRegistry<T>::Registry().CreateObject(factoryName));
	BenchMark(name.c_str(), *obj, g_allocatedTime);
}

void AddHtmlHeader()
{
	std::ostringstream oss;

	// HTML5
	oss << "<!DOCTYPE HTML>";
	oss << "\n<HTML lang=\"en\">";

	oss << "\n<HEAD>";
	oss << "\n<META charset=\"UTF-8\">";
	oss << "\n<TITLE>Speed Comparison of Popular Crypto Algorithms</TITLE>";
	oss << "\n<STYLE>\n  table {border-collapse: collapse;}";
	oss << "\n  table, th, td, tr {border: 1px solid black;}\n</STYLE>";
	oss << "\n</HEAD>";

	oss << "\n<BODY>";

	oss << "\n<H1><A href=\"http://www.cryptopp.com\">Crypto++ " << CRYPTOPP_VERSION / 100;
	oss << '.' << (CRYPTOPP_VERSION % 100) / 10 << '.' << CRYPTOPP_VERSION % 10 << "</A> Benchmarks</H1>";

	oss << "\n<P>Here are speed benchmarks for some commonly used cryptographic algorithms.</P>";

	if (g_hertz > 1.0f)
		oss << "\n<P>CPU frequency of the test platform is " << HertzToString(g_hertz) << ".</P>";
	else
		oss << "\n<P>CPU frequency of the test platform was not provided.</P>" << std::endl;

	std::cout << oss.str();
}

void AddHtmlFooter()
{
	std::ostringstream oss;
	oss << "\n</BODY>\n</HTML>\n";
	std::cout << oss.str();
}

void BenchmarkWithCommand(int argc, const char* const argv[])
{
	std::string command(argv[1]);
	float runningTime(argc >= 3 ? Test::StringToValue<float, true>(argv[2]) : 1.0f);
	float cpuFreq(argc >= 4 ? Test::StringToValue<float, true>(argv[3])*float(1e9) : 0.0f);
	std::string algoName(argc >= 5 ? argv[4] : "");

	// https://github.com/weidai11/cryptopp/issues/983
	if (runningTime > 10.0f)
		runningTime = 10.0f;

	if (command == "b")  // All benchmarks
		Benchmark(Test::All, runningTime, cpuFreq);
	else if (command == "b4")  // Public key algorithms over EC
		Test::Benchmark(Test::PublicKeyEC, runningTime, cpuFreq);
	else if (command == "b3")  // Public key algorithms
		Test::Benchmark(Test::PublicKey, runningTime, cpuFreq);
	else if (command == "b2")  // Shared key algorithms
		Test::Benchmark(Test::SharedKey, runningTime, cpuFreq);
	else if (command == "b1")  // Unkeyed algorithms
		Test::Benchmark(Test::Unkeyed, runningTime, cpuFreq);
}

void Benchmark(Test::TestClass suites, double t, double hertz)
{
	g_allocatedTime = t;
	g_hertz = hertz;

	// Add <br> in between tables
	size_t count_breaks = 0;

	AddHtmlHeader();

	g_testBegin = ::time(NULLPTR);

	if (static_cast<int>(suites) == 0 || static_cast<int>(suites) > TestLast)
		suites = Test::All;

	// Unkeyed algorithms
	if (suites & Test::Unkeyed)
	{
		if (count_breaks)
			std::cout << "\n<BR>";
		count_breaks++;

		BenchmarkUnkeyedAlgorithms(t, hertz);
	}

	// Shared key algorithms
	if (suites & Test::SharedKey)
	{
		if (count_breaks)
			std::cout << "\n<BR>";
		count_breaks++;

		BenchmarkSharedKeyedAlgorithms(t, hertz);
	}

	// Public key algorithms
	if (suites & Test::PublicKey)
	{
		if (count_breaks)
			std::cout << "\n<BR>";
		count_breaks++;

		BenchmarkPublicKeyAlgorithms(t, hertz);
	}

	// Public key algorithms over EC
	if (suites & Test::PublicKeyEC)
	{
		if (count_breaks)
			std::cout << "\n<BR>";
		count_breaks++;

		BenchmarkEllipticCurveAlgorithms(t, hertz);
	}

	g_testEnd = ::time(NULLPTR);

	std::ostringstream oss;
	oss << "\n<P>Throughput Geometric Average: " << std::setiosflags(std::ios::fixed);
	oss << std::exp(g_logTotal/(g_logCount > 0.0f ? g_logCount : 1.0f)) << std::endl;

	oss << "\n<P>Test started at " << TimeToString(g_testBegin);
	oss << "\n<BR>Test ended at " << TimeToString(g_testEnd);
	oss << "\n";
	std::cout << oss.str();

	AddHtmlFooter();
}

void BenchmarkUnkeyedAlgorithms(double t, double hertz)
{
	g_allocatedTime = t;
	g_hertz = hertz;

	const char *cpb;
	if (g_hertz > 1.0f)
		cpb = "<TH>Cycles/Byte";
	else
		cpb = "";

	std::cout << "\n<TABLE>";

	std::cout << "\n<COLGROUP><COL style=\"text-align: left;\"><COL style=\"text-align: right;\">";
	std::cout << "<COL style=\"text-align: right;\">";
	std::cout << "\n<THEAD style=\"background: #F0F0F0\">";
	std::cout << "\n<TR><TH>Algorithm<TH>Provider<TH>MiB/Second" << cpb;

	std::cout << "\n<TBODY style=\"background: white;\">";
	{
#ifdef NONBLOCKING_RNG_AVAILABLE
		BenchMarkByNameKeyLess<RandomNumberGenerator>("NonblockingRng");
#endif
#ifdef OS_RNG_AVAILABLE
		BenchMarkByNameKeyLess<RandomNumberGenerator>("AutoSeededRandomPool");
		BenchMarkByNameKeyLess<RandomNumberGenerator>("AutoSeededX917RNG(AES)");
#endif
		BenchMarkByNameKeyLess<RandomNumberGenerator>("MT19937");
#if (CRYPTOPP_BOOL_X86) && !defined(CRYPTOPP_DISABLE_ASM)
		if (HasPadlockRNG())
			BenchMarkByNameKeyLess<RandomNumberGenerator>("PadlockRNG");
#endif
#if (CRYPTOPP_BOOL_X86 || CRYPTOPP_BOOL_X32 || CRYPTOPP_BOOL_X64) && !defined(CRYPTOPP_DISABLE_ASM)
		if (HasRDRAND())
			BenchMarkByNameKeyLess<RandomNumberGenerator>("RDRAND");
		if (HasRDSEED())
			BenchMarkByNameKeyLess<RandomNumberGenerator>("RDSEED");
#endif
#if (CRYPTOPP_BOOL_PPC32 || CRYPTOPP_BOOL_PPC64) && !defined(CRYPTOPP_DISABLE_ASM)
		if (HasDARN())
			BenchMarkByNameKeyLess<RandomNumberGenerator>("DARN");
#endif
		BenchMarkByNameKeyLess<RandomNumberGenerator>("AES/OFB RNG");
		BenchMarkByNameKeyLess<NIST_DRBG>("Hash_DRBG(SHA1)");
		BenchMarkByNameKeyLess<NIST_DRBG>("Hash_DRBG(SHA256)");
		BenchMarkByNameKeyLess<NIST_DRBG>("HMAC_DRBG(SHA1)");
		BenchMarkByNameKeyLess<NIST_DRBG>("HMAC_DRBG(SHA256)");
	}

	std::cout << "\n<TBODY style=\"background: yellow;\">";
	{
		BenchMarkByNameKeyLess<HashTransformation>("CRC32");
		BenchMarkByNameKeyLess<HashTransformation>("CRC32C");
		BenchMarkByNameKeyLess<HashTransformation>("Adler32");
		BenchMarkByNameKeyLess<HashTransformation>("MD5");
		BenchMarkByNameKeyLess<HashTransformation>("SHA-1");
		BenchMarkByNameKeyLess<HashTransformation>("SHA-256");
		BenchMarkByNameKeyLess<HashTransformation>("SHA-512");
		BenchMarkByNameKeyLess<HashTransformation>("SHA3-224");
		BenchMarkByNameKeyLess<HashTransformation>("SHA3-256");
		BenchMarkByNameKeyLess<HashTransformation>("SHA3-384");
		BenchMarkByNameKeyLess<HashTransformation>("SHA3-512");
		BenchMarkByNameKeyLess<HashTransformation>("Keccak-224");
		BenchMarkByNameKeyLess<HashTransformation>("Keccak-256");
		BenchMarkByNameKeyLess<HashTransformation>("Keccak-384");
		BenchMarkByNameKeyLess<HashTransformation>("Keccak-512");
		BenchMarkByNameKeyLess<HashTransformation>("Tiger");
		BenchMarkByNameKeyLess<HashTransformation>("Whirlpool");
		BenchMarkByNameKeyLess<HashTransformation>("RIPEMD-160");
		BenchMarkByNameKeyLess<HashTransformation>("RIPEMD-320");
		BenchMarkByNameKeyLess<HashTransformation>("RIPEMD-128");
		BenchMarkByNameKeyLess<HashTransformation>("RIPEMD-256");
		BenchMarkByNameKeyLess<HashTransformation>("SM3");
		BenchMarkByNameKeyLess<HashTransformation>("BLAKE2s");
		BenchMarkByNameKeyLess<HashTransformation>("BLAKE2b");
		BenchMarkByNameKeyLess<HashTransformation>("LSH-256");
		BenchMarkByNameKeyLess<HashTransformation>("LSH-512");
	}

	std::cout << "\n</TABLE>" << std::endl;
}

NAMESPACE_END  // Test
NAMESPACE_END  // CryptoPP
