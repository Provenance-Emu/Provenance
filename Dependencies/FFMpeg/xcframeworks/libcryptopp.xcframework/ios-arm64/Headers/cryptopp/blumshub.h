// blumshub.h - originally written and placed in the public domain by Wei Dai

/// \file blumshub.h
/// \brief Classes for Blum Blum Shub generator

#ifndef CRYPTOPP_BLUMSHUB_H
#define CRYPTOPP_BLUMSHUB_H

#include "cryptlib.h"
#include "modarith.h"
#include "integer.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief BlumBlumShub without factorization of the modulus
/// \details You should reseed the generator after a fork() to avoid multiple generators
///  with the same internal state.
class PublicBlumBlumShub : public RandomNumberGenerator,
						   public StreamTransformation
{
public:
	virtual ~PublicBlumBlumShub() {}

	/// \brief Construct a PublicBlumBlumShub
	/// \param n the modulus
	/// \param seed the seed for the generator
	/// \details seed is the secret key and should be about as large as n.
	PublicBlumBlumShub(const Integer &n, const Integer &seed);

	unsigned int GenerateBit();
	byte GenerateByte();
	void GenerateBlock(byte *output, size_t size);
	void ProcessData(byte *outString, const byte *inString, size_t length);

	bool IsSelfInverting() const {return true;}
	bool IsForwardTransformation() const {return true;}

protected:
	ModularArithmetic modn;
	Integer current;
	word maxBits, bitsLeft;
};

/// \brief BlumBlumShub with factorization of the modulus
/// \details You should reseed the generator after a fork() to avoid multiple generators
///  with the same internal state.
class BlumBlumShub : public PublicBlumBlumShub
{
public:
	virtual ~BlumBlumShub() {}

	/// \brief Construct a BlumBlumShub
	/// \param p the first prime factor
	/// \param q the second prime factor
	/// \param seed the seed for the generator
	/// \details Esure p and q are both primes congruent to 3 mod 4 and at least 512 bits long.
	///  seed is the secret key and should be about as large as p*q.
	BlumBlumShub(const Integer &p, const Integer &q, const Integer &seed);

	bool IsRandomAccess() const {return true;}
	void Seek(lword index);

protected:
	const Integer p, q;
	const Integer x0;
};

NAMESPACE_END

#endif
