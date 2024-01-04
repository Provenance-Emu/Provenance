// regtest1.cpp - originally written and placed in the public domain by Wei Dai
//                regtest.cpp split into 3 files due to OOM kills by JW
//                in April 2017. A second split occurred in July 2018.

// Local Changes: Header include path

#define CRYPTOPP_ENABLE_NAMESPACE_WEAK 1

#include "cryptlib.h"
#include "../externals/include/cryptopp/factory.h"
#include "bench.h"
#include "cpu.h"

#include "crc.h"
#include "adler32.h"
#include "md2.h"
#include "md5.h"
#include "keccak.h"
#include "sha3.h"
#include "shake.h"
#include "blake2.h"
#include "sha.h"
#include "sha3.h"
#include "sm3.h"
#include "hkdf.h"
#include "tiger.h"
#include "ripemd.h"
#include "panama.h"
#include "whrlpool.h"
#include "lsh.h"

#include "osrng.h"
#include "drbg.h"
#include "darn.h"
#include "mersenne.h"
#include "rdrand.h"
#include "padlkrng.h"

#include "modes.h"
#include "aes.h"

// Aggressive stack checking with VS2005 SP1 and above.
#if (_MSC_FULL_VER >= 140050727)
# pragma strict_gs_check (on)
#endif

#if CRYPTOPP_MSC_VERSION
# pragma warning(disable: 4505 4355)
#endif

USING_NAMESPACE(CryptoPP)

// Unkeyed ciphers
void RegisterFactories1();
// MAC ciphers
void RegisterFactories2();
// Stream ciphers
void RegisterFactories3();
// Block ciphers
void RegisterFactories4();
// Public key ciphers
void RegisterFactories5();

void RegisterFactories(Test::TestClass suites)
{
	static bool s_registered = false;
	if (s_registered)
		return;

	if ((suites & Test::Unkeyed) == Test::Unkeyed)
		RegisterFactories1();

	if ((suites & Test::SharedKeyMAC) == Test::SharedKeyMAC)
		RegisterFactories2();

	if ((suites & Test::SharedKeyStream) == Test::SharedKeyStream)
		RegisterFactories3();

	if ((suites & Test::SharedKeyBlock) == Test::SharedKeyBlock)
		RegisterFactories4();

	if ((suites & Test::PublicKey) == Test::PublicKey)
		RegisterFactories5();

	s_registered = true;
}

// Unkeyed ciphers
void RegisterFactories1()
{
	RegisterDefaultFactoryFor<HashTransformation, CRC32>();
	RegisterDefaultFactoryFor<HashTransformation, CRC32C>();
	RegisterDefaultFactoryFor<HashTransformation, Adler32>();
	RegisterDefaultFactoryFor<HashTransformation, Weak::MD5>();
	RegisterDefaultFactoryFor<HashTransformation, SHA1>();
	RegisterDefaultFactoryFor<HashTransformation, SHA224>();
	RegisterDefaultFactoryFor<HashTransformation, SHA256>();
	RegisterDefaultFactoryFor<HashTransformation, SHA384>();
	RegisterDefaultFactoryFor<HashTransformation, SHA512>();
	RegisterDefaultFactoryFor<HashTransformation, Whirlpool>();
	RegisterDefaultFactoryFor<HashTransformation, Tiger>();
	RegisterDefaultFactoryFor<HashTransformation, RIPEMD160>();
	RegisterDefaultFactoryFor<HashTransformation, RIPEMD320>();
	RegisterDefaultFactoryFor<HashTransformation, RIPEMD128>();
	RegisterDefaultFactoryFor<HashTransformation, RIPEMD256>();
	RegisterDefaultFactoryFor<HashTransformation, Weak::PanamaHash<LittleEndian> >();
	RegisterDefaultFactoryFor<HashTransformation, Weak::PanamaHash<BigEndian> >();
	RegisterDefaultFactoryFor<HashTransformation, Keccak_224>();
	RegisterDefaultFactoryFor<HashTransformation, Keccak_256>();
	RegisterDefaultFactoryFor<HashTransformation, Keccak_384>();
	RegisterDefaultFactoryFor<HashTransformation, Keccak_512>();
	RegisterDefaultFactoryFor<HashTransformation, SHA3_224>();
	RegisterDefaultFactoryFor<HashTransformation, SHA3_256>();
	RegisterDefaultFactoryFor<HashTransformation, SHA3_384>();
	RegisterDefaultFactoryFor<HashTransformation, SHA3_512>();
	RegisterDefaultFactoryFor<HashTransformation, SHAKE128>();
	RegisterDefaultFactoryFor<HashTransformation, SHAKE256>();
	RegisterDefaultFactoryFor<HashTransformation, SM3>();
	RegisterDefaultFactoryFor<HashTransformation, BLAKE2s>();
	RegisterDefaultFactoryFor<HashTransformation, BLAKE2b>();
	RegisterDefaultFactoryFor<HashTransformation, LSH224>();
	RegisterDefaultFactoryFor<HashTransformation, LSH256>();
	RegisterDefaultFactoryFor<HashTransformation, LSH384>();
	RegisterDefaultFactoryFor<HashTransformation, LSH512>();
	RegisterDefaultFactoryFor<HashTransformation, LSH512_256>();

#ifdef BLOCKING_RNG_AVAILABLE
	RegisterDefaultFactoryFor<RandomNumberGenerator, BlockingRng>();
#endif
#ifdef NONBLOCKING_RNG_AVAILABLE
	RegisterDefaultFactoryFor<RandomNumberGenerator, NonblockingRng>();
#endif
#ifdef OS_RNG_AVAILABLE
	RegisterDefaultFactoryFor<RandomNumberGenerator, AutoSeededRandomPool>();
	RegisterDefaultFactoryFor<RandomNumberGenerator, AutoSeededX917RNG<AES> >();
#endif
	RegisterDefaultFactoryFor<RandomNumberGenerator, MT19937>();
#if (CRYPTOPP_BOOL_X86)
	if (HasPadlockRNG())
		RegisterDefaultFactoryFor<RandomNumberGenerator, PadlockRNG>();
#endif
#if (CRYPTOPP_BOOL_X86 || CRYPTOPP_BOOL_X32 || CRYPTOPP_BOOL_X64)
	if (HasRDRAND())
		RegisterDefaultFactoryFor<RandomNumberGenerator, RDRAND>();
	if (HasRDSEED())
		RegisterDefaultFactoryFor<RandomNumberGenerator, RDSEED>();
#endif
#if (CRYPTOPP_BOOL_PPC32 || CRYPTOPP_BOOL_PPC64)
	if (HasDARN())
		RegisterDefaultFactoryFor<RandomNumberGenerator, DARN>();
#endif
	RegisterDefaultFactoryFor<RandomNumberGenerator, OFB_Mode<AES>::Encryption >("AES/OFB RNG");
	RegisterDefaultFactoryFor<NIST_DRBG, Hash_DRBG<SHA1> >("Hash_DRBG(SHA1)");
	RegisterDefaultFactoryFor<NIST_DRBG, Hash_DRBG<SHA256> >("Hash_DRBG(SHA256)");
	RegisterDefaultFactoryFor<NIST_DRBG, HMAC_DRBG<SHA1> >("HMAC_DRBG(SHA1)");
	RegisterDefaultFactoryFor<NIST_DRBG, HMAC_DRBG<SHA256> >("HMAC_DRBG(SHA256)");

	RegisterDefaultFactoryFor<KeyDerivationFunction, HKDF<SHA1> >();
	RegisterDefaultFactoryFor<KeyDerivationFunction, HKDF<SHA256> >();
	RegisterDefaultFactoryFor<KeyDerivationFunction, HKDF<SHA512> >();
	RegisterDefaultFactoryFor<KeyDerivationFunction, HKDF<Whirlpool> >();
}
