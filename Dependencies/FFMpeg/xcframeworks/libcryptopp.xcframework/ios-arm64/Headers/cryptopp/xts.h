// xts.h - written and placed in the public domain by Jeffrey Walton

/// \file xts.h
/// \brief Classes for XTS block cipher mode of operation
/// \details XTS mode is a wide block mode defined by IEEE P1619-2008. NIST
///  SP-800-38E approves the mode for storage devices citing IEEE 1619-2007.
///  IEEE 1619-2007 provides both a reference implementation and test vectors.
///  The IEEE reference implementation fails to arrive at the expected result
///  for some test vectors.
/// \sa <A HREF="http://www.cryptopp.com/wiki/Modes_of_Operation">Modes of
///  Operation</A> on the Crypto++ wiki, <A
///  HREF="https://web.cs.ucdavis.edu/~rogaway/papers/modes.pdf"> Evaluation of Some
///  Blockcipher Modes of Operation</A>, <A
///  HREF="https://csrc.nist.gov/publications/detail/sp/800-38e/final">Recommendation
///  for Block Cipher Modes of Operation: The XTS-AES Mode for Confidentiality on
///  Storage Devices</A>, <A
///  HREF="http://libeccio.di.unisa.it/Crypto14/Lab/p1619.pdf">IEEE P1619-2007</A>
///  and <A HREF="https://crypto.stackexchange.com/q/74925/10496">IEEE P1619/XTS,
///  inconsistent reference implementation and test vectors</A>.
/// \since Crypto++ 8.3

#ifndef CRYPTOPP_XTS_MODE_H
#define CRYPTOPP_XTS_MODE_H

#include "cryptlib.h"
#include "secblock.h"
#include "modes.h"
#include "misc.h"

/// \brief Enable XTS for wide block ciphers
/// \details XTS is only defined for AES. The library can support wide
///  block ciphers like Kaylna and Threefish since we know the polynomials.
///  To enable wide block ciphers define <tt>CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS</tt>
///  to non-zero. Note this is a library compile time define.
/// \details There is risk involved with using XTS with wider block ciphers.
///  According to Phillip Rogaway, "The narrow width of the underlying PRP and
///  the poor treatment of fractional final blocks are problems."
/// \sa <A HREF="https://web.cs.ucdavis.edu/~rogaway/papers/modes.pdf">Evaluation
///  of Some Blockcipher Modes of Operation</A>
/// \since Crypto++ 8.3
#ifndef CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS
# define CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS 0
#endif  // CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS

NAMESPACE_BEGIN(CryptoPP)

/// \brief XTS block cipher mode of operation default implementation
/// \since Crypto++ 8.3
class CRYPTOPP_NO_VTABLE XTS_ModeBase : public BlockOrientedCipherModeBase
{
public:
    /// \brief The algorithm name
    /// \return the algorithm name
    /// \details StaticAlgorithmName returns the algorithm's name as a static
    ///  member function.
    CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName()
        {return "XTS";}

    virtual ~XTS_ModeBase() {}

    std::string AlgorithmName() const
        {return GetBlockCipher().AlgorithmName() + "/XTS";}
    std::string AlgorithmProvider() const
        {return GetBlockCipher().AlgorithmProvider();}

    size_t MinKeyLength() const
        {return GetBlockCipher().MinKeyLength()*2;}
    size_t MaxKeyLength() const
        {return GetBlockCipher().MaxKeyLength()*2;}
    size_t DefaultKeyLength() const
        {return GetBlockCipher().DefaultKeyLength()*2;}
    size_t GetValidKeyLength(size_t n) const
        {return 2*GetBlockCipher().GetValidKeyLength((n+1)/2);}
    bool IsValidKeyLength(size_t keylength) const
        {return keylength == GetValidKeyLength(keylength);}

    /// \brief Validates the key length
    /// \param length the size of the keying material, in bytes
    /// \throw InvalidKeyLength if the key length is invalid
    void ThrowIfInvalidKeyLength(size_t length);

    /// Provides the block size of the cipher
    /// \return the block size of the cipher, in bytes
    unsigned int BlockSize() const
        {return GetBlockCipher().BlockSize();}

    /// \brief Provides the input block size most efficient for this cipher
    /// \return The input block size that is most efficient for the cipher
    /// \details The base class implementation returns MandatoryBlockSize().
    /// \note Optimal input length is
    ///  <tt>n * OptimalBlockSize() - GetOptimalBlockSizeUsed()</tt> for
    ///  any <tt>n \> 0</tt>.
    unsigned int GetOptimalBlockSize() const
        {return GetBlockCipher().BlockSize()*ParallelBlocks;}
    unsigned int MinLastBlockSize() const
        {return GetBlockCipher().BlockSize()+1;}
    unsigned int OptimalDataAlignment() const
        {return GetBlockCipher().OptimalDataAlignment();}

    /// \brief Validates the block size
    /// \param length the block size of the cipher, in bytes
    /// \throw InvalidArgument if the block size is invalid
    /// \details If <tt>CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS</tt> is 0,
    ///  then CIPHER must be a 16-byte block cipher. If
    ///  <tt>CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS</tt> is non-zero then
    ///  CIPHER can be 16, 32, 64, or 128-byte block cipher.
    void ThrowIfInvalidBlockSize(size_t length);

    void SetKey(const byte *key, size_t length, const NameValuePairs &params = g_nullNameValuePairs);
    IV_Requirement IVRequirement() const {return UNIQUE_IV;}
    void Resynchronize(const byte *iv, int ivLength=-1);
    void ProcessData(byte *outString, const byte *inString, size_t length);
    size_t ProcessLastBlock(byte *outString, size_t outLength, const byte *inString, size_t inLength);

    /// \brief Resynchronize the cipher
    /// \param sector a 64-bit sector number
    /// \param order the endian order the word should be written
    /// \details The Resynchronize() overload was provided for API
    ///  compatibility with the IEEE P1619 paper.
    void Resynchronize(word64 sector, ByteOrder order=BIG_ENDIAN_ORDER);

protected:
    virtual void ResizeBuffers();

    inline size_t ProcessLastPlainBlock(byte *outString, size_t outLength, const byte *inString, size_t inLength);
    inline size_t ProcessLastCipherBlock(byte *outString, size_t outLength, const byte *inString, size_t inLength);

    virtual BlockCipher& AccessBlockCipher() = 0;
    virtual BlockCipher& AccessTweakCipher() = 0;

    const BlockCipher& GetBlockCipher() const
        {return const_cast<XTS_ModeBase*>(this)->AccessBlockCipher();}
    const BlockCipher& GetTweakCipher() const
        {return const_cast<XTS_ModeBase*>(this)->AccessTweakCipher();}

    // Buffers are sized based on ParallelBlocks
    AlignedSecByteBlock m_xregister;
    AlignedSecByteBlock m_xworkspace;

    // Intel lacks the SSE registers to run 8 or 12 parallel blocks.
    // Do not change this value after compiling. It has no effect.
#if CRYPTOPP_BOOL_X64 || CRYPTOPP_BOOL_X32 || CRYPTOPP_BOOL_X86
    enum {ParallelBlocks = 4};
#else
    enum {ParallelBlocks = 12};
#endif
};

/// \brief XTS block cipher mode of operation implementation
/// \tparam CIPHER BlockCipher derived class or type
/// \details XTS_Final() provides access to CIPHER in base class XTS_ModeBase()
///  through an interface. AccessBlockCipher() and AccessTweakCipher() allow
///  the XTS_ModeBase() base class to access the user's block cipher without
///  recompiling the library.
/// \details If <tt>CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS</tt> is 0, then CIPHER must
///  be a 16-byte block cipher. If <tt>CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS</tt> is
///  non-zero then CIPHER can be 16, 32, 64, or 128-byte block cipher.
///  There is risk involved with using XTS with wider block ciphers.
///  According to Phillip Rogaway, "The narrow width of the underlying PRP and
///  the poor treatment of fractional final blocks are problems." To enable
///  wide block cipher support define <tt>CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS</tt> to
///  non-zero.
/// \sa <A HREF="http://www.cryptopp.com/wiki/Modes_of_Operation">Modes of
///  Operation</A> on the Crypto++ wiki, <A
///  HREF="https://web.cs.ucdavis.edu/~rogaway/papers/modes.pdf"> Evaluation of Some
///  Blockcipher Modes of Operation</A>, <A
///  HREF="https://csrc.nist.gov/publications/detail/sp/800-38e/final">Recommendation
///  for Block Cipher Modes of Operation: The XTS-AES Mode for Confidentiality on
///  Storage Devices</A>, <A
///  HREF="http://libeccio.di.unisa.it/Crypto14/Lab/p1619.pdf">IEEE P1619-2007</A>
///  and <A HREF="https://crypto.stackexchange.com/q/74925/10496">IEEE P1619/XTS,
///  inconsistent reference implementation and test vectors</A>.
/// \since Crypto++ 8.3
template <class CIPHER>
class CRYPTOPP_NO_VTABLE XTS_Final : public XTS_ModeBase
{
protected:
    BlockCipher& AccessBlockCipher()
        {return *m_cipher;}
    BlockCipher& AccessTweakCipher()
        {return m_tweaker;}

protected:
    typename CIPHER::Encryption m_tweaker;
};

/// \brief XTS block cipher mode of operation
/// \tparam CIPHER BlockCipher derived class or type
/// \details XTS mode is a wide block mode defined by IEEE P1619-2008. NIST
///  SP-800-38E approves the mode for storage devices citing IEEE 1619-2007.
///  IEEE 1619-2007 provides both a reference implementation and test vectors.
///  The IEEE reference implementation fails to arrive at the expected result
///  for some test vectors.
/// \details XTS is only defined for AES. The library can support wide
///  block ciphers like Kaylna and Threefish since we know the polynomials.
///  There is risk involved with using XTS with wider block ciphers.
///  According to Phillip Rogaway, "The narrow width of the underlying PRP and
///  the poor treatment of fractional final blocks are problems." To enable
///  wide block cipher support define <tt>CRYPTOPP_XTS_WIDE_BLOCK_CIPHERS</tt> to
///  non-zero.
/// \sa <A HREF="http://www.cryptopp.com/wiki/Modes_of_Operation">Modes of
///  Operation</A> on the Crypto++ wiki, <A
///  HREF="https://web.cs.ucdavis.edu/~rogaway/papers/modes.pdf"> Evaluation of Some
///  Blockcipher Modes of Operation</A>, <A
///  HREF="https://csrc.nist.gov/publications/detail/sp/800-38e/final">Recommendation
///  for Block Cipher Modes of Operation: The XTS-AES Mode for Confidentiality on
///  Storage Devices</A>, <A
///  HREF="http://libeccio.di.unisa.it/Crypto14/Lab/p1619.pdf">IEEE P1619-2007</A>
///  and <A HREF="https://crypto.stackexchange.com/q/74925/10496">IEEE P1619/XTS,
///  inconsistent reference implementation and test vectors</A>.
/// \since Crypto++ 8.3
template <class CIPHER>
struct XTS : public CipherModeDocumentation
{
    typedef CipherModeFinalTemplate_CipherHolder<typename CIPHER::Encryption, XTS_Final<CIPHER> > Encryption;
    typedef CipherModeFinalTemplate_CipherHolder<typename CIPHER::Decryption, XTS_Final<CIPHER> > Decryption;
};

// C++03 lacks the mechanics to typedef a template
#define XTS_Mode XTS

NAMESPACE_END

#endif  // CRYPTOPP_XTS_MODE_H
