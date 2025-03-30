// validate.h - originally written and placed in the public domain by Wei Dai
//              CryptoPP::Test namespace added by JW in February 2017

#ifndef CRYPTOPP_VALIDATE_H
#define CRYPTOPP_VALIDATE_H

#include "cryptlib.h"
#include "misc.h"
#include "files.h"
#include "argnames.h"
#include "algparam.h"
#include "hex.h"

#include <iostream>
#include <sstream>
#include <iomanip>
#include <ctime>
#include <cctype>

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(Test)

// A hint to help locate TestData/ and TestVectors/ after install. Due to
// execve the path can be malicious. If the path is ficticous then we move
// onto the next potential path. Also note we only read from the path; we
// never write through it. Storage for the string is in test.cpp.
extern std::string g_argvPathHint;

bool ValidateAll(bool thorough);
bool TestSettings();
bool TestOS_RNG();
// bool TestSecRandom();
bool TestRandomPool();
#if !defined(NO_OS_DEPENDENCE)
bool TestAutoSeededX917();
#endif
#if (CRYPTOPP_BOOL_X86 || CRYPTOPP_BOOL_X32 || CRYPTOPP_BOOL_X64)
bool TestRDRAND();
bool TestRDSEED();
bool TestPadlockRNG();
#endif
#if (CRYPTOPP_BOOL_PPC32 || CRYPTOPP_BOOL_PPC64)
bool TestDARN();
#endif
bool ValidateBaseCode();
bool ValidateEncoder();
bool ValidateCRC32();
bool ValidateCRC32C();
bool ValidateAdler32();
bool ValidateMD2();
bool ValidateMD4();
bool ValidateMD5();
bool ValidateSHA();
bool ValidateSHA2();
bool ValidateSHA3();
bool ValidateSHAKE();      // output <= r, where r is blocksize
bool ValidateSHAKE_XOF();  // output > r, needs hand crafted tests
bool ValidateKeccak();
bool ValidateTiger();
bool ValidateRIPEMD();
bool ValidatePanama();
bool ValidateWhirlpool();
bool ValidateLSH();

bool ValidateSM3();
bool ValidateBLAKE2s();
bool ValidateBLAKE2b();
bool ValidatePoly1305();
bool ValidateSipHash();

bool ValidateHMAC();
bool ValidateTTMAC();

bool ValidateCipherModes();
bool ValidatePBKDF();
bool ValidateHKDF();
bool ValidateScrypt();

bool ValidateDES();
bool ValidateIDEA();
bool ValidateSAFER();
bool ValidateRC2();
bool ValidateARC4();

bool ValidateRC5();
bool ValidateBlowfish();
bool ValidateBlowfishCompat();
bool ValidateThreeWay();
bool ValidateGOST();
bool ValidateSHARK();
bool ValidateSEAL();
bool ValidateCAST();
bool ValidateSquare();
bool ValidateSKIPJACK();
bool ValidateRC6();
bool ValidateMARS();
bool ValidateRijndael();
bool ValidateTwofish();
bool ValidateSerpent();
bool ValidateSHACAL2();
bool ValidateARIA();
bool ValidateSIMECK();
bool ValidateCHAM();
bool ValidateHIGHT();
bool ValidateLEA();
bool ValidateSIMON();
bool ValidateSPECK();
bool ValidateCamellia();

bool ValidateHC128();
bool ValidateHC256();
bool ValidateRabbit();
bool ValidateSalsa();
bool ValidateChaCha();
bool ValidateChaChaTLS();
bool ValidateSosemanuk();

bool ValidateVMAC();
bool ValidateCCM();
bool ValidateGCM();
bool ValidateXTS();
bool ValidateCMAC();

bool ValidateBBS();
bool ValidateDH();
bool ValidateMQV();
bool ValidateHMQV();
bool ValidateFHMQV();
bool ValidateRSA();
bool ValidateElGamal();
bool ValidateDLIES();
bool ValidateNR();
bool ValidateDSA(bool thorough);
bool ValidateLUC();
bool ValidateLUC_DL();
bool ValidateLUC_DH();
bool ValidateXTR_DH();
bool ValidateRabin();
bool ValidateRW();
bool ValidateECP();
bool ValidateEC2N();
bool ValidateECDSA();
bool ValidateECDSA_RFC6979();
bool ValidateECGDSA(bool thorough);
bool ValidateESIGN();

bool ValidateHashDRBG();
bool ValidateHmacDRBG();

bool TestX25519();
bool TestEd25519();
bool ValidateX25519();
bool ValidateEd25519();
bool ValidateNaCl();

// If CRYPTOPP_DEBUG or CRYPTOPP_COVERAGE is in effect, then perform additional tests
#if (defined(CRYPTOPP_DEBUG) || defined(CRYPTOPP_COVERAGE)) && !defined(CRYPTOPP_IMPORTS)
# define CRYPTOPP_EXTENDED_VALIDATION 1
#endif

#if defined(CRYPTOPP_EXTENDED_VALIDATION)
// http://github.com/weidai11/cryptopp/issues/92
bool TestSecBlock();
// http://github.com/weidai11/cryptopp/issues/64
bool TestPolynomialMod2();
// http://github.com/weidai11/cryptopp/issues/336
bool TestIntegerBitops();
// http://github.com/weidai11/cryptopp/issues/602
bool TestIntegerOps();
// http://github.com/weidai11/cryptopp/issues/360
bool TestRounding();
// http://github.com/weidai11/cryptopp/issues/242
bool TestHuffmanCodes();
// http://github.com/weidai11/cryptopp/issues/346
bool TestASN1Parse();
bool TestASN1Functions();
// https://github.com/weidai11/cryptopp/pull/334
bool TestStringSink();
// Additional tests due to no coverage
bool TestCompressors();
bool TestEncryptors();
bool TestMersenne();
bool TestSharing();
# if defined(CRYPTOPP_ALTIVEC_AVAILABLE)
bool TestAltivecOps();
# endif
#endif

class FixedRNG : public RandomNumberGenerator
{
public:
	FixedRNG(BufferedTransformation &source) : m_source(source) {}

	void GenerateBlock(byte *output, size_t size)
	{
		m_source.Get(output, size);
	}

private:
	BufferedTransformation &m_source;
};

// Safer functions on Windows for C&A, http://github.com/weidai11/cryptopp/issues/55
inline std::string TimeToString(const time_t& t)
{
#if (CRYPTOPP_MSC_VERSION >= 1400)
	tm localTime;
	char timeBuf[64];
	errno_t err;

	err = ::localtime_s(&localTime, &t);
	CRYPTOPP_ASSERT(err == 0);
	err = ::asctime_s(timeBuf, sizeof(timeBuf), &localTime);
	CRYPTOPP_ASSERT(err == 0);

	std::string str(err == 0 ? timeBuf : "");
#elif defined(__MINGW32__) || defined(__MINGW64__)
	char* timeString = ::asctime(::localtime(&t));
	std::string str(timeString ? timeString : "");
#elif (_POSIX_C_SOURCE >= 1 || _XOPEN_SOURCE || _BSD_SOURCE || _SVID_SOURCE || defined(_POSIX_SOURCE))
	tm localTime;
	char timeBuf[64];
	char* timeString = ::asctime_r(::localtime_r(&t, &localTime), timeBuf);
	std::string str(timeString ? timeString : "");
#else
	char* timeString = ::asctime(::localtime(&t));
	std::string str(timeString ? timeString : "");
#endif

	// Cleanup whitespace
	std::string::size_type pos = 0;
	while (!str.empty() && std::isspace(str[str.length()-1]))
		{str.erase(str.end()-1);}
	while (!str.empty() && std::string::npos != (pos = str.find("  ", pos)))
		{str.erase(pos, 1);}

	return str;
}

// Coverity finding
template <class T, bool NON_NEGATIVE>
inline T StringToValue(const std::string& str)
{
	std::istringstream iss(str);

	// Arbitrary, but we need to clear a Coverity finding TAINTED_SCALAR
	if (iss.str().length() > 25)
		throw InvalidArgument(str + "' is too long");

	T value;
	iss >> std::noskipws >> value;

	// Use fail(), not bad()
	if (iss.fail())
		throw InvalidArgument(str + "' is not a value");

	if (NON_NEGATIVE && value < 0)
		throw InvalidArgument(str + "' is negative");

	return value;
}

// Coverity finding
template<>
inline int StringToValue<int, true>(const std::string& str)
{
	Integer n(str.c_str());
	long l = n.ConvertToLong();

	int r;
	if (!SafeConvert(l, r))
		throw InvalidArgument(str + "' is not an integer value");

	return r;
}

inline std::string AddSeparator(std::string str)
{
	if (str.empty()) return "";
	const char last = str[str.length()-1];
	if (last != '/' && last != '\\')
		return str + "/";
	return str;
}

// Use CRYPTOPP_DATA_DIR last. The problem this sidesteps is, finding an
// old version of Crypto++ library in CRYPTOPP_DATA_DIR when the library
// has been staged in DESTDIR. Using CRYPTOPP_DATA_DIR first only works
// as expected when CRYPTOPP_DATA_DIR is empty before an install. We
// encountered this problem rather quickly during testing of Crypto++ 8.1
// when Crypto++ 8.0 was installed locally. It took some time to realize
// where the old test data was coming from.
static std::string GetDataDir()
{
	std::ifstream file;
	std::string name, filename = "TestData/usage.dat";

#ifndef CRYPTOPP_DISABLE_DATA_DIR_SEARCH
	// Look in $ORIGIN/../share/. This is likely a Linux install directory.
	name = AddSeparator(g_argvPathHint) + std::string("../share/cryptopp/") + filename;
	file.open(name.c_str());
	if (file.is_open())
		return AddSeparator(g_argvPathHint) + std::string("../share/cryptopp/");
#endif
#ifndef CRYPTOPP_DISABLE_DATA_DIR_SEARCH
	// Look in current working directory
	name = AddSeparator(g_argvPathHint) + filename;
	file.open(name.c_str());
	if (file.is_open())
		return AddSeparator(g_argvPathHint);
#endif
#ifdef CRYPTOPP_DATA_DIR
	// Honor CRYPTOPP_DATA_DIR. This is likely an install directory if it is not "./".
	name = AddSeparator(CRYPTOPP_DATA_DIR) + filename;
	file.open(name.c_str());
	if (file.is_open())
		return AddSeparator(CRYPTOPP_DATA_DIR);
#endif
	return "./";
}

inline std::string DataDir(const std::string& filename)
{
	std::string name;
	std::ifstream file;

#if CRYPTOPP_CXX11_STATIC_INIT
	static std::string path = AddSeparator(GetDataDir());
	name = path + filename;
	file.open(name.c_str());
	if (file.is_open())
		return name;
#else
	// Avoid static initialization problems
	name = AddSeparator(GetDataDir()) + filename;
	file.open(name.c_str());
	if (file.is_open())
		return name;
#endif

	// This will cause the expected exception in the caller
	return filename;
}

// Definition in test.cpp
RandomNumberGenerator& GlobalRNG();

// Definition in datatest.cpp
bool RunTestDataFile(const char *filename, const NameValuePairs &overrideParameters=g_nullNameValuePairs, bool thorough=true);

// Definitions in validat6.cpp
bool CryptoSystemValidate(PK_Decryptor &priv, PK_Encryptor &pub, bool thorough = false);
bool SimpleKeyAgreementValidate(SimpleKeyAgreementDomain &d);
bool AuthenticatedKeyAgreementWithRolesValidate(AuthenticatedKeyAgreementDomain &initiator, AuthenticatedKeyAgreementDomain &recipient);
bool AuthenticatedKeyAgreementValidate(AuthenticatedKeyAgreementDomain &d);
bool SignatureValidate(PK_Signer &priv, PK_Verifier &pub, bool thorough = false);

// Miscellaneous PK definitions in validat6.cpp
// Key Agreement definitions in validat7.cpp
// Encryption and Decryption definitions in validat8.cpp
// Sign and Verify definitions in validat9.cpp

bool ValidateECP();
bool ValidateEC2N();

bool ValidateRSA_Encrypt();
bool ValidateRSA_Sign();

bool ValidateLUC_Encrypt();
bool ValidateLUC_Sign();

bool ValidateLUC_DL_Encrypt();
bool ValidateLUC_DL_Sign();

bool ValidateRabin_Encrypt();
bool ValidateRabin_Sign();

bool ValidateECP();
bool ValidateECP_Agreement();
bool ValidateECP_Encrypt();
bool ValidateECP_Sign();

bool ValidateECP_Legacy_Encrypt();
bool ValidateEC2N_Legacy_Encrypt();
bool ValidateECP_NULLDigest_Encrypt();

bool ValidateEC2N();
bool ValidateEC2N_Agreement();
bool ValidateEC2N_Encrypt();
bool ValidateEC2N_Sign();

NAMESPACE_END  // Test
NAMESPACE_END  // CryptoPP

#endif
