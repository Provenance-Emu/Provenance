// simon.h - written and placed in the public domain by Jeffrey Walton

/// \file simon.h
/// \brief Classes for the Simon block cipher
/// \details Simon is a block cipher designed by Ray Beaulieu, Douglas Shors, Jason Smith,
///  Stefan Treatman-Clark, Bryan Weeks and Louis Wingers.
/// \sa <A HREF="http://eprint.iacr.org/2013/404">The SIMON and SPECK Families of
///  Lightweight Block Ciphers</A>, <A HREF="http://iadgov.github.io/simon-speck/">
///  The Simon and Speck GitHub</A> and <A HREF="https://www.cryptopp.com/wiki/SIMON">
///  SIMON</A> on the Crypto++ wiki.
/// \since Crypto++ 6.0

#ifndef CRYPTOPP_SIMON_H
#define CRYPTOPP_SIMON_H

#include "config.h"
#include "seckey.h"
#include "secblock.h"

#if CRYPTOPP_BOOL_X64 || CRYPTOPP_BOOL_X32 || CRYPTOPP_BOOL_X86 || \
    CRYPTOPP_BOOL_ARM32 || CRYPTOPP_BOOL_ARMV8 || \
    CRYPTOPP_BOOL_PPC32 || CRYPTOPP_BOOL_PPC64
# ifndef CRYPTOPP_DISABLE_SIMON_SIMD
#  define CRYPTOPP_SIMON128_ADVANCED_PROCESS_BLOCKS 1
# endif
#endif

// Yet another SunStudio/SunCC workaround. Failed self tests
// in SSE code paths on i386 for SunStudio 12.3 and below.
#if defined(__SUNPRO_CC) && (__SUNPRO_CC <= 0x5120)
# undef CRYPTOPP_SIMON128_ADVANCED_PROCESS_BLOCKS
#endif

NAMESPACE_BEGIN(CryptoPP)

/// \brief SIMON block cipher information
/// \tparam L block size of the cipher, in bytes
/// \tparam D default key length, in bytes
/// \tparam N minimum key length, in bytes
/// \tparam M maximum key length, in bytes
/// \since Crypto++ 6.0
template <unsigned int L, unsigned int D, unsigned int N, unsigned int M>
struct SIMON_Info : public FixedBlockSize<L>, VariableKeyLength<D, N, M>
{
	/// \brief The algorithm name
	/// \return the algorithm name
	/// \details StaticAlgorithmName returns the algorithm's name as a static
	///  member function.
    static const std::string StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize(Keylength)
        return "SIMON-" + IntToString(L*8);
    }
};

/// \brief SIMON block cipher base class
/// \tparam W the word type
/// \details User code should use SIMON64 or SIMON128
/// \sa SIMON64, SIMON128, <a href="http://www.cryptopp.com/wiki/SIMON">SIMON</a> on the Crypto++ wiki
/// \since Crypto++ 6.0
template <class W>
struct SIMON_Base
{
    virtual ~SIMON_Base() {}
    SIMON_Base() : m_kwords(0), m_rounds(0) {}

    typedef SecBlock<W, AllocatorWithCleanup<W, true> > AlignedSecBlock;
    mutable AlignedSecBlock m_wspace;  // workspace
    AlignedSecBlock         m_rkeys;   // round keys
    unsigned int            m_kwords;  // number of key words
    unsigned int            m_rounds;  // number of rounds
};

/// \brief SIMON 64-bit block cipher
/// \details Simon is a block cipher designed by Ray Beaulieu, Douglas Shors, Jason Smith,
///  Stefan Treatman-Clark, Bryan Weeks and Louis Wingers.
/// \details SIMON64 provides 64-bit block size. The valid key sizes are 96-bit and 128-bit.
/// \sa SIMON64, SIMON128,  <A HREF="http://eprint.iacr.org/2013/404">The SIMON and SIMON
///  Families of Lightweight Block Ciphers</A>, <A HREF="http://iadgov.github.io/simon-speck/">
///  The Simon and Speck GitHub</A>, <a href="http://www.cryptopp.com/wiki/SIMON">SIMON</a> on the
///  Crypto++ wiki
/// \since Crypto++ 6.0
class CRYPTOPP_NO_VTABLE SIMON64 : public SIMON_Info<8, 12, 12, 16>, public BlockCipherDocumentation
{
public:
    /// \brief SIMON64 block cipher base implementation
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Base : protected SIMON_Base<word32>, public BlockCipherImpl<SIMON_Info<8, 12, 12, 16> >
    {
    public:
        /// \brief The algorithm name
        /// \return the algorithm name
        /// \details AlgorithmName returns the algorithm's name as a
        ///  member function.
        std::string AlgorithmName() const {
            return StaticAlgorithmName() + (m_kwords == 0 ? "" :
                "(" + IntToString(m_kwords*sizeof(word32)*8) + ")");
        }

        std::string AlgorithmProvider() const;

        /// \brief Provides input and output data alignment for optimal performance.
        /// \return the input data alignment that provides optimal performance
        /// \sa GetAlignment() and OptimalBlockSize()
        unsigned int OptimalDataAlignment() const;

    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);
    };

    /// \brief SIMON64 encryption transformation
    /// \details Enc provides the encryption transformation.
    ///  All key sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    /// \brief SIMON64 decryption transformation
    /// \details Dec provides the decryption transformation.
    ///  All key sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Dec : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

/// \brief SIMON 128-bit block cipher
/// \details Simon is a block cipher designed by Ray Beaulieu, Douglas Shors, Jason Smith,
///  Stefan Treatman-Clark, Bryan Weeks and Louis Wingers.
/// \details SIMON128 provides 128-bit block size. The valid key sizes are 128-bit, 192-bit and 256-bit.
/// \sa SIMON64, SIMON128,  <A HREF="http://eprint.iacr.org/2013/404">The SIMON and SIMON
///  Families of Lightweight Block Ciphers</A>, <A HREF="http://iadgov.github.io/simon-speck/">
///  The Simon and Speck GitHub</A>, <a href="http://www.cryptopp.com/wiki/SIMON">SIMON</a> on the
///  Crypto++ wiki
/// \since Crypto++ 6.0
class CRYPTOPP_NO_VTABLE SIMON128 : public SIMON_Info<16, 16, 16, 32>, public BlockCipherDocumentation
{
public:
    /// \brief SIMON128 block cipher base implementation
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Base : protected SIMON_Base<word64>, public BlockCipherImpl<SIMON_Info<16, 16, 16, 32> >
    {
    public:
        /// \brief The algorithm name
        /// \return the algorithm name
        /// \details AlgorithmName returns the algorithm's name as a
        ///  member function.
        std::string AlgorithmName() const {
            return StaticAlgorithmName() + (m_kwords == 0 ? "" :
                "(" + IntToString(m_kwords*sizeof(word64)*8) + ")");
        }

        std::string AlgorithmProvider() const;

        /// \brief Provides input and output data alignment for optimal performance.
        /// \return the input data alignment that provides optimal performance
        /// \sa GetAlignment() and OptimalBlockSize()
        unsigned int OptimalDataAlignment() const;

    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);
    };

    /// \brief SIMON128 encryption transformation
    /// \details Enc provides the encryption transformation.
    ///  All key sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
#if CRYPTOPP_SIMON128_ADVANCED_PROCESS_BLOCKS
        size_t AdvancedProcessBlocks(const byte *inBlocks, const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags) const;
#endif
    };

    /// \brief SIMON128 decryption transformation
    /// \details Dec provides the decryption transformation.
    ///  All key sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Dec : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
#if CRYPTOPP_SIMON128_ADVANCED_PROCESS_BLOCKS
        size_t AdvancedProcessBlocks(const byte *inBlocks, const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags) const;
#endif
    };

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

NAMESPACE_END

#endif  // CRYPTOPP_SIMON_H
