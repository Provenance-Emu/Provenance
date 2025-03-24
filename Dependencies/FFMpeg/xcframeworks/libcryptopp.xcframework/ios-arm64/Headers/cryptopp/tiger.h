// tiger.h - originally written and placed in the public domain by Wei Dai

/// \file tiger.h
/// \brief Classes for the Tiger message digest
/// \details Crypto++ provides the original Tiger hash that was
///  submitted to the NESSIE project. The implementation is different
///  from the revised Tiger2 hash.
/// \sa <a href="https://www.cryptopp.com/wiki/Tiger">Tiger</a> and
///  <a href="http://www.cs.technion.ac.il/~biham/Reports/Tiger/">Tiger:
///  A Fast New Cryptographic Hash Function</a>
/// \since Crypto++ 2.1

#ifndef CRYPTOPP_TIGER_H
#define CRYPTOPP_TIGER_H

#include "config.h"
#include "iterhash.h"

// Clang 3.3 integrated assembler crash on Linux. Clang 3.4 due to compiler
// error with .intel_syntax, http://llvm.org/bugs/show_bug.cgi?id=24232
#if CRYPTOPP_BOOL_X32 || defined(CRYPTOPP_DISABLE_MIXED_ASM)
# define CRYPTOPP_DISABLE_TIGER_ASM 1
#endif

NAMESPACE_BEGIN(CryptoPP)

/// \brief Tiger message digest
/// \details Crypto++ provides the original Tiger hash that was
///  submitted to the NESSIE project. The implementation is different
///  from the revised Tiger2 hash.
/// \sa <a href="https://www.cryptopp.com/wiki/Tiger">Tiger</a> and
///  <a href="http://www.cs.technion.ac.il/~biham/Reports/Tiger/">Tiger:
///  A Fast New Cryptographic Hash Function</a>
/// \since Crypto++ 2.1
class Tiger : public IteratedHashWithStaticTransform<word64, LittleEndian, 64, 24, Tiger>
{
public:
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "Tiger";}
	std::string AlgorithmProvider() const;

	/// \brief Initialize state array
	/// \param state the state of the hash
	static void InitState(HashWordType *state);
	/// \brief Operate the hash
	/// \param digest the state of the hash
	/// \param data the data to be digested
	static void Transform(word64 *digest, const word64 *data);
	/// \brief Computes the hash of the current message
	/// \param digest a pointer to the buffer to receive the hash
	/// \param digestSize the size of the truncated digest, in bytes
	/// \details TruncatedFinal() calls Final() and then copies digestSize bytes to digest.
	///   The hash is restarted the hash for the next message.
	void TruncatedFinal(byte *digest, size_t digestSize);

protected:
	static const word64 table[4*256+3];
};

NAMESPACE_END

#endif
