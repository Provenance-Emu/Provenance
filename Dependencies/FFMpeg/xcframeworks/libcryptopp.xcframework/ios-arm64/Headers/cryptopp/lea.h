// lea.h - written and placed in the public domain by Kim Sung Hee and Jeffrey Walton
//         Based on "LEA: A 128-Bit Block Cipher for Fast Encryption on Common
//         Processors" by Deukjo Hong, Jung-Keun Lee, Dong-Chan Kim, Daesung Kwon,
//         Kwon Ho Ryu, and Dong-Geon Lee.

/// \file lea.h
/// \brief Classes for the LEA block cipher
/// \since Crypto++ 8.0

#ifndef CRYPTOPP_LEA_H
#define CRYPTOPP_LEA_H

#include "config.h"
#include "seckey.h"
#include "secblock.h"
#include "algparam.h"

#if (CRYPTOPP_BOOL_X64 || CRYPTOPP_BOOL_X32 || CRYPTOPP_BOOL_X86 || CRYPTOPP_BOOL_ARM32 || CRYPTOPP_BOOL_ARMV8)
# ifndef CRYPTOPP_DISABLE_LEA_SIMD
#  define CRYPTOPP_LEA_ADVANCED_PROCESS_BLOCKS 1
# endif
#endif

// Yet another SunStudio/SunCC workaround. Failed self tests
// in SSE code paths on i386 for SunStudio 12.3 and below.
#if defined(__SUNPRO_CC) && (__SUNPRO_CC <= 0x5120)
# undef CRYPTOPP_LEA_ADVANCED_PROCESS_BLOCKS
#endif

NAMESPACE_BEGIN(CryptoPP)

/// \brief LEA block cipher information
/// \since Crypto++ 8.0
struct LEA_Info : public FixedBlockSize<16>, public VariableKeyLength<16,16,32,8>
{
    /// \brief The algorithm name
    /// \return the algorithm name
    /// \details StaticAlgorithmName returns the algorithm's name as a static
    ///   member function.
    static const std::string StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize
        return "LEA-128";
    }
};

/// \brief LEA 128-bit block cipher
/// \details LEA provides 128-bit block size. The valid key size is 128-bits, 192-bits and 256-bits.
/// \note Crypto++ provides a byte oriented implementation
/// \sa <a href="http://www.cryptopp.com/wiki/LEA">LEA</a>,
///   <a href="https://seed.kisa.or.kr/html/egovframework/iwt/ds/ko/ref/LEA%20A%20128-Bit%20Block%20Cipher%20for%20Fast%20Encryption%20on%20Common%20Processors-English.pdf">
///   LEA: A 128-Bit Block Cipher for Fast Encryption on Common Processors</a>
/// \since Crypto++ 8.0
class CRYPTOPP_NO_VTABLE LEA : public LEA_Info, public BlockCipherDocumentation
{
public:
    /// \brief LEA block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<LEA_Info>
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);
        std::string AlgorithmProvider() const;

        SecBlock<word32> m_rkey;
        mutable SecBlock<word32> m_temp;
        unsigned int m_rounds;
    };

    /// \brief Encryption transformation
    /// \details Enc provides implementation for encryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

#if CRYPTOPP_LEA_ADVANCED_PROCESS_BLOCKS
        size_t AdvancedProcessBlocks(const byte *inBlocks, const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags) const;
#endif
    };

    /// \brief Decryption transformation
    /// \details Dec provides implementation for decryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Dec : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

#if CRYPTOPP_LEA_ADVANCED_PROCESS_BLOCKS
        size_t AdvancedProcessBlocks(const byte *inBlocks, const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags) const;
#endif
    };

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef LEA::Encryption LEAEncryption;
typedef LEA::Decryption LEADecryption;

NAMESPACE_END

#endif  // CRYPTOPP_LEA_H
