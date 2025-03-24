// mersenne.h - written and placed in public domain by Jeffrey Walton.

/// \file mersenne.h
/// \brief Class file for Mersenne Twister
/// \warning MersenneTwister is suitable for Monte-Carlo simulations, where uniformaly distributed
///  numbers are required quickly. It should not be used for cryptographic purposes.
/// \since Crypto++ 5.6.3
#ifndef CRYPTOPP_MERSENNE_TWISTER_H
#define CRYPTOPP_MERSENNE_TWISTER_H

#include "cryptlib.h"
#include "secblock.h"
#include "misc.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Mersenne Twister class for Monte-Carlo simulations
/// \tparam K Magic constant
/// \tparam M Period parameter
/// \tparam N Size of the state vector
/// \tparam F Multiplier constant
/// \tparam S Initial seed
/// \details Provides the MersenneTwister implementation. The class is a header-only implementation.
/// \details You should reseed the generator after a fork() to avoid multiple generators
///  with the same internal state.
/// \warning MersenneTwister is suitable for simulations, where uniformaly distributed numbers are
///  required quickly. It should not be used for cryptographic purposes.
/// \sa MT19937, MT19937ar
/// \since Crypto++ 5.6.3
template <unsigned int K, unsigned int M, unsigned int N, unsigned int F, word32 S>
class MersenneTwister : public RandomNumberGenerator
{
public:
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() { return (S==5489 ? "MT19937ar" : (S==4537 ? "MT19937" : "MT19937x")); }

	~MersenneTwister() {}

	/// \brief Construct a Mersenne Twister
	/// \param seed 32-bit seed
	/// \details Defaults to template parameter S due to changing algorithm
	///  parameters over time
	MersenneTwister(word32 seed = S) : m_idx(N)
	{
		Reset(seed);
	}

	bool CanIncorporateEntropy() const {return true;}

	/// \brief Update RNG state with additional unpredictable values
	/// \param input the entropy to add to the generator
	/// \param length the size of the input buffer
	/// \details MersenneTwister uses the first 32-bits of <tt>input</tt> to reseed the
	///  generator. If fewer bytes are provided, then the seed is padded with 0's.
	void IncorporateEntropy(const byte *input, size_t length)
	{
		// Handle word32 size blocks
		FixedSizeSecBlock<word32, 1> temp;
		temp[0] = 0;

		if (length > 4)
			length = 4;

		for (size_t i=0; i<length; ++i)
		{
			temp[0] <<= 8;
			temp[0] = temp[0] | input[i];
		}

		Reset(temp[0]);
	}

	/// \brief Generate random array of bytes
	/// \param output byte buffer
	/// \param size length of the buffer, in bytes
	/// \details Bytes are written to output in big endian order. If output length
	///  is not a multiple of word32, then unused bytes are not accumulated for subsequent
	///  calls to GenerateBlock. Rather, the unused tail bytes are discarded, and the
	///  stream is continued at the next word32 boundary from the state array.
	void GenerateBlock(byte *output, size_t size)
	{
		// Handle word32 size blocks
		FixedSizeSecBlock<word32, 1> temp;
		for (size_t i=0; i < size/4; i++, output += 4)
		{
			temp[0] = NextMersenneWord();
			std::memcpy(output, temp+0, 4);
		}

		// No tail bytes
		if (size%4 == 0)
			return;

		// Handle tail bytes
		temp[0] = NextMersenneWord();
		switch (size%4)
		{
			case 3: output[2] = CRYPTOPP_GET_BYTE_AS_BYTE(temp[0], 1); /* fall through */
			case 2: output[1] = CRYPTOPP_GET_BYTE_AS_BYTE(temp[0], 2); /* fall through */
			case 1: output[0] = CRYPTOPP_GET_BYTE_AS_BYTE(temp[0], 3); break;

			default: CRYPTOPP_ASSERT(0);;
		}
	}

	/// \brief Generate a random 32-bit word in the range min to max, inclusive
	/// \return random 32-bit word in the range min to max, inclusive
	/// \details If the 32-bit candidate is not within the range, then it is discarded
	///  and a new candidate is used.
	word32 GenerateWord32(word32 min=0, word32 max=0xffffffffL)
	{
		const word32 range = max-min;
		if (range == 0xffffffffL)
			return NextMersenneWord();

		const int maxBits = BitPrecision(range);
		word32 value;

		do{
			value = Crop(NextMersenneWord(), maxBits);
		} while (value > range);

		return value+min;
	}

	/// \brief Generate and discard n bytes
	/// \param n the number of bytes to discard, rounded up to a <tt>word32</tt> size
	/// \details If n is not a multiple of <tt>word32</tt>, then unused bytes are
	///  not accumulated for subsequent calls to GenerateBlock. Rather, the unused
	///  tail bytes are discarded, and the stream is continued at the next
	///  <tt>word32</tt> boundary from the state array.
	void DiscardBytes(size_t n)
	{
		for(size_t i=0; i < RoundUpToMultipleOf(n, 4U); i++)
			NextMersenneWord();
	}

protected:

	void Reset(word32 seed)
	{
		m_idx = N;

		m_state[0] = seed;
		for (unsigned int i = 1; i < N+1; i++)
			m_state[i] = word32(F * (m_state[i-1] ^ (m_state[i-1] >> 30)) + i);
	}

	/// \brief Returns the next 32-bit word from the state array
	/// \return the next 32-bit word from the state array
	/// \details fetches the next word frm the state array, performs bit operations on
	///  it, and then returns the value to the caller.
	word32 NextMersenneWord()
	{
		if (m_idx >= N) { Twist(); }

		word32 temp = m_state[m_idx++];

		temp ^= (temp >> 11);
		temp ^= (temp << 7)  & 0x9D2C5680; // 0x9D2C5680 (2636928640)
		temp ^= (temp << 15) & 0xEFC60000; // 0xEFC60000 (4022730752)

		return temp ^ (temp >> 18);
	}

	/// \brief Performs the twist operation on the state array
	void Twist()
	{
		static const word32 magic[2]={0x0UL, K};
		word32 kk, temp;

		CRYPTOPP_ASSERT(N >= M);
		for (kk=0;kk<N-M;kk++)
		{
			temp = (m_state[kk] & 0x80000000)|(m_state[kk+1] & 0x7FFFFFFF);
			m_state[kk] = m_state[kk+M] ^ (temp >> 1) ^ magic[temp & 0x1UL];
		}

		for (;kk<N-1;kk++)
		{
			temp = (m_state[kk] & 0x80000000)|(m_state[kk+1] & 0x7FFFFFFF);
			m_state[kk] = m_state[kk+(M-N)] ^ (temp >> 1) ^ magic[temp & 0x1UL];
		}

		temp = (m_state[N-1] & 0x80000000)|(m_state[0] & 0x7FFFFFFF);
		m_state[N-1] = m_state[M-1] ^ (temp >> 1) ^ magic[temp & 0x1UL];

		// Reset index
		m_idx = 0;

		// Wipe temp
		SecureWipeArray(&temp, 1);
	}

private:

	/// \brief 32-bit word state array of size N
	FixedSizeSecBlock<word32, N+1> m_state;
	/// \brief the current index into the state array
	word32 m_idx;
};

/// \brief Original MT19937 generator provided in the ACM paper.
/// \details MT19937 uses 4537 as default initial seed.
/// \details You should reseed the generator after a fork() to avoid multiple generators
///  with the same internal state.
/// \sa MT19937ar, <A HREF="http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/ARTICLES/mt.pdf">Mersenne twister:
///  a 623-dimensionally equidistributed uniform pseudo-random number generator</A>
/// \since Crypto++ 5.6.3
#if CRYPTOPP_DOXYGEN_PROCESSING
class MT19937 : public MersenneTwister<0x9908B0DF /*2567483615*/, 397, 624, 0x10DCD /*69069*/, 4537> {};
#else
typedef MersenneTwister<0x9908B0DF /*2567483615*/, 397, 624, 0x10DCD /*69069*/, 4537> MT19937;
#endif

/// \brief Updated MT19937 generator adapted to provide an array for initialization.
/// \details MT19937 uses 5489 as default initial seed. Use this generator when interoperating with C++11's
///  mt19937 class.
/// \details You should reseed the generator after a fork() to avoid multiple generators
///  with the same internal state.
/// \sa MT19937, <A HREF="http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/MT2002/emt19937ar.html">Mersenne Twister
///  with improved initialization</A>
/// \since Crypto++ 5.6.3
#if CRYPTOPP_DOXYGEN_PROCESSING
class MT19937ar : public MersenneTwister<0x9908B0DF /*2567483615*/, 397, 624, 0x6C078965 /*1812433253*/, 5489> {};
#else
typedef MersenneTwister<0x9908B0DF /*2567483615*/, 397, 624, 0x6C078965 /*1812433253*/, 5489> MT19937ar;
#endif

NAMESPACE_END

#endif // CRYPTOPP_MERSENNE_TWISTER_H
