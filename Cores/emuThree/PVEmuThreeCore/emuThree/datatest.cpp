// datatest.cpp - originally written and placed in the public domain by Wei Dai
//                CryptoPP::Test namespace added by JW in February 2017

// Local Changes: Header include path

#define CRYPTOPP_DEFAULT_NO_DLL
#define CRYPTOPP_ENABLE_NAMESPACE_WEAK 1

#include "cryptlib.h"
#include "../externals/include/cryptopp/factory.h"
#include "integer.h"
#include "filters.h"
#include "randpool.h"
#include "files.h"
#include "trunhash.h"
#include "queue.h"
#include "smartptr.h"
#include "validate.h"
#include "stdcpp.h"
#include "misc.h"
#include "hex.h"
#include "trap.h"

#include <iostream>
#include <sstream>
#include <cerrno>

// Aggressive stack checking with VS2005 SP1 and above.
#if (_MSC_FULL_VER >= 140050727)
# pragma strict_gs_check (on)
#endif

#if CRYPTOPP_MSC_VERSION
# pragma warning(disable: 4505 4355)
#endif

#ifdef _MSC_VER
# define STRTOUL64 _strtoui64
#else
# define STRTOUL64 strtoull
#endif

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(Test)

ANONYMOUS_NAMESPACE_BEGIN

bool s_thorough = false;
typedef std::map<std::string, std::string> TestData;
const TestData *s_currentTestData = NULLPTR;
const std::string testDataFilename = "cryptest.dat";

// Handles CR, LF, and CRLF properly
// For istream.fail() see https://stackoverflow.com/q/34395801/608639.
bool Readline(std::istream& stream, std::string& line)
{
	// Ensure old data is cleared
	line.clear();

	std::string temp;
	temp.reserve(64);

	while (!stream.fail())
	{
		int ch = stream.get();
		if (ch == '\r')
		{
			int next = stream.peek();
			if (next == '\n')
				(void)stream.get();

			break;
		}
		else if (ch == '\n')
		{
			break;
		}

		// Let string class manage its own capacity.
		// The string will grow as needed.
		temp.push_back(static_cast<char>(ch));
	}

#if defined(CRYPTOPP_CXX11)
	temp.shrink_to_fit();
#else
	// Non-binding shrink to fit
	temp.reserve(0);
#endif

	std::swap(line, temp);

	return !stream.fail();
}

std::string TrimSpace(const std::string& str)
{
	if (str.empty()) return "";

	const std::string whitespace(" \r\t\n");
	std::string::size_type beg = str.find_first_not_of(whitespace);
	std::string::size_type end = str.find_last_not_of(whitespace);

	if (beg != std::string::npos && end != std::string::npos)
		return str.substr(beg, end+1);
	else if (beg != std::string::npos)
		return str.substr(beg);
	else
		return "";
}

std::string TrimComment(const std::string& str)
{
	if (str.empty()) return "";

	std::string::size_type first = str.find("#");

	if (first != std::string::npos)
		return TrimSpace(str.substr(0, first));
	else
		return TrimSpace(str);
}

class TestFailure : public Exception
{
public:
	TestFailure() : Exception(OTHER_ERROR, "Validation test failed") {}
};

void OutputTestData(const TestData &v)
{
	std::cerr << "\n";
	for (TestData::const_iterator i = v.begin(); i != v.end(); ++i)
	{
		std::cerr << i->first << ": " << i->second << std::endl;
	}
}

void SignalTestFailure()
{
	OutputTestData(*s_currentTestData);
	throw TestFailure();
}

void SignalUnknownAlgorithmError(const std::string& algType)
{
	OutputTestData(*s_currentTestData);
	throw Exception(Exception::OTHER_ERROR, "Unknown algorithm " + algType + " during validation test");
}

void SignalTestError(const char* msg = NULLPTR)
{
	OutputTestData(*s_currentTestData);

	if (msg)
		throw Exception(Exception::OTHER_ERROR, msg);
	else
		throw Exception(Exception::OTHER_ERROR, "Unexpected error during validation test");
}

bool DataExists(const TestData &data, const char *name)
{
	TestData::const_iterator i = data.find(name);
	return (i != data.end());
}

const std::string & GetRequiredDatum(const TestData &data, const char *name)
{
	TestData::const_iterator i = data.find(name);
	if (i == data.end())
	{
		std::string msg("Required datum \"" + std::string(name) + "\" missing");
		SignalTestError(msg.c_str());
	}
	return i->second;
}

void RandomizedTransfer(BufferedTransformation &source, BufferedTransformation &target, bool finish, const std::string &channel=DEFAULT_CHANNEL)
{
	while (source.MaxRetrievable() > (finish ? 0 : 4096))
	{
		byte buf[4096+64];
		size_t start = Test::GlobalRNG().GenerateWord32(0, 63);
		size_t len = Test::GlobalRNG().GenerateWord32(1, UnsignedMin(4096U, 3*source.MaxRetrievable()/2));
		len = source.Get(buf+start, len);
		target.ChannelPut(channel, buf+start, len);
	}
}

void PutDecodedDatumInto(const TestData &data, const char *name, BufferedTransformation &target)
{
	std::string s1 = GetRequiredDatum(data, name), s2;
	ByteQueue q;

	while (!s1.empty())
	{
		std::string::size_type pos = s1.find_first_not_of(" ");
		if (pos != std::string::npos)
			s1.erase(0, pos);

		if (s1.empty())
			goto end;

		int repeat = 1;
		if (s1[0] == 'r')
		{
			s1 = s1.erase(0, 1);
			repeat = std::atoi(s1.c_str());
			s1 = s1.substr(s1.find(' ')+1);
		}

		// Convert word32 or word64 to little endian order. Some algorithm test vectors are
		// presented in the format. We probably should have named them word32le and word64le.
		if (s1.length() >= 6 && (s1.substr(0,6) == "word32" || s1.substr(0,6) == "word64"))
		{
			std::istringstream iss(s1.substr(6));
			if (s1.substr(0,6) == "word64")
			{
				word64 value;
				while (iss >> std::skipws >> std::hex >> value)
				{
					value = ConditionalByteReverse(LITTLE_ENDIAN_ORDER, value);
					q.Put(reinterpret_cast<const byte *>(&value), 8);
				}
			}
			else
			{
				word32 value;
				while (iss >> std::skipws >> std::hex >> value)
				{
					value = ConditionalByteReverse(LITTLE_ENDIAN_ORDER, value);
					q.Put(reinterpret_cast<const byte *>(&value), 4);
				}
			}
			goto end;
		}

		s2.clear();
		if (s1[0] == '\"')
		{
			s2 = s1.substr(1, s1.find('\"', 1)-1);
			s1 = s1.substr(s2.length() + 2);
		}
		else if (s1.substr(0, 2) == "0x")
		{
			std::string::size_type n = s1.find(' ');
			StringSource(s1.substr(2, n), true, new HexDecoder(new StringSink(s2)));
			s1 = s1.substr(STDMIN(n, s1.length()));
		}
		else
		{
			std::string::size_type n = s1.find(' ');
			StringSource(s1.substr(0, n), true, new HexDecoder(new StringSink(s2)));
			s1 = s1.substr(STDMIN(n, s1.length()));
		}

		while (repeat--)
		{
			q.Put(ConstBytePtr(s2), BytePtrSize(s2));
			RandomizedTransfer(q, target, false);
		}
	}

end:
	RandomizedTransfer(q, target, true);
}

std::string GetDecodedDatum(const TestData &data, const char *name)
{
	std::string s;
	PutDecodedDatumInto(data, name, StringSink(s).Ref());
	return s;
}

std::string GetOptionalDecodedDatum(const TestData &data, const char *name)
{
	std::string s;
	if (DataExists(data, name))
		PutDecodedDatumInto(data, name, StringSink(s).Ref());
	return s;
}

class TestDataNameValuePairs : public NameValuePairs
{
public:
	TestDataNameValuePairs(const TestData &data) : m_data(data) {}

	virtual bool GetVoidValue(const char *name, const std::type_info &valueType, void *pValue) const
	{
		TestData::const_iterator i = m_data.find(name);
		if (i == m_data.end())
		{
			if (std::string(name) == Name::DigestSize() && valueType == typeid(int))
			{
				i = m_data.find("MAC");
				if (i == m_data.end())
					i = m_data.find("Digest");
				if (i == m_data.end())
					return false;

				m_temp.clear();
				PutDecodedDatumInto(m_data, i->first.c_str(), StringSink(m_temp).Ref());
				*reinterpret_cast<int *>(pValue) = (int)m_temp.size();
				return true;
			}
			else
				return false;
		}

		const std::string &value = i->second;

		if (valueType == typeid(int))
			*reinterpret_cast<int *>(pValue) = atoi(value.c_str());
		else if (valueType == typeid(word64))
		{
			std::string x(value.empty() ? "0" : value);
			const char* beg = &x[0];
			char* end = &x[0] + value.size();

			errno = 0;
			*reinterpret_cast<word64*>(pValue) = STRTOUL64(beg, &end, 0);
			if (errno != 0)
				return false;
		}
		else if (valueType == typeid(Integer))
			*reinterpret_cast<Integer *>(pValue) = Integer((std::string(value) + "h").c_str());
		else if (valueType == typeid(ConstByteArrayParameter))
		{
			m_temp.clear();
			PutDecodedDatumInto(m_data, name, StringSink(m_temp).Ref());
			reinterpret_cast<ConstByteArrayParameter *>(pValue)->Assign(ConstBytePtr(m_temp), BytePtrSize(m_temp), false);
		}
		else
			throw ValueTypeMismatch(name, typeid(std::string), valueType);

		return true;
	}

private:
	const TestData &m_data;
	mutable std::string m_temp;
};

void TestKeyPairValidAndConsistent(CryptoMaterial &pub, const CryptoMaterial &priv, unsigned int &totalTests)
{
	totalTests++;

	if (!pub.Validate(Test::GlobalRNG(), 2U+!!s_thorough))
		SignalTestFailure();
	if (!priv.Validate(Test::GlobalRNG(), 2U+!!s_thorough))
		SignalTestFailure();

	ByteQueue bq1, bq2;
	pub.Save(bq1);
	pub.AssignFrom(priv);
	pub.Save(bq2);
	if (bq1 != bq2)
		SignalTestFailure();
}

void TestSignatureScheme(TestData &v, unsigned int &totalTests)
{
	std::string name = GetRequiredDatum(v, "Name");
	std::string test = GetRequiredDatum(v, "Test");

	static member_ptr<PK_Signer> signer;
	static member_ptr<PK_Verifier> verifier;
	static std::string lastName;

	if (name != lastName)
	{
		signer.reset(ObjectFactoryRegistry<PK_Signer>::Registry().CreateObject(name.c_str()));
		verifier.reset(ObjectFactoryRegistry<PK_Verifier>::Registry().CreateObject(name.c_str()));
		lastName = name;

		// Code coverage
		(void)signer->AlgorithmName();
		(void)verifier->AlgorithmName();
		(void)signer->AlgorithmProvider();
		(void)verifier->AlgorithmProvider();
	}

	TestDataNameValuePairs pairs(v);

	if (test == "GenerateKey")
	{
		totalTests++;

		signer->AccessPrivateKey().GenerateRandom(Test::GlobalRNG(), pairs);
		verifier->AccessPublicKey().AssignFrom(signer->AccessPrivateKey());
	}
	else
	{
		std::string keyFormat = GetRequiredDatum(v, "KeyFormat");

		totalTests++;  // key format
		if (keyFormat == "DER")
			verifier->AccessMaterial().Load(StringStore(GetDecodedDatum(v, "PublicKey")).Ref());
		else if (keyFormat == "Component")
			verifier->AccessMaterial().AssignFrom(pairs);

		if (test == "Verify" || test == "NotVerify")
		{
			totalTests++;

			SignatureVerificationFilter verifierFilter(*verifier, NULLPTR, SignatureVerificationFilter::SIGNATURE_AT_BEGIN);
			PutDecodedDatumInto(v, "Signature", verifierFilter);
			PutDecodedDatumInto(v, "Message", verifierFilter);
			verifierFilter.MessageEnd();
			if (verifierFilter.GetLastResult() == (test == "NotVerify"))
				SignalTestFailure();
			return;
		}
		else if (test == "PublicKeyValid")
		{
			totalTests++;

			if (!verifier->GetMaterial().Validate(Test::GlobalRNG(), 3))
				SignalTestFailure();
			return;
		}

		totalTests++; // key format
		if (keyFormat == "DER")
			signer->AccessMaterial().Load(StringStore(GetDecodedDatum(v, "PrivateKey")).Ref());
		else if (keyFormat == "Component")
			signer->AccessMaterial().AssignFrom(pairs);
	}

	if (test == "GenerateKey" || test == "KeyPairValidAndConsistent")
	{
		totalTests++;

		TestKeyPairValidAndConsistent(verifier->AccessMaterial(), signer->GetMaterial(),totalTests);
		SignatureVerificationFilter verifierFilter(*verifier, NULLPTR, SignatureVerificationFilter::THROW_EXCEPTION);
		const byte msg[3] = {'a', 'b', 'c'};
		verifierFilter.Put(msg, sizeof(msg));
		StringSource ss(msg, sizeof(msg), true, new SignerFilter(Test::GlobalRNG(), *signer, new Redirector(verifierFilter)));
	}
	else if (test == "Sign")
	{
		totalTests++;

		SignerFilter f(Test::GlobalRNG(), *signer, new HexEncoder(new FileSink(std::cout)));
		StringSource ss(GetDecodedDatum(v, "Message"), true, new Redirector(f));
		SignalTestFailure();
	}
	else if (test == "DeterministicSign")
	{
		totalTests++;

		// This test is specialized for RFC 6979. The RFC is a drop-in replacement
		// for DSA and ECDSA, and access to the seed or secret is not needed. If
		// additional deterministic signatures are added, then the test harness will
		// likely need to be extended.
		std::string signature;
		SignerFilter f(Test::GlobalRNG(), *signer, new StringSink(signature));
		StringSource ss(GetDecodedDatum(v, "Message"), true, new Redirector(f));

		if (GetDecodedDatum(v, "Signature") != signature)
			SignalTestFailure();
	}
	else
	{
		std::string msg("Unknown signature test \"" + test + "\"");
		SignalTestError(msg.c_str());
		CRYPTOPP_ASSERT(false);
	}
}

// Subset of TestSignatureScheme. We picked the tests that have data that is easy to write to a file.
// Also see https://github.com/weidai11/cryptopp/issues/1010, where HIGHT broke when using FileSource.
void TestSignatureSchemeWithFileSource(TestData &v, unsigned int &totalTests)
{
	std::string name = GetRequiredDatum(v, "Name");
	std::string test = GetRequiredDatum(v, "Test");

	if (test != "Sign" && test != "DeterministicSign") { return; }

	static member_ptr<PK_Signer> signer;
	static member_ptr<PK_Verifier> verifier;
	static std::string lastName;

	if (name != lastName)
	{
		signer.reset(ObjectFactoryRegistry<PK_Signer>::Registry().CreateObject(name.c_str()));
		verifier.reset(ObjectFactoryRegistry<PK_Verifier>::Registry().CreateObject(name.c_str()));
		name = lastName;

		// Code coverage
		(void)signer->AlgorithmName();
		(void)verifier->AlgorithmName();
		(void)signer->AlgorithmProvider();
		(void)verifier->AlgorithmProvider();
	}

	TestDataNameValuePairs pairs(v);

	std::string keyFormat = GetRequiredDatum(v, "KeyFormat");

	totalTests++;  // key format
	if (keyFormat == "DER")
		verifier->AccessMaterial().Load(StringStore(GetDecodedDatum(v, "PublicKey")).Ref());
	else if (keyFormat == "Component")
		verifier->AccessMaterial().AssignFrom(pairs);

	totalTests++; // key format
	if (keyFormat == "DER")
		signer->AccessMaterial().Load(StringStore(GetDecodedDatum(v, "PrivateKey")).Ref());
	else if (keyFormat == "Component")
		signer->AccessMaterial().AssignFrom(pairs);

	if (test == "Sign")
	{
		totalTests++;

		SignerFilter f(Test::GlobalRNG(), *signer, new HexEncoder(new FileSink(std::cout)));
		StringSource ss(GetDecodedDatum(v, "Message"), true, new FileSink(testDataFilename.c_str()));
		FileSource fs(testDataFilename.c_str(), true, new Redirector(f));
		SignalTestFailure();
	}
	else if (test == "DeterministicSign")
	{
		totalTests++;

		// This test is specialized for RFC 6979. The RFC is a drop-in replacement
		// for DSA and ECDSA, and access to the seed or secret is not needed. If
		// additional deterministic signatures are added, then the test harness will
		// likely need to be extended.
		std::string signature;
		SignerFilter f(Test::GlobalRNG(), *signer, new StringSink(signature));
		StringSource ss(GetDecodedDatum(v, "Message"), true, new FileSink(testDataFilename.c_str()));
		FileSource fs(testDataFilename.c_str(), true, new Redirector(f));

		if (GetDecodedDatum(v, "Signature") != signature)
			SignalTestFailure();
	}
}

void TestAsymmetricCipher(TestData &v, unsigned int &totalTests)
{
	std::string name = GetRequiredDatum(v, "Name");
	std::string test = GetRequiredDatum(v, "Test");

	static member_ptr<PK_Encryptor> encryptor;
	static member_ptr<PK_Decryptor> decryptor;
	static std::string lastName;

	if (name != lastName)
	{
		encryptor.reset(ObjectFactoryRegistry<PK_Encryptor>::Registry().CreateObject(name.c_str()));
		decryptor.reset(ObjectFactoryRegistry<PK_Decryptor>::Registry().CreateObject(name.c_str()));
		lastName = name;

		// Code coverage
		(void)encryptor->AlgorithmName();
		(void)decryptor->AlgorithmName();
		(void)encryptor->AlgorithmProvider();
		(void)decryptor->AlgorithmProvider();
	}

	std::string keyFormat = GetRequiredDatum(v, "KeyFormat");

	if (keyFormat == "DER")
	{
		totalTests++;

		decryptor->AccessMaterial().Load(StringStore(GetDecodedDatum(v, "PrivateKey")).Ref());
		encryptor->AccessMaterial().Load(StringStore(GetDecodedDatum(v, "PublicKey")).Ref());
	}
	else if (keyFormat == "Component")
	{
		totalTests++;

		TestDataNameValuePairs pairs(v);
		decryptor->AccessMaterial().AssignFrom(pairs);
		encryptor->AccessMaterial().AssignFrom(pairs);
	}

	if (test == "DecryptMatch")
	{
		totalTests++;

		std::string decrypted, expected = GetDecodedDatum(v, "Plaintext");
		StringSource ss(GetDecodedDatum(v, "Ciphertext"), true, new PK_DecryptorFilter(Test::GlobalRNG(), *decryptor, new StringSink(decrypted)));
		if (decrypted != expected)
			SignalTestFailure();
	}
	else if (test == "KeyPairValidAndConsistent")
	{
		totalTests++;

		TestKeyPairValidAndConsistent(encryptor->AccessMaterial(), decryptor->GetMaterial(), totalTests);
	}
	else
	{
		std::string msg("Unknown asymmetric cipher test \"" + test + "\"");
		SignalTestError(msg.c_str());
		CRYPTOPP_ASSERT(false);
	}
}

void TestSymmetricCipher(TestData &v, const NameValuePairs &overrideParameters, unsigned int &totalTests)
{
	std::string name = GetRequiredDatum(v, "Name");
	std::string test = GetRequiredDatum(v, "Test");

	std::string key = GetDecodedDatum(v, "Key");
	std::string plaintext = GetDecodedDatum(v, "Plaintext");

	TestDataNameValuePairs testDataPairs(v);
	CombinedNameValuePairs pairs(overrideParameters, testDataPairs);

	if (test == "Encrypt" || test == "EncryptXorDigest" || test == "Resync" || test == "EncryptionMCT" || test == "DecryptionMCT")
	{
		static member_ptr<SymmetricCipher> encryptor, decryptor;
		static std::string lastName;

		totalTests++;

		if (name != lastName)
		{
			encryptor.reset(ObjectFactoryRegistry<SymmetricCipher, ENCRYPTION>::Registry().CreateObject(name.c_str()));
			decryptor.reset(ObjectFactoryRegistry<SymmetricCipher, DECRYPTION>::Registry().CreateObject(name.c_str()));
			lastName = name;

			// Code coverage
			(void)encryptor->AlgorithmName();
			(void)decryptor->AlgorithmName();
			(void)encryptor->AlgorithmProvider();
			(void)decryptor->AlgorithmProvider();
			(void)encryptor->IsRandomAccess();
			(void)decryptor->IsRandomAccess();
			(void)encryptor->MinKeyLength();
			(void)decryptor->MinKeyLength();
			(void)encryptor->MaxKeyLength();
			(void)decryptor->MaxKeyLength();
			(void)encryptor->DefaultKeyLength();
			(void)decryptor->DefaultKeyLength();
		}

		ConstByteArrayParameter iv;
		if (pairs.GetValue(Name::IV(), iv) && iv.size() != encryptor->IVSize())
			SignalTestFailure();

		if (test == "Resync")
		{
			encryptor->Resynchronize(iv.begin(), (int)iv.size());
			decryptor->Resynchronize(iv.begin(), (int)iv.size());
		}
		else
		{
			encryptor->SetKey(ConstBytePtr(key), BytePtrSize(key), pairs);
			decryptor->SetKey(ConstBytePtr(key), BytePtrSize(key), pairs);
		}

		word64 seek64 = pairs.GetWord64ValueWithDefault("Seek64", 0);
		if (seek64)
		{
			encryptor->Seek(seek64);
			decryptor->Seek(seek64);
		}
		else
		{
			int seek = pairs.GetIntValueWithDefault("Seek", 0);
			if (seek)
			{
				encryptor->Seek(seek);
				decryptor->Seek(seek);
			}
		}

		// Most block ciphers don't specify BlockPaddingScheme. Kalyna uses it
		// in test vectors. 0 is NoPadding, 1 is ZerosPadding, 2 is PkcsPadding,
		// 3 is OneAndZerosPadding, etc. Note: The machinery is wired such that
		// paddingScheme is effectively latched. An old paddingScheme may be
		// unintentionally used in a subsequent test.
		int paddingScheme = pairs.GetIntValueWithDefault(Name::BlockPaddingScheme(), 0);

		std::string encrypted, xorDigest, ciphertext, ciphertextXorDigest;
		if (test == "EncryptionMCT" || test == "DecryptionMCT")
		{
			SymmetricCipher *cipher = encryptor.get();
			std::string buf(plaintext), keybuf(key);

			if (test == "DecryptionMCT")
			{
				cipher = decryptor.get();
				ciphertext = GetDecodedDatum(v, "Ciphertext");
				buf.assign(ciphertext.begin(), ciphertext.end());
			}

			for (int i=0; i<400; i++)
			{
				encrypted.reserve(10000 * plaintext.size());
				for (int j=0; j<10000; j++)
				{
					cipher->ProcessString(BytePtr(buf), BytePtrSize(buf));
					encrypted.append(buf.begin(), buf.end());
				}

				encrypted.erase(0, encrypted.size() - keybuf.size());
				xorbuf(BytePtr(keybuf), BytePtr(encrypted), BytePtrSize(keybuf));
				cipher->SetKey(BytePtr(keybuf), BytePtrSize(keybuf));
			}

			encrypted.assign(buf.begin(), buf.end());
			ciphertext = GetDecodedDatum(v, test == "EncryptionMCT" ? "Ciphertext" : "Plaintext");
			if (encrypted != ciphertext)
			{
				std::cout << "\nincorrectly encrypted: ";
				StringSource ss(encrypted, false, new HexEncoder(new FileSink(std::cout)));
				ss.Pump(256); ss.Flush(false);
				std::cout << "\n";
				SignalTestFailure();
			}
			return;
		}

		StreamTransformationFilter encFilter(*encryptor, new StringSink(encrypted),
			static_cast<BlockPaddingSchemeDef::BlockPaddingScheme>(paddingScheme));

		StringStore pstore(plaintext);
		RandomizedTransfer(pstore, encFilter, true);
		encFilter.MessageEnd();

		if (test != "EncryptXorDigest")
		{
			ciphertext = GetDecodedDatum(v, "Ciphertext");
		}
		else
		{
			ciphertextXorDigest = GetDecodedDatum(v, "CiphertextXorDigest");
			xorDigest.append(encrypted, 0, 64);
			for (size_t i=64; i<encrypted.size(); i++)
				xorDigest[i%64] = static_cast<char>(xorDigest[i%64] ^ encrypted[i]);
		}
		if (test != "EncryptXorDigest" ? encrypted != ciphertext : xorDigest != ciphertextXorDigest)
		{
			std::cout << "\nincorrectly encrypted: ";
			StringSource ss(encrypted, false, new HexEncoder(new FileSink(std::cout)));
			ss.Pump(2048); ss.Flush(false);
			std::cout << "\n";
			SignalTestFailure();
		}

		std::string decrypted;
		StreamTransformationFilter decFilter(*decryptor, new StringSink(decrypted),
			static_cast<BlockPaddingSchemeDef::BlockPaddingScheme>(paddingScheme));

		StringStore cstore(encrypted);
		RandomizedTransfer(cstore, decFilter, true);
		decFilter.MessageEnd();

		if (decrypted != plaintext)
		{
			std::cout << "\nincorrectly decrypted: ";
			StringSource ss(decrypted, false, new HexEncoder(new FileSink(std::cout)));
			ss.Pump(256); ss.Flush(false);
			std::cout << "\n";
			SignalTestFailure();
		}
	}
	else
	{
		std::string msg("Unknown symmetric cipher test \"" + test + "\"");
		SignalTestError(msg.c_str());
	}
}

// Subset of TestSymmetricCipher. We picked the tests that have data that is easy to write to a file.
// Also see https://github.com/weidai11/cryptopp/issues/1010, where HIGHT broke when using FileSource.
void TestSymmetricCipherWithFileSource(TestData &v, const NameValuePairs &overrideParameters, unsigned int &totalTests)
{
	std::string name = GetRequiredDatum(v, "Name");
	std::string test = GetRequiredDatum(v, "Test");

	// Limit FileSource tests to Encrypt only.
	if (test != "Encrypt") { return; }

	totalTests++;

	std::string key = GetDecodedDatum(v, "Key");
	std::string plaintext = GetDecodedDatum(v, "Plaintext");

	TestDataNameValuePairs testDataPairs(v);
	CombinedNameValuePairs pairs(overrideParameters, testDataPairs);

	static member_ptr<SymmetricCipher> encryptor, decryptor;
	static std::string lastName;

	if (name != lastName)
	{
		encryptor.reset(ObjectFactoryRegistry<SymmetricCipher, ENCRYPTION>::Registry().CreateObject(name.c_str()));
		decryptor.reset(ObjectFactoryRegistry<SymmetricCipher, DECRYPTION>::Registry().CreateObject(name.c_str()));
		lastName = name;

		// Code coverage
		(void)encryptor->AlgorithmName();
		(void)decryptor->AlgorithmName();
		(void)encryptor->AlgorithmProvider();
		(void)decryptor->AlgorithmProvider();
		(void)encryptor->MinKeyLength();
		(void)decryptor->MinKeyLength();
		(void)encryptor->MaxKeyLength();
		(void)decryptor->MaxKeyLength();
		(void)encryptor->DefaultKeyLength();
		(void)decryptor->DefaultKeyLength();
	}

	ConstByteArrayParameter iv;
	if (pairs.GetValue(Name::IV(), iv) && iv.size() != encryptor->IVSize())
		SignalTestFailure();

	encryptor->SetKey(ConstBytePtr(key), BytePtrSize(key), pairs);
	decryptor->SetKey(ConstBytePtr(key), BytePtrSize(key), pairs);

	word64 seek64 = pairs.GetWord64ValueWithDefault("Seek64", 0);
	if (seek64)
	{
		encryptor->Seek(seek64);
		decryptor->Seek(seek64);
	}
	else
	{
		int seek = pairs.GetIntValueWithDefault("Seek", 0);
		if (seek)
		{
			encryptor->Seek(seek);
			decryptor->Seek(seek);
		}
	}

	// Most block ciphers don't specify BlockPaddingScheme. Kalyna uses it
	// in test vectors. 0 is NoPadding, 1 is ZerosPadding, 2 is PkcsPadding,
	// 3 is OneAndZerosPadding, etc. Note: The machinery is wired such that
	// paddingScheme is effectively latched. An old paddingScheme may be
	// unintentionally used in a subsequent test.
	int paddingScheme = pairs.GetIntValueWithDefault(Name::BlockPaddingScheme(), 0);

	std::string encrypted, ciphertext;
	StreamTransformationFilter encFilter(*encryptor, new StringSink(encrypted),
		static_cast<BlockPaddingSchemeDef::BlockPaddingScheme>(paddingScheme));

	StringSource ss(plaintext, true, new FileSink(testDataFilename.c_str()));
	FileSource pstore(testDataFilename.c_str(), true);
	RandomizedTransfer(pstore, encFilter, true);
	encFilter.MessageEnd();

	ciphertext = GetDecodedDatum(v, "Ciphertext");

	if (encrypted != ciphertext)
	{
		std::cout << "\nincorrectly encrypted: ";
		StringSource sss(encrypted, false, new HexEncoder(new FileSink(std::cout)));
		sss.Pump(2048); sss.Flush(false);
		std::cout << "\n";
		SignalTestFailure();
	}

	std::string decrypted;
	StreamTransformationFilter decFilter(*decryptor, new StringSink(decrypted),
		static_cast<BlockPaddingSchemeDef::BlockPaddingScheme>(paddingScheme));

	StringStore cstore(encrypted);
	RandomizedTransfer(cstore, decFilter, true);
	decFilter.MessageEnd();

	if (decrypted != plaintext)
	{
		std::cout << "\nincorrectly decrypted: ";
		StringSource sss(decrypted, false, new HexEncoder(new FileSink(std::cout)));
		sss.Pump(256); sss.Flush(false);
		std::cout << "\n";
		SignalTestFailure();
	}
}

void TestAuthenticatedSymmetricCipher(TestData &v, const NameValuePairs &overrideParameters, unsigned int &totalTests)
{
	std::string type = GetRequiredDatum(v, "AlgorithmType");
	std::string name = GetRequiredDatum(v, "Name");
	std::string test = GetRequiredDatum(v, "Test");
	std::string key = GetDecodedDatum(v, "Key");

	std::string plaintext = GetOptionalDecodedDatum(v, "Plaintext");
	std::string ciphertext = GetOptionalDecodedDatum(v, "Ciphertext");
	std::string header = GetOptionalDecodedDatum(v, "Header");
	std::string footer = GetOptionalDecodedDatum(v, "Footer");
	std::string mac = GetOptionalDecodedDatum(v, "MAC");

	TestDataNameValuePairs testDataPairs(v);
	CombinedNameValuePairs pairs(overrideParameters, testDataPairs);

	if (test == "Encrypt" || test == "EncryptXorDigest" || test == "NotVerify")
	{
		totalTests++;

		static member_ptr<AuthenticatedSymmetricCipher> encryptor;
		static member_ptr<AuthenticatedSymmetricCipher> decryptor;
		static std::string lastName;

		if (name != lastName)
		{
			encryptor.reset(ObjectFactoryRegistry<AuthenticatedSymmetricCipher, ENCRYPTION>::Registry().CreateObject(name.c_str()));
			decryptor.reset(ObjectFactoryRegistry<AuthenticatedSymmetricCipher, DECRYPTION>::Registry().CreateObject(name.c_str()));
			name = lastName;

			// Code coverage
			(void)encryptor->AlgorithmName();
			(void)decryptor->AlgorithmName();
			(void)encryptor->AlgorithmProvider();
			(void)decryptor->AlgorithmProvider();
			(void)encryptor->MinKeyLength();
			(void)decryptor->MinKeyLength();
			(void)encryptor->MaxKeyLength();
			(void)decryptor->MaxKeyLength();
			(void)encryptor->DefaultKeyLength();
			(void)decryptor->DefaultKeyLength();
			(void)encryptor->IsRandomAccess();
			(void)decryptor->IsRandomAccess();
			(void)encryptor->IsSelfInverting();
			(void)decryptor->IsSelfInverting();
			(void)encryptor->MaxHeaderLength();
			(void)decryptor->MaxHeaderLength();
			(void)encryptor->MaxMessageLength();
			(void)decryptor->MaxMessageLength();
			(void)encryptor->MaxFooterLength();
			(void)decryptor->MaxFooterLength();
			(void)encryptor->NeedsPrespecifiedDataLengths();
			(void)decryptor->NeedsPrespecifiedDataLengths();
		}

		encryptor->SetKey(ConstBytePtr(key), BytePtrSize(key), pairs);
		decryptor->SetKey(ConstBytePtr(key), BytePtrSize(key), pairs);

		std::string encrypted, decrypted;
		AuthenticatedEncryptionFilter ef(*encryptor, new StringSink(encrypted));
		bool macAtBegin = !mac.empty() && !Test::GlobalRNG().GenerateBit();	// test both ways randomly
		AuthenticatedDecryptionFilter df(*decryptor, new StringSink(decrypted), macAtBegin ? AuthenticatedDecryptionFilter::MAC_AT_BEGIN : 0);

		if (encryptor->NeedsPrespecifiedDataLengths())
		{
			encryptor->SpecifyDataLengths(header.size(), plaintext.size(), footer.size());
			decryptor->SpecifyDataLengths(header.size(), plaintext.size(), footer.size());
		}

		StringStore sh(header), sp(plaintext), sc(ciphertext), sf(footer), sm(mac);

		if (macAtBegin)
			RandomizedTransfer(sm, df, true);
		sh.CopyTo(df, LWORD_MAX, AAD_CHANNEL);
		RandomizedTransfer(sc, df, true);
		sf.CopyTo(df, LWORD_MAX, AAD_CHANNEL);
		if (!macAtBegin)
			RandomizedTransfer(sm, df, true);
		df.MessageEnd();

		RandomizedTransfer(sh, ef, true, AAD_CHANNEL);
		RandomizedTransfer(sp, ef, true);
		RandomizedTransfer(sf, ef, true, AAD_CHANNEL);
		ef.MessageEnd();

		if (test == "Encrypt" && encrypted != ciphertext+mac)
		{
			std::cout << "\nincorrectly encrypted: ";
			StringSource ss(encrypted, false, new HexEncoder(new FileSink(std::cout)));
			ss.Pump(2048); ss.Flush(false);
			std::cout << "\n";
			SignalTestFailure();
		}
		if (test == "Encrypt" && decrypted != plaintext)
		{
			std::cout << "\nincorrectly decrypted: ";
			StringSource ss(decrypted, false, new HexEncoder(new FileSink(std::cout)));
			ss.Pump(256); ss.Flush(false);
			std::cout << "\n";
			SignalTestFailure();
		}

		if (ciphertext.size()+mac.size()-plaintext.size() != encryptor->DigestSize())
		{
			std::cout << "\nbad MAC size\n";
			SignalTestFailure();
		}
		if (df.GetLastResult() != (test == "Encrypt"))
		{
			std::cout << "\nMAC incorrectly verified\n";
			SignalTestFailure();
		}
	}
	else
	{
		std::string msg("Unknown authenticated symmetric cipher test \"" + test + "\"");
		SignalTestError(msg.c_str());
	}
}

void TestDigestOrMAC(TestData &v, bool testDigest, unsigned int &totalTests)
{
	std::string name = GetRequiredDatum(v, "Name");
	std::string test = GetRequiredDatum(v, "Test");
	const char *digestName = testDigest ? "Digest" : "MAC";

	member_ptr<MessageAuthenticationCode> mac;
	member_ptr<HashTransformation> hash;
	HashTransformation *pHash = NULLPTR;

	TestDataNameValuePairs pairs(v);

	if (testDigest)
	{
		hash.reset(ObjectFactoryRegistry<HashTransformation>::Registry().CreateObject(name.c_str()));
		pHash = hash.get();

		// Code coverage
		(void)hash->AlgorithmName();
		(void)hash->AlgorithmProvider();
		(void)hash->TagSize();
		(void)hash->DigestSize();
		(void)hash->Restart();
	}
	else
	{
		mac.reset(ObjectFactoryRegistry<MessageAuthenticationCode>::Registry().CreateObject(name.c_str()));
		pHash = mac.get();
		std::string key = GetDecodedDatum(v, "Key");
		mac->SetKey(ConstBytePtr(key), BytePtrSize(key), pairs);

		// Code coverage
		(void)mac->AlgorithmName();
		(void)mac->AlgorithmProvider();
		(void)mac->TagSize();
		(void)mac->DigestSize();
		(void)mac->Restart();
		(void)mac->MinKeyLength();
		(void)mac->MaxKeyLength();
		(void)mac->DefaultKeyLength();
	}

	if (test == "Verify" || test == "VerifyTruncated" || test == "NotVerify")
	{
		totalTests++;

		int digestSize = -1;
		if (test == "VerifyTruncated")
			digestSize = pairs.GetIntValueWithDefault(Name::DigestSize(), digestSize);
		HashVerificationFilter verifierFilter(*pHash, NULLPTR, HashVerificationFilter::HASH_AT_BEGIN, digestSize);
		PutDecodedDatumInto(v, digestName, verifierFilter);
		PutDecodedDatumInto(v, "Message", verifierFilter);
		verifierFilter.MessageEnd();
		if (verifierFilter.GetLastResult() == (test == "NotVerify"))
			SignalTestFailure();
	}
	else
	{
		std::string msg("Unknown digest or mac test \"" + test + "\"");
		SignalTestError(msg.c_str());
	}
}

void TestKeyDerivationFunction(TestData &v, unsigned int &totalTests)
{
	totalTests++;

	std::string name = GetRequiredDatum(v, "Name");
	std::string test = GetRequiredDatum(v, "Test");

	if(test == "Skip") return;

	std::string secret = GetDecodedDatum(v, "Secret");
	std::string expected = GetDecodedDatum(v, "DerivedKey");

	TestDataNameValuePairs pairs(v);

	static member_ptr<KeyDerivationFunction> kdf;
	static std::string lastName;

	if (name != lastName)
	{
		kdf.reset(ObjectFactoryRegistry<KeyDerivationFunction>::Registry().CreateObject(name.c_str()));
		name = lastName;

		// Code coverage
		(void)kdf->AlgorithmName();
		(void)kdf->AlgorithmProvider();
		(void)kdf->MinDerivedKeyLength();
		(void)kdf->MaxDerivedKeyLength();
	}

	std::string calculated; calculated.resize(expected.size());
	kdf->DeriveKey(BytePtr(calculated), BytePtrSize(calculated), BytePtr(secret), BytePtrSize(secret), pairs);

	if(calculated != expected)
	{
		std::cerr << "Calculated: ";
		StringSource(calculated, true, new HexEncoder(new FileSink(std::cerr)));
		std::cerr << std::endl;

		SignalTestFailure();
	}
}

inline char FirstChar(const std::string& str) {
	if (str.empty()) return 0;
	return str[0];
}

inline char LastChar(const std::string& str) {
	if (str.empty()) return 0;
	return str[str.length()-1];
}

// GetField parses the name/value pairs. If this function is modified,
// then run 'cryptest.exe tv all' to ensure parsing still works.
bool GetField(std::istream &is, std::string &name, std::string &value)
{
	std::string line;
	name.clear(); value.clear();

	// ***** Name *****
	while (Readline(is, line))
	{
		// Eat empty lines and comments gracefully
		line = TrimSpace(line);
		if (line.empty() || line[0] == '#')
			continue;

		std::string::size_type pos = line.find(':');
		if (pos == std::string::npos)
			SignalTestError("Unable to parse name/value pair");

		name = TrimSpace(line.substr(0, pos));
		line = TrimSpace(line.substr(pos +1));

		// Empty name is bad
		if (name.empty())
			return false;

		// Empty value is ok
		if (line.empty())
			return true;

		break;
	}

	// ***** Value *****
	bool continueLine = true;

	do
	{
		continueLine = false;

		// Trim leading and trailing whitespace. Don't parse comments
		// here because there may be a line continuation at the end.
		line = TrimSpace(line);

		if (line.empty())
			continue;

		// Check for continuation. The slash must be the last character.
		if (LastChar(line) == '\\') {
			continueLine = true;
			line.erase(line.end()-1);
		}

		// Re-trim after parsing
		line = TrimComment(line);
		line = TrimSpace(line);

		if (line.empty())
			continue;

		// Finally... the value
		value += line;

		if (continueLine)
			value += ' ';
	}
	while (continueLine && Readline(is, line));

	return true;
}

void OutputPair(const NameValuePairs &v, const char *name)
{
	Integer x;
	bool b = v.GetValue(name, x);
	CRYPTOPP_UNUSED(b); CRYPTOPP_ASSERT(b);
	std::cout << name << ": \\\n    ";
	x.Encode(HexEncoder(new FileSink(std::cout), false, 64, "\\\n    ").Ref(), x.MinEncodedSize());
	std::cout << std::endl;
}

void OutputNameValuePairs(const NameValuePairs &v)
{
	std::string names = v.GetValueNames();
	std::string::size_type i = 0;
	while (i < names.size())
	{
		std::string::size_type j = names.find_first_of (';', i);

		if (j == std::string::npos)
			return;
		else
		{
			std::string name = names.substr(i, j-i);
			if (name.find(':') == std::string::npos)
				OutputPair(v, name.c_str());
		}

		i = j + 1;
	}
}

void TestDataFile(std::string filename, const NameValuePairs &overrideParameters, unsigned int &totalTests, unsigned int &failedTests)
{
	std::ifstream file(DataDir(filename).c_str());
	if (!file.good())
		throw Exception(Exception::OTHER_ERROR, "Can not open file " + DataDir(filename) + " for reading");

	TestData v;
	s_currentTestData = &v;
	std::string name, value, lastAlgName;

	while (file)
	{
		if (!GetField(file, name, value))
			break;

		if (name == "AlgorithmType")
			v.clear();

		// Can't assert value. Plaintext is sometimes empty.
		// CRYPTOPP_ASSERT(!value.empty());
		v[name] = value;

		// The name "Test" is special. It tells the framework
		// to run the test. Otherwise, name/value pairs are
		// parsed and added to TestData 'v'.
		if (name == "Test" && (s_thorough || v["SlowTest"] != "1"))
		{
			bool failed = false;
			std::string algType = GetRequiredDatum(v, "AlgorithmType");
			std::string algName = GetRequiredDatum(v, "Name");

			if (lastAlgName != algName)
			{
				std::cout << "\nTesting " << algType << " algorithm " << algName << ".\n";
				lastAlgName = algName;
			}

			// In the old days each loop ran one test. Later, things were modified to run the
			// the same test twice. Some tests are run with both a StringSource and a FileSource
			// to catch FileSource specific errors. currentTests and deltaTests (below) keep
			// the book keeping in order.
			unsigned int currentTests = totalTests;

			try
			{
				if (algType == "Signature")
				{
					TestSignatureScheme(v, totalTests);
					TestSignatureSchemeWithFileSource(v, totalTests);
				}
				else if (algType == "SymmetricCipher")
				{
					TestSymmetricCipher(v, overrideParameters, totalTests);
					TestSymmetricCipherWithFileSource(v, overrideParameters, totalTests);
				}
				else if (algType == "AuthenticatedSymmetricCipher")
					TestAuthenticatedSymmetricCipher(v, overrideParameters, totalTests);
				else if (algType == "AsymmetricCipher")
					TestAsymmetricCipher(v, totalTests);
				else if (algType == "MessageDigest")
					TestDigestOrMAC(v, true, totalTests);
				else if (algType == "MAC")
					TestDigestOrMAC(v, false, totalTests);
				else if (algType == "KDF")
					TestKeyDerivationFunction(v, totalTests);
				else if (algType == "FileList")
					TestDataFile(GetRequiredDatum(v, "Test"), g_nullNameValuePairs, totalTests, failedTests);
				else
					SignalUnknownAlgorithmError(algType);
			}
			catch (const TestFailure &)
			{
				failed = true;
				std::cout << "\nTest FAILED.\n";
			}
			catch (const Exception &e)
			{
				failed = true;
				std::cout << "\nCryptoPP::Exception caught: " << e.what() << std::endl;
			}
			catch (const std::exception &e)
			{
				failed = true;
				std::cout << "\nstd::exception caught: " << e.what() << std::endl;
			}

			if (failed)
			{
				std::cout << "Skipping to next test." << std::endl;
				failedTests++;
			}
			else
			{
				if (algType != "FileList")
				{
					unsigned int deltaTests = totalTests-currentTests;
					if (deltaTests)
					{
						std::string progress(deltaTests, '.');
						std::cout << progress;
						if (currentTests % 4 == 0)
							std::cout << std::flush;
					}
				}
			}

			// Most tests fully specify parameters, like key and iv. Each test gets
			// its own unique value. Since each test gets a new value for each test
			// case, latching a value in 'TestData v' does not matter. The old key
			// or iv will get overwritten on the next test.
			//
			// If a per-test vector parameter was set for a test, like BlockPadding,
			// BlockSize or Tweak, then it becomes latched in 'TestData v'. The old
			// value is used in subsequent tests, and it could cause a self test
			// failure in the next test. The behavior surfaced under Kalyna and
			// Threefish. The Kalyna test vectors use NO_PADDING for all tests except
			// one. Threefish occasionally uses a Tweak.
			//
			// Unlatch BlockPadding, BlockSize and Tweak now, after the test has been
			// run. Also note we only unlatch from 'TestData v'. If overrideParameters
			// are specified, the caller is responsible for managing the parameter.
			v.erase("Tweak");     v.erase("InitialBlock");
			v.erase("BlockSize"); v.erase("BlockPaddingScheme");
		}
	}
}

ANONYMOUS_NAMESPACE_END

bool RunTestDataFile(const char *filename, const NameValuePairs &overrideParameters, bool thorough)
{
	s_thorough = thorough;
	unsigned int totalTests = 0, failedTests = 0;
	TestDataFile((filename ? filename : ""), overrideParameters, totalTests, failedTests);

	std::cout << std::dec << "\nTests complete. Total tests = " << totalTests << ". Failed tests = " << failedTests << "." << std::endl;
	if (failedTests != 0)
		std::cout << "SOME TESTS FAILED!\n";

	CRYPTOPP_ASSERT(failedTests == 0);
	return failedTests == 0;
}

NAMESPACE_END  // Test
NAMESPACE_END  // CryptoPP
