// bench.h - originally written and placed in the public domain by Wei Dai
//           CryptoPP::Test namespace added by JW in February 2017

#ifndef CRYPTOPP_BENCH_H
#define CRYPTOPP_BENCH_H

#include "cryptlib.h"

#include <iostream>
#include <iomanip>
#include <cmath>
#include <ctime>

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(Test)

// More granular control over benchmarks
enum TestClass {
	/// \brief Random number generators
	UnkeyedRNG=(1<<0),
	/// \brief Message digests
	UnkeyedHash=(1<<1),
	/// \brief Other unkeyed algorithms
	UnkeyedOther=(1<<2),

	/// \brief Message authentication codes
	SharedKeyMAC=(1<<3),
	/// \brief Stream ciphers
	SharedKeyStream=(1<<4),
	/// \brief Block ciphers ciphers
	SharedKeyBlock=(1<<5),
	/// \brief Other shared key algorithms
	SharedKeyOther=(1<<6),

	/// \brief Key agreement algorithms over integers
	PublicKeyAgreement=(1<<7),
	/// \brief Encryption algorithms over integers
	PublicKeyEncryption=(1<<8),
	/// \brief Signature algorithms over integers
	PublicKeySignature=(1<<9),
	/// \brief Other public key algorithms over integers
	PublicKeyOther=(1<<10),

	/// \brief Key agreement algorithms over EC
	PublicKeyAgreementEC=(1<<11),
	/// \brief Encryption algorithms over EC
	PublicKeyEncryptionEC=(1<<12),
	/// \brief Signature algorithms over EC
	PublicKeySignatureEC=(1<<13),
	/// \brief Other public key algorithms over EC
	PublicKeyOtherEC=(1<<14),

	Unkeyed=UnkeyedRNG|UnkeyedHash|UnkeyedOther,
	SharedKey=SharedKeyMAC|SharedKeyStream|SharedKeyBlock|SharedKeyOther,
	PublicKey=PublicKeyAgreement|PublicKeyEncryption|PublicKeySignature|PublicKeyOther,
	PublicKeyEC=PublicKeyAgreementEC|PublicKeyEncryptionEC|PublicKeySignatureEC|PublicKeyOtherEC,

	All=Unkeyed|SharedKey|PublicKey|PublicKeyEC,

	TestFirst=(0), TestLast=(1<<15)
};

extern const double CLOCK_TICKS_PER_SECOND;
extern double g_allocatedTime;
extern double g_hertz;
extern double g_logTotal;
extern unsigned int g_logCount;
extern const byte defaultKey[];

// Test book keeping
extern time_t g_testBegin;
extern time_t g_testEnd;

// Benchmark command handler
void BenchmarkWithCommand(int argc, const char* const argv[]);
// Top level, prints preamble and postamble
void Benchmark(Test::TestClass suites, double t, double hertz);
// Unkeyed systems
void BenchmarkUnkeyedAlgorithms(double t, double hertz);
// Shared key systems
void BenchmarkSharedKeyedAlgorithms(double t, double hertz);
// Public key systems over integers
void BenchmarkPublicKeyAlgorithms(double t, double hertz);
// Public key systems over elliptic curves
void BenchmarkEllipticCurveAlgorithms(double t, double hertz);

// These are defined in bench1.cpp
extern void OutputResultKeying(double iterations, double timeTaken);
extern void OutputResultBytes(const char *name, const char *provider, double length, double timeTaken);
extern void OutputResultOperations(const char *name, const char *provider, const char *operation, bool pc, unsigned long iterations, double timeTaken);

// These are defined in bench1.cpp
extern void BenchMark(const char *name, BufferedTransformation &bt, double timeTotal);
extern void BenchMark(const char *name, StreamTransformation &cipher, double timeTotal);
extern void BenchMark(const char *name, HashTransformation &ht, double timeTotal);
extern void BenchMark(const char *name, RandomNumberGenerator &rng, double timeTotal);

// These are defined in bench2.cpp
extern void BenchMarkKeying(SimpleKeyingInterface &c, size_t keyLength, const NameValuePairs &params);
extern void BenchMark(const char *name, AuthenticatedSymmetricCipher &cipher, double timeTotal);

NAMESPACE_END  // Test
NAMESPACE_END  // CryptoPP

#endif
