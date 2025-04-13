// salsa.h - originally written and placed in the public domain by Wei Dai

/// \file salsa.h
/// \brief Classes for Salsa and Salsa20 stream ciphers

#ifndef CRYPTOPP_SALSA_H
#define CRYPTOPP_SALSA_H

#include "strciphr.h"
#include "secblock.h"

// Clang 3.3 integrated assembler crash on Linux. Clang 3.4 due to compiler
// error with .intel_syntax, http://llvm.org/bugs/show_bug.cgi?id=24232
#if CRYPTOPP_BOOL_X32 || defined(CRYPTOPP_DISABLE_MIXED_ASM)
# define CRYPTOPP_DISABLE_SALSA_ASM 1
#endif

NAMESPACE_BEGIN(CryptoPP)

/// \brief Salsa20 core transform
/// \param data the data to transform
/// \param rounds the number of rounds
/// \details Several algorithms, like CryptoBox and Scrypt, require access to
///  the core Salsa20 transform. The current Crypto++ implementation does not
///  lend itself to disgorging the Salsa20 cipher from the Salsa20 core transform.
///  Instead Salsa20_Core is provided with customary accelerations.
void Salsa20_Core(word32* data, unsigned int rounds);

/// \brief Salsa20 stream cipher information
/// \since Crypto++ 5.4
struct Salsa20_Info : public VariableKeyLength<32, 16, 32, 16, SimpleKeyingInterface::UNIQUE_IV, 8>
{
	static std::string StaticAlgorithmName() {return "Salsa20";}
};

/// \brief Salsa20 stream cipher operation
/// \since Crypto++ 5.4
class CRYPTOPP_NO_VTABLE Salsa20_Policy : public AdditiveCipherConcretePolicy<word32, 16>
{
protected:
	Salsa20_Policy() : m_rounds(ROUNDS) {}
	void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length);
	void OperateKeystream(KeystreamOperation operation, byte *output, const byte *input, size_t iterationCount);
	void CipherResynchronize(byte *keystreamBuffer, const byte *IV, size_t length);
	bool CipherIsRandomAccess() const {return true;}
	void SeekToIteration(lword iterationCount);

#if (CRYPTOPP_BOOL_X86 || CRYPTOPP_BOOL_X32 || CRYPTOPP_BOOL_X64)
	unsigned int GetAlignment() const;
	unsigned int GetOptimalBlockSize() const;
#endif

	std::string AlgorithmProvider() const;

	CRYPTOPP_CONSTANT(ROUNDS = 20);  // Default rounds
	FixedSizeAlignedSecBlock<word32, 16> m_state;
	int m_rounds;
};

/// \brief Salsa20 stream cipher
/// \details Salsa20 provides a variable number of rounds: 8, 12 or 20. The default number of rounds is 20.
/// \sa <A HREF="https://cr.yp.to/snuffle/salsafamily-20071225.pdf">The Salsa20
///  family of stream ciphers (20071225)</A>,
///  <A HREF="https://cr.yp.to/snuffle.html">Snuffle 2005: the Salsa20 encryption
///  function</A> and <A HREF="https://www.cryptopp.com/wiki/Salsa20">Salsa20</A>
/// \since Crypto++ 5.4
struct Salsa20 : public Salsa20_Info, public SymmetricCipherDocumentation
{
	typedef SymmetricCipherFinal<ConcretePolicyHolder<Salsa20_Policy, AdditiveCipherTemplate<> >, Salsa20_Info> Encryption;
	typedef Encryption Decryption;
};

/// \brief XSalsa20 stream cipher information
/// \since Crypto++ 5.4
struct XSalsa20_Info : public FixedKeyLength<32, SimpleKeyingInterface::UNIQUE_IV, 24>
{
	static std::string StaticAlgorithmName() {return "XSalsa20";}
};

/// \brief XSalsa20 stream cipher operation
/// \since Crypto++ 5.4
class CRYPTOPP_NO_VTABLE XSalsa20_Policy : public Salsa20_Policy
{
public:
	void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length);
	void CipherResynchronize(byte *keystreamBuffer, const byte *IV, size_t length);

protected:
	FixedSizeSecBlock<word32, 8> m_key;
};

/// \brief XSalsa20 stream cipher
/// \details XSalsa20 provides a variable number of rounds: 8, 12 or 20. The default number of rounds is 20.
/// \sa <a href="http://www.cryptolounge.org/wiki/XSalsa20">XSalsa20</a>
/// \since Crypto++ 5.4
struct XSalsa20 : public XSalsa20_Info, public SymmetricCipherDocumentation
{
	typedef SymmetricCipherFinal<ConcretePolicyHolder<XSalsa20_Policy, AdditiveCipherTemplate<> >, XSalsa20_Info> Encryption;
	typedef Encryption Decryption;
};

NAMESPACE_END

#endif
