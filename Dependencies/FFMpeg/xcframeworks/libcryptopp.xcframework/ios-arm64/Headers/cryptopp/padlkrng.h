// via-rng.h - written and placed in public domain by Jeffrey Walton

/// \file padlkrng.h
/// \brief Classes for VIA Padlock RNG
/// \since Crypto++ 6.0
/// \sa <A HREF="http://www.cryptopp.com/wiki/VIA_Padlock">VIA
///   Padlock</A> on the Crypto++ wiki

#ifndef CRYPTOPP_PADLOCK_RNG_H
#define CRYPTOPP_PADLOCK_RNG_H

#include "cryptlib.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Exception thrown when a PadlockRNG generator encounters
///	a generator related error.
/// \since Crypto++ 6.0
class PadlockRNG_Err : public Exception
{
public:
	PadlockRNG_Err(const std::string &operation)
		: Exception(OTHER_ERROR, "PadlockRNG: " + operation + " operation failed") {}
	PadlockRNG_Err(const std::string &component, const std::string &message)
		: Exception(OTHER_ERROR, component + ": " + message) {}
};

/// \brief Hardware generated random numbers using VIA XSTORE
/// \details Some VIA processors provide a Security Engine called Padlock. The Padlock
///   Security Engine provides AES, SHA and a RNG. The PadlockRNG class provides access
///   to the RNG.
/// \details The VIA generator uses an 8 byte FIFO buffer for random numbers. The
///   generator can be configured to discard bits from the buffer to resist analysis.
///   The <tt>divisor</tt> controls the number of bytes discarded. The formula for
///   the discard amount is <tt>2**divisor - 1</tt>. When <tt>divisor=0</tt> no bits
///   are discarded and the entire 8 byte buffer is read. If <tt>divisor=3</tt> then
///   7 bytes are discarded and 1 byte is read. TheVIA SDK samples use <tt>divisor=1</tt>.
/// \details Cryptography Research, Inc (CRI) audited the Padlock Security Engine
///   in 2003. CRI provided recommendations to operate the generator for secure and
///   non-secure applications. Additionally, the Programmers Guide and SDK provided a
///   different configuration in the sample code.
/// \details You can operate the generator according to CRI recommendations by setting
///   <tt>divisor</tt>, reading one word (or partial word) at a time from the FIFO, and
///   then inspecting the MSR after each read.
/// \details The audit report with recommendations is available on the Crypto++ wiki
///   at <A HREF="http://www.cryptopp.com/wiki/VIA_Padlock">VIA Padlock</A>.
/// \sa MaurerRandomnessTest() for random bit generators
/// \since Crypto++ 6.0
class PadlockRNG : public RandomNumberGenerator
{
public:
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() { return "PadlockRNG"; }

	virtual ~PadlockRNG() {}

	/// \brief Construct a PadlockRNG generator
	/// \param divisor the XSTORE divisor
	/// \details Some VIA processors provide a Security Engine called Padlock. The Padlock
	///   Security Engine provides AES, SHA and a RNG. The PadlockRNG class provides access
	///   to the RNG.
	/// \details The VIA generator uses an 8 byte FIFO buffer for random numbers. The
	///   generator can be configured to discard bits from the buffer to resist analysis.
	///   The <tt>divisor</tt> controls the number of bytes discarded. The formula for
	///   the discard amount is <tt>2**divisor - 1</tt>. When <tt>divisor=0</tt> no bits
	///   are discarded and the entire 8 byte buffer is read. If <tt>divisor=3</tt> then
	///   7 bytes are discarded and 1 byte is read. VIA SDK samples use <tt>divisor=1</tt>.
	/// \details Cryptography Research, Inc (CRI) audited the Padlock Security Engine
	///   in 2003. CRI provided recommendations to operate the generator for secure and
	///   non-secure applications. Additionally, the Programmers SDK provided a different
	///   configuration in the sample code.
	/// \details The audit report with recommendations is available on the Crypto++ wiki
	///   at <A HREF="http://www.cryptopp.com/wiki/VIA_Padlock">VIA Padlock</A>.
	/// \sa SetDivisor, GetDivisor
	PadlockRNG(word32 divisor=1);

	/// \brief Generate random array of bytes
	/// \param output the byte buffer
	/// \param size the length of the buffer, in bytes
	virtual void GenerateBlock(byte *output, size_t size);

	/// \brief Generate and discard n bytes
	/// \param n the number of bytes to generate and discard
	/// \details the Padlock generator discards words, not bytes. If n is
	///   not a multiple of a 32-bit word, then it is rounded up to
	///   that size.
	virtual void DiscardBytes(size_t n);

	/// \brief Update RNG state with additional unpredictable values
	/// \param input unused
	/// \param length unused
	/// \details The operation is a nop for this generator.
	virtual void IncorporateEntropy(const byte *input, size_t length)
	{
		// Override to avoid the base class' throw.
		CRYPTOPP_UNUSED(input); CRYPTOPP_UNUSED(length);
	}

    std::string AlgorithmProvider() const;

	/// \brief Set the XSTORE divisor
	/// \param divisor the XSTORE divisor
	/// \return the old XSTORE divisor
	word32 SetDivisor(word32 divisor)
	{
		word32 old = m_divisor;
		m_divisor = DivisorHelper(divisor);
		return old;
	}

	/// \brief Get the XSTORE divisor
	/// \return the current XSTORE divisor
	word32 GetDivisor() const
	{
		return m_divisor;
	}

	/// \brief Get the MSR for the last operation
	/// \return the MSR for the last read operation
	word32 GetMSR() const
	{
		return m_msr;
	}

protected:
	inline word32 DivisorHelper(word32 divisor)
	{
		return divisor > 3 ? 3 : divisor;
	}

private:
	FixedSizeAlignedSecBlock<word32, 4, true> m_buffer;
	word32 m_divisor, m_msr;
};

NAMESPACE_END

#endif  // CRYPTOPP_PADLOCK_RNG_H
