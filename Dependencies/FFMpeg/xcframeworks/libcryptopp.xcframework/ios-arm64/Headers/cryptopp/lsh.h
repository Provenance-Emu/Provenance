// lsh.h - written and placed in the public domain by Jeffrey Walton
//         Based on the specification and source code provided by
//         Korea Internet & Security Agency (KISA) website. Also
//         see https://seed.kisa.or.kr/kisa/algorithm/EgovLSHInfo.do
//         and https://seed.kisa.or.kr/kisa/Board/22/detailView.do.

// We are hitting some sort of GCC bug in the LSH AVX2 code path.
// Clang is OK on the AVX2 code path. We believe it is GCC Issue
// 82735, https://gcc.gnu.org/bugzilla/show_bug.cgi?id=82735. It
// makes using zeroupper a little tricky.

/// \file lsh.h
/// \brief Classes for the LSH hash functions
/// \since Crypto++ 8.6
/// \sa <A HREF="https://seed.kisa.or.kr/kisa/algorithm/EgovLSHInfo.do">LSH</A>
///  on the Korea Internet & Security Agency (KISA) website.
#ifndef CRYPTOPP_LSH_H
#define CRYPTOPP_LSH_H

#include "cryptlib.h"
#include "secblock.h"

// Enable SSE2 and AVX2 for 64-bit machines.
// 32-bit machines slow down with SSE2.
#if (CRYPTOPP_BOOL_X32) || (CRYPTOPP_BOOL_X64)
# define CRYPTOPP_ENABLE_64BIT_SSE 1
#endif

NAMESPACE_BEGIN(CryptoPP)

/// \brief LSH-224 and LSH-256 hash base class
/// \details LSH256_Base is the base class for both LSH-224 and LSH-256
/// \since Crypto++ 8.6
class LSH256_Base : public HashTransformation
{
public:
	/// \brief Block size, in bytes
	/// \details LSH_256 uses LSH256_MSG_BLK_BYTE_LEN for block size, which is 128
	CRYPTOPP_CONSTANT(BLOCKSIZE = 128);

	virtual ~LSH256_Base() {}

	unsigned int BlockSize() const { return BLOCKSIZE; }
	unsigned int DigestSize() const { return m_digestSize; }
	unsigned int OptimalDataAlignment() const { return GetAlignmentOf<word32>(); }

	void Restart();
	void Update(const byte *input, size_t size);
	void TruncatedFinal(byte *hash, size_t size);

	std::string AlgorithmProvider() const;

protected:
	LSH256_Base(unsigned int algType, unsigned int digestSize)
		: m_digestSize(digestSize) { m_state[80] = algType; }

protected:
	// Working state is:
	//   * cv_l = 8 32-bit words
	//   * cv_r = 8 32-bit words
	//   * submsg_e_l = 8 32-bit words
	//   * submsg_e_r = 8 32-bit words
	//   * submsg_o_l = 8 32-bit words
	//   * submsg_o_r = 8 32-bit words
	//   * last_block = 32 32-bit words (128 bytes)
	//   * algType
	//   * remainingBitLength
	FixedSizeSecBlock<word32, 80+2> m_state;
	// word32 m_algType, m_remainingBitLength;
	word32 m_digestSize;
};

/// \brief LSH-224 hash function
/// \sa <A HREF="https://seed.kisa.or.kr/kisa/algorithm/EgovLSHInfo.do">LSH</A>
///  on the Korea Internet & Security Agency (KISA) website.
/// \since Crypto++ 8.6
class LSH224 : public LSH256_Base
{
public:
	/// \brief Digest size, in bytes
	/// \details LSH_256 uses LSH_GET_HASHBYTE(algType) for digest size, which is 28
	CRYPTOPP_CONSTANT(DIGESTSIZE = 28);
	/// \brief Block size, in bytes
	/// \details LSH_256 uses LSH256_MSG_BLK_BYTE_LEN for block size, which is 128
	CRYPTOPP_CONSTANT(BLOCKSIZE = LSH256_Base::BLOCKSIZE);

	/// \brief The algorithm's name
	/// \return the standard algorithm name
	/// \details The standard algorithm name can be a name like <tt>AES</tt> or <tt>AES/GCM</tt>.
	///  Some algorithms do not have standard names yet. For example, there is no standard
	///  algorithm name for Shoup's ECIES.
	/// \note StaticAlgorithmName is not universally implemented yet.
	static std::string StaticAlgorithmName() { return "LSH-224"; }

	/// \brief Construct a LSH-224
	/// \details LSH_TYPE_224 is the magic value 0x000001C defined in lsh.cpp.
	LSH224() : LSH256_Base(0x000001C, DIGESTSIZE) { Restart(); }

	std::string AlgorithmName() const { return StaticAlgorithmName(); }
};

/// \brief LSH-256 hash function
/// \sa <A HREF="https://seed.kisa.or.kr/kisa/algorithm/EgovLSHInfo.do">LSH</A>
///  on the Korea Internet & Security Agency (KISA) website.
/// \since Crypto++ 8.6
class LSH256 : public LSH256_Base
{
public:
	/// \brief Digest size, in bytes
	/// \details LSH_256 uses LSH_GET_HASHBYTE(algType) for digest size, which is 32
	CRYPTOPP_CONSTANT(DIGESTSIZE = 32);
	/// \brief Block size, in bytes
	/// \details LSH_256 uses LSH256_MSG_BLK_BYTE_LEN for block size, which is 128
	CRYPTOPP_CONSTANT(BLOCKSIZE = LSH256_Base::BLOCKSIZE);

	/// \brief The algorithm's name
	/// \return the standard algorithm name
	/// \details The standard algorithm name can be a name like <tt>AES</tt> or <tt>AES/GCM</tt>.
	///  Some algorithms do not have standard names yet. For example, there is no standard
	///  algorithm name for Shoup's ECIES.
	/// \note StaticAlgorithmName is not universally implemented yet.
	static std::string StaticAlgorithmName() { return "LSH-256"; }

	/// \brief Construct a LSH-256
	/// \details LSH_TYPE_256 is the magic value 0x0000020 defined in lsh.cpp.
	LSH256() : LSH256_Base(0x0000020, DIGESTSIZE) { Restart(); }

	std::string AlgorithmName() const { return StaticAlgorithmName(); }
};

/// \brief LSH-384 and LSH-512 hash base class
/// \details LSH512_Base is the base class for both LSH-384 and LSH-512
/// \since Crypto++ 8.6
class LSH512_Base : public HashTransformation
{
public:
	/// \brief Block size, in bytes
	/// \details LSH_512 uses LSH512_MSG_BLK_BYTE_LEN for block size, which is 256
	CRYPTOPP_CONSTANT(BLOCKSIZE = 256);

	virtual ~LSH512_Base() {}

	unsigned int BlockSize() const { return BLOCKSIZE; }
	unsigned int DigestSize() const { return m_digestSize; }
	unsigned int OptimalDataAlignment() const { return GetAlignmentOf<word64>(); }

	void Restart();
	void Update(const byte *input, size_t size);
	void TruncatedFinal(byte *hash, size_t size);

	std::string AlgorithmProvider() const;

protected:
	LSH512_Base(unsigned int algType, unsigned int digestSize)
		: m_digestSize(digestSize) { m_state[80] = algType; }

protected:
	// Working state is:
	//   * cv_l = 8 64-bit words
	//   * cv_r = 8 64-bit words
	//   * submsg_e_l = 8 64-bit words
	//   * submsg_e_r = 8 64-bit words
	//   * submsg_o_l = 8 64-bit words
	//   * submsg_o_r = 8 64-bit words
	//   * last_block = 32 64-bit words (256 bytes)
	//   * algType
	//   * remainingBitLength
	FixedSizeSecBlock<word64, 80+2> m_state;
	// word32 m_algType, m_remainingBitLength;
	word32 m_digestSize;
};

/// \brief LSH-384 hash function
/// \sa <A HREF="https://seed.kisa.or.kr/kisa/algorithm/EgovLSHInfo.do">LSH</A>
///  on the Korea Internet & Security Agency (KISA) website.
/// \since Crypto++ 8.6
class LSH384 : public LSH512_Base
{
public:
	/// \brief Digest size, in bytes
	/// \details LSH_512 uses LSH_GET_HASHBYTE(algType) for digest size, which is 48
	CRYPTOPP_CONSTANT(DIGESTSIZE = 48);
	/// \brief Block size, in bytes
	/// \details LSH_512 uses LSH512_MSG_BLK_BYTE_LEN for block size, which is 256
	CRYPTOPP_CONSTANT(BLOCKSIZE = LSH512_Base::BLOCKSIZE);

	/// \brief The algorithm's name
	/// \return the standard algorithm name
	/// \details The standard algorithm name can be a name like <tt>AES</tt> or <tt>AES/GCM</tt>.
	///  Some algorithms do not have standard names yet. For example, there is no standard
	///  algorithm name for Shoup's ECIES.
	/// \note StaticAlgorithmName is not universally implemented yet.
	static std::string StaticAlgorithmName() { return "LSH-384"; }

	/// \brief Construct a LSH-384
	/// \details LSH_TYPE_384 is the magic value 0x0010030 defined in lsh.cpp.
	LSH384() : LSH512_Base(0x0010030, DIGESTSIZE) { Restart(); }

	std::string AlgorithmName() const { return StaticAlgorithmName(); }
};

/// \brief LSH-512 hash function
/// \sa <A HREF="https://seed.kisa.or.kr/kisa/algorithm/EgovLSHInfo.do">LSH</A>
///  on the Korea Internet & Security Agency (KISA) website.
/// \since Crypto++ 8.6
class LSH512 : public LSH512_Base
{
public:
	/// \brief Digest size, in bytes
	/// \details LSH_512 uses LSH_GET_HASHBYTE(algType) for digest size, which is 64
	CRYPTOPP_CONSTANT(DIGESTSIZE = 64);
	/// \brief Block size, in bytes
	/// \details LSH_512 uses LSH512_MSG_BLK_BYTE_LEN for block size, which is 256
	CRYPTOPP_CONSTANT(BLOCKSIZE = LSH512_Base::BLOCKSIZE);

	/// \brief The algorithm's name
	/// \return the standard algorithm name
	/// \details The standard algorithm name can be a name like <tt>AES</tt> or <tt>AES/GCM</tt>.
	///  Some algorithms do not have standard names yet. For example, there is no standard
	///  algorithm name for Shoup's ECIES.
	/// \note StaticAlgorithmName is not universally implemented yet.
	static std::string StaticAlgorithmName() { return "LSH-512"; }

	/// \brief Construct a LSH-512
	/// \details LSH_TYPE_512 is the magic value 0x0010040 defined in lsh.cpp.
	LSH512() : LSH512_Base(0x0010040, DIGESTSIZE) { Restart(); }

	std::string AlgorithmName() const { return StaticAlgorithmName(); }
};

/// \brief LSH-512-256 hash function
/// \sa <A HREF="https://seed.kisa.or.kr/kisa/algorithm/EgovLSHInfo.do">LSH</A>
///  on the Korea Internet & Security Agency (KISA) website.
/// \since Crypto++ 8.6
class LSH512_256 : public LSH512_Base
{
public:
	/// \brief Digest size, in bytes
	/// \details LSH_512 uses LSH_GET_HASHBYTE(algType) for digest size, which is 32
	CRYPTOPP_CONSTANT(DIGESTSIZE = 32);
	/// \brief Block size, in bytes
	/// \details LSH_512 uses LSH512_MSG_BLK_BYTE_LEN for block size, which is 256
	CRYPTOPP_CONSTANT(BLOCKSIZE = LSH512_Base::BLOCKSIZE);

	/// \brief The algorithm's name
	/// \return the standard algorithm name
	/// \details The standard algorithm name can be a name like <tt>AES</tt> or <tt>AES/GCM</tt>.
	///  Some algorithms do not have standard names yet. For example, there is no standard
	///  algorithm name for Shoup's ECIES.
	/// \note StaticAlgorithmName is not universally implemented yet.
	static std::string StaticAlgorithmName() { return "LSH-512-256"; }

	/// \brief Construct a LSH-512-256
	/// \details LSH_TYPE_512_256 is the magic value 0x0010020 defined in lsh.cpp.
	LSH512_256() : LSH512_Base(0x0010020, DIGESTSIZE) { Restart(); }

	std::string AlgorithmName() const { return StaticAlgorithmName(); }
};

NAMESPACE_END

#endif  // CRYPTOPP_LSH_H
