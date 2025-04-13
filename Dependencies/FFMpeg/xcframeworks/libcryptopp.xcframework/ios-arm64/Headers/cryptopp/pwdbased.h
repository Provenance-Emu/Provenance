// pwdbased.h - originally written and placed in the public domain by Wei Dai
//              Cutover to KeyDerivationFunction interface by Uri Blumenthal
//              Marcel Raad and Jeffrey Walton in March 2018.

/// \file pwdbased.h
/// \brief Password based key derivation functions

#ifndef CRYPTOPP_PWDBASED_H
#define CRYPTOPP_PWDBASED_H

#include "cryptlib.h"
#include "hrtimer.h"
#include "integer.h"
#include "argnames.h"
#include "algparam.h"
#include "hmac.h"

NAMESPACE_BEGIN(CryptoPP)

// ******************** PBKDF1 ********************

/// \brief PBKDF1 from PKCS #5
/// \tparam T a HashTransformation class
/// \sa PasswordBasedKeyDerivationFunction, <A
///  HREF="https://www.cryptopp.com/wiki/PKCS5_PBKDF1">PKCS5_PBKDF1</A>
///  on the Crypto++ wiki
/// \since Crypto++ 2.0
template <class T>
class PKCS5_PBKDF1 : public PasswordBasedKeyDerivationFunction
{
public:
	virtual ~PKCS5_PBKDF1() {}

	static std::string StaticAlgorithmName () {
		const std::string name(std::string("PBKDF1(") +
			std::string(T::StaticAlgorithmName()) + std::string(")"));
		return name;
	}

	// KeyDerivationFunction interface
	std::string AlgorithmName() const {
		return StaticAlgorithmName();
	}

	// KeyDerivationFunction interface
	size_t MaxDerivedKeyLength() const {
		return static_cast<size_t>(T::DIGESTSIZE);
	}

	// KeyDerivationFunction interface
	size_t GetValidDerivedLength(size_t keylength) const;

	// KeyDerivationFunction interface
	virtual size_t DeriveKey(byte *derived, size_t derivedLen, const byte *secret, size_t secretLen,
		const NameValuePairs& params = g_nullNameValuePairs) const;

	/// \brief Derive a key from a secret seed
	/// \param derived the derived output buffer
	/// \param derivedLen the size of the derived buffer, in bytes
	/// \param purpose a purpose byte
	/// \param secret the seed input buffer
	/// \param secretLen the size of the secret buffer, in bytes
	/// \param salt the salt input buffer
	/// \param saltLen the size of the salt buffer, in bytes
	/// \param iterations the number of iterations
	/// \param timeInSeconds the in seconds
	/// \return the number of iterations performed
	/// \throw InvalidDerivedKeyLength if <tt>derivedLen</tt> is invalid for the scheme
	/// \details DeriveKey() provides a standard interface to derive a key from
	///   a seed and other parameters. Each class that derives from KeyDerivationFunction
	///   provides an overload that accepts most parameters used by the derivation function.
	/// \details If <tt>timeInSeconds</tt> is <tt>&gt; 0.0</tt> then DeriveKey will run for
	///   the specified amount of time. If <tt>timeInSeconds</tt> is <tt>0.0</tt> then DeriveKey
	///   will run for the specified number of iterations.
	/// \details PKCS #5 says PBKDF1 should only take 8-byte salts. This implementation
	///   allows salts of any length.
	size_t DeriveKey(byte *derived, size_t derivedLen, byte purpose, const byte *secret, size_t secretLen, const byte *salt, size_t saltLen, unsigned int iterations, double timeInSeconds=0) const;

protected:
	// KeyDerivationFunction interface
	const Algorithm & GetAlgorithm() const {
		return *this;
	}
};

template <class T>
size_t PKCS5_PBKDF1<T>::GetValidDerivedLength(size_t keylength) const
{
	if (keylength > MaxDerivedKeyLength())
		return MaxDerivedKeyLength();
	return keylength;
}

template <class T>
size_t PKCS5_PBKDF1<T>::DeriveKey(byte *derived, size_t derivedLen,
    const byte *secret, size_t secretLen, const NameValuePairs& params) const
{
	CRYPTOPP_ASSERT(secret /*&& secretLen*/);
	CRYPTOPP_ASSERT(derived && derivedLen);
	CRYPTOPP_ASSERT(derivedLen <= MaxDerivedKeyLength());

	byte purpose = (byte)params.GetIntValueWithDefault("Purpose", 0);
	unsigned int iterations = (unsigned int)params.GetIntValueWithDefault("Iterations", 1);

	double timeInSeconds = 0.0f;
	(void)params.GetValue("TimeInSeconds", timeInSeconds);

	ConstByteArrayParameter salt;
	(void)params.GetValue(Name::Salt(), salt);

	return DeriveKey(derived, derivedLen, purpose, secret, secretLen, salt.begin(), salt.size(), iterations, timeInSeconds);
}

template <class T>
size_t PKCS5_PBKDF1<T>::DeriveKey(byte *derived, size_t derivedLen, byte purpose, const byte *secret, size_t secretLen, const byte *salt, size_t saltLen, unsigned int iterations, double timeInSeconds) const
{
	CRYPTOPP_ASSERT(secret /*&& secretLen*/);
	CRYPTOPP_ASSERT(derived && derivedLen);
	CRYPTOPP_ASSERT(derivedLen <= MaxDerivedKeyLength());
	CRYPTOPP_ASSERT(iterations > 0 || timeInSeconds > 0);
	CRYPTOPP_UNUSED(purpose);

	ThrowIfInvalidDerivedKeyLength(derivedLen);

	// Business logic
	if (!iterations) { iterations = 1; }

	T hash;
	hash.Update(secret, secretLen);
	hash.Update(salt, saltLen);

	SecByteBlock buffer(hash.DigestSize());
	hash.Final(buffer);

	unsigned int i;
	ThreadUserTimer timer;

	if (timeInSeconds)
		timer.StartTimer();

	for (i=1; i<iterations || (timeInSeconds && (i%128!=0 || timer.ElapsedTimeAsDouble() < timeInSeconds)); i++)
		hash.CalculateDigest(buffer, buffer, buffer.size());

	if (derived)
		std::memcpy(derived, buffer, derivedLen);
	return i;
}

// ******************** PKCS5_PBKDF2_HMAC ********************

/// \brief PBKDF2 from PKCS #5
/// \tparam T a HashTransformation class
/// \sa PasswordBasedKeyDerivationFunction, <A
///  HREF="https://www.cryptopp.com/wiki/PKCS5_PBKDF2_HMAC">PKCS5_PBKDF2_HMAC</A>
///  on the Crypto++ wiki
/// \since Crypto++ 2.0
template <class T>
class PKCS5_PBKDF2_HMAC : public PasswordBasedKeyDerivationFunction
{
public:
	virtual ~PKCS5_PBKDF2_HMAC() {}

	static std::string StaticAlgorithmName () {
		const std::string name(std::string("PBKDF2_HMAC(") +
			std::string(T::StaticAlgorithmName()) + std::string(")"));
		return name;
	}

	// KeyDerivationFunction interface
	std::string AlgorithmName() const {
		return StaticAlgorithmName();
	}

	// KeyDerivationFunction interface
	// should multiply by T::DIGESTSIZE, but gets overflow that way
	size_t MaxDerivedKeyLength() const {
		return 0xffffffffU;
	}

	// KeyDerivationFunction interface
	size_t GetValidDerivedLength(size_t keylength) const;

	// KeyDerivationFunction interface
	size_t DeriveKey(byte *derived, size_t derivedLen, const byte *secret, size_t secretLen,
		const NameValuePairs& params = g_nullNameValuePairs) const;

	/// \brief Derive a key from a secret seed
	/// \param derived the derived output buffer
	/// \param derivedLen the size of the derived buffer, in bytes
	/// \param purpose a purpose byte
	/// \param secret the seed input buffer
	/// \param secretLen the size of the secret buffer, in bytes
	/// \param salt the salt input buffer
	/// \param saltLen the size of the salt buffer, in bytes
	/// \param iterations the number of iterations
	/// \param timeInSeconds the in seconds
	/// \return the number of iterations performed
	/// \throw InvalidDerivedKeyLength if <tt>derivedLen</tt> is invalid for the scheme
	/// \details DeriveKey() provides a standard interface to derive a key from
	///   a seed and other parameters. Each class that derives from KeyDerivationFunction
	///   provides an overload that accepts most parameters used by the derivation function.
	/// \details If <tt>timeInSeconds</tt> is <tt>&gt; 0.0</tt> then DeriveKey will run for
	///   the specified amount of time. If <tt>timeInSeconds</tt> is <tt>0.0</tt> then DeriveKey
	///   will run for the specified number of iterations.
	size_t DeriveKey(byte *derived, size_t derivedLen, byte purpose, const byte *secret, size_t secretLen,
	    const byte *salt, size_t saltLen, unsigned int iterations, double timeInSeconds=0) const;

protected:
	// KeyDerivationFunction interface
	const Algorithm & GetAlgorithm() const {
		return *this;
	}
};

template <class T>
size_t PKCS5_PBKDF2_HMAC<T>::GetValidDerivedLength(size_t keylength) const
{
	if (keylength > MaxDerivedKeyLength())
		return MaxDerivedKeyLength();
	return keylength;
}

template <class T>
size_t PKCS5_PBKDF2_HMAC<T>::DeriveKey(byte *derived, size_t derivedLen,
    const byte *secret, size_t secretLen, const NameValuePairs& params) const
{
	CRYPTOPP_ASSERT(secret /*&& secretLen*/);
	CRYPTOPP_ASSERT(derived && derivedLen);
	CRYPTOPP_ASSERT(derivedLen <= MaxDerivedKeyLength());

	byte purpose = (byte)params.GetIntValueWithDefault("Purpose", 0);
	unsigned int iterations = (unsigned int)params.GetIntValueWithDefault("Iterations", 1);

	double timeInSeconds = 0.0f;
	(void)params.GetValue("TimeInSeconds", timeInSeconds);

	ConstByteArrayParameter salt;
	(void)params.GetValue(Name::Salt(), salt);

	return DeriveKey(derived, derivedLen, purpose, secret, secretLen, salt.begin(), salt.size(), iterations, timeInSeconds);
}

template <class T>
size_t PKCS5_PBKDF2_HMAC<T>::DeriveKey(byte *derived, size_t derivedLen, byte purpose, const byte *secret, size_t secretLen, const byte *salt, size_t saltLen, unsigned int iterations, double timeInSeconds) const
{
	CRYPTOPP_ASSERT(secret /*&& secretLen*/);
	CRYPTOPP_ASSERT(derived && derivedLen);
	CRYPTOPP_ASSERT(derivedLen <= MaxDerivedKeyLength());
	CRYPTOPP_ASSERT(iterations > 0 || timeInSeconds > 0);
	CRYPTOPP_UNUSED(purpose);

	ThrowIfInvalidDerivedKeyLength(derivedLen);

	// Business logic
	if (!iterations) { iterations = 1; }

	// DigestSize check due to https://github.com/weidai11/cryptopp/issues/855
	HMAC<T> hmac(secret, secretLen);
	if (hmac.DigestSize() == 0)
		throw InvalidArgument("PKCS5_PBKDF2_HMAC: DigestSize cannot be 0");

	SecByteBlock buffer(hmac.DigestSize());
	ThreadUserTimer timer;

	unsigned int i=1;
	while (derivedLen > 0)
	{
		hmac.Update(salt, saltLen);
		unsigned int j;
		for (j=0; j<4; j++)
		{
			byte b = byte(i >> ((3-j)*8));
			hmac.Update(&b, 1);
		}
		hmac.Final(buffer);

#if CRYPTOPP_MSC_VERSION
		const size_t segmentLen = STDMIN(derivedLen, buffer.size());
		memcpy_s(derived, segmentLen, buffer, segmentLen);
#else
		const size_t segmentLen = STDMIN(derivedLen, buffer.size());
		std::memcpy(derived, buffer, segmentLen);
#endif

		if (timeInSeconds)
		{
			timeInSeconds = timeInSeconds / ((derivedLen + buffer.size() - 1) / buffer.size());
			timer.StartTimer();
		}

		for (j=1; j<iterations || (timeInSeconds && (j%128!=0 || timer.ElapsedTimeAsDouble() < timeInSeconds)); j++)
		{
			hmac.CalculateDigest(buffer, buffer, buffer.size());
			xorbuf(derived, buffer, segmentLen);
		}

		if (timeInSeconds)
		{
			iterations = j;
			timeInSeconds = 0;
		}

		derived += segmentLen;
		derivedLen -= segmentLen;
		i++;
	}

	return iterations;
}

// ******************** PKCS12_PBKDF ********************

/// \brief PBKDF from PKCS #12, appendix B
/// \tparam T a HashTransformation class
/// \sa PasswordBasedKeyDerivationFunction, <A
///  HREF="https://www.cryptopp.com/wiki/PKCS12_PBKDF">PKCS12_PBKDF</A>
///  on the Crypto++ wiki
/// \since Crypto++ 2.0
template <class T>
class PKCS12_PBKDF : public PasswordBasedKeyDerivationFunction
{
public:
	virtual ~PKCS12_PBKDF() {}

	static std::string StaticAlgorithmName () {
		const std::string name(std::string("PBKDF_PKCS12(") +
			std::string(T::StaticAlgorithmName()) + std::string(")"));
		return name;
	}

	// KeyDerivationFunction interface
	std::string AlgorithmName() const {
		return StaticAlgorithmName();
	}

	// TODO - check this
	size_t MaxDerivedKeyLength() const {
		return static_cast<size_t>(-1);
	}

	// KeyDerivationFunction interface
	size_t GetValidDerivedLength(size_t keylength) const;

	// KeyDerivationFunction interface
	size_t DeriveKey(byte *derived, size_t derivedLen, const byte *secret, size_t secretLen,
		const NameValuePairs& params = g_nullNameValuePairs) const;

	/// \brief Derive a key from a secret seed
	/// \param derived the derived output buffer
	/// \param derivedLen the size of the derived buffer, in bytes
	/// \param purpose a purpose byte
	/// \param secret the seed input buffer
	/// \param secretLen the size of the secret buffer, in bytes
	/// \param salt the salt input buffer
	/// \param saltLen the size of the salt buffer, in bytes
	/// \param iterations the number of iterations
	/// \param timeInSeconds the in seconds
	/// \return the number of iterations performed
	/// \throw InvalidDerivedKeyLength if <tt>derivedLen</tt> is invalid for the scheme
	/// \details DeriveKey() provides a standard interface to derive a key from
	///   a seed and other parameters. Each class that derives from KeyDerivationFunction
	///   provides an overload that accepts most parameters used by the derivation function.
	/// \details If <tt>timeInSeconds</tt> is <tt>&gt; 0.0</tt> then DeriveKey will run for
	///   the specified amount of time. If <tt>timeInSeconds</tt> is <tt>0.0</tt> then DeriveKey
	///   will run for the specified number of iterations.
	size_t DeriveKey(byte *derived, size_t derivedLen, byte purpose, const byte *secret, size_t secretLen,
	    const byte *salt, size_t saltLen, unsigned int iterations, double timeInSeconds) const;

protected:
	// KeyDerivationFunction interface
	const Algorithm & GetAlgorithm() const {
		return *this;
	}
};

template <class T>
size_t PKCS12_PBKDF<T>::GetValidDerivedLength(size_t keylength) const
{
	if (keylength > MaxDerivedKeyLength())
		return MaxDerivedKeyLength();
	return keylength;
}

template <class T>
size_t PKCS12_PBKDF<T>::DeriveKey(byte *derived, size_t derivedLen,
    const byte *secret, size_t secretLen, const NameValuePairs& params) const
{
	CRYPTOPP_ASSERT(secret /*&& secretLen*/);
	CRYPTOPP_ASSERT(derived && derivedLen);
	CRYPTOPP_ASSERT(derivedLen <= MaxDerivedKeyLength());

	byte purpose = (byte)params.GetIntValueWithDefault("Purpose", 0);
	unsigned int iterations = (unsigned int)params.GetIntValueWithDefault("Iterations", 1);

	double timeInSeconds = 0.0f;
	(void)params.GetValue("TimeInSeconds", timeInSeconds);

	// NULL or 0 length salt OK
	ConstByteArrayParameter salt;
	(void)params.GetValue(Name::Salt(), salt);

	return DeriveKey(derived, derivedLen, purpose, secret, secretLen, salt.begin(), salt.size(), iterations, timeInSeconds);
}

template <class T>
size_t PKCS12_PBKDF<T>::DeriveKey(byte *derived, size_t derivedLen, byte purpose, const byte *secret, size_t secretLen, const byte *salt, size_t saltLen, unsigned int iterations, double timeInSeconds) const
{
	CRYPTOPP_ASSERT(secret /*&& secretLen*/);
	CRYPTOPP_ASSERT(derived && derivedLen);
	CRYPTOPP_ASSERT(derivedLen <= MaxDerivedKeyLength());
	CRYPTOPP_ASSERT(iterations > 0 || timeInSeconds > 0);

	ThrowIfInvalidDerivedKeyLength(derivedLen);

	// Business logic
	if (!iterations) { iterations = 1; }

	const size_t v = T::BLOCKSIZE;	// v is in bytes rather than bits as in PKCS #12
	const size_t DLen = v, SLen = RoundUpToMultipleOf(saltLen, v);
	const size_t PLen = RoundUpToMultipleOf(secretLen, v), ILen = SLen + PLen;
	SecByteBlock buffer(DLen + SLen + PLen);
	byte *D = buffer, *S = buffer+DLen, *P = buffer+DLen+SLen, *I = S;

	if (D)  // GCC analyzer
		std::memset(D, purpose, DLen);

	size_t i;
	for (i=0; i<SLen; i++)
		S[i] = salt[i % saltLen];
	for (i=0; i<PLen; i++)
		P[i] = secret[i % secretLen];

	T hash;
	SecByteBlock Ai(T::DIGESTSIZE), B(v);
	ThreadUserTimer timer;

	while (derivedLen > 0)
	{
		hash.CalculateDigest(Ai, buffer, buffer.size());

		if (timeInSeconds)
		{
			timeInSeconds = timeInSeconds / ((derivedLen + Ai.size() - 1) / Ai.size());
			timer.StartTimer();
		}

		for (i=1; i<iterations || (timeInSeconds && (i%128!=0 || timer.ElapsedTimeAsDouble() < timeInSeconds)); i++)
			hash.CalculateDigest(Ai, Ai, Ai.size());

		if (timeInSeconds)
		{
			iterations = (unsigned int)i;
			timeInSeconds = 0;
		}

		for (i=0; i<B.size(); i++)
			B[i] = Ai[i % Ai.size()];

		Integer B1(B, B.size());
		++B1;
		for (i=0; i<ILen; i+=v)
			(Integer(I+i, v) + B1).Encode(I+i, v);

#if CRYPTOPP_MSC_VERSION
		const size_t segmentLen = STDMIN(derivedLen, Ai.size());
		memcpy_s(derived, segmentLen, Ai, segmentLen);
#else
		const size_t segmentLen = STDMIN(derivedLen, Ai.size());
		std::memcpy(derived, Ai, segmentLen);
#endif

		derived += segmentLen;
		derivedLen -= segmentLen;
	}

	return iterations;
}

NAMESPACE_END

#endif
