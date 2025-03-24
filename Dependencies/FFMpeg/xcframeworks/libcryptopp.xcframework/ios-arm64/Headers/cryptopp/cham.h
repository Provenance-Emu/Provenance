// cham.h - written and placed in the public domain by Kim Sung Hee and Jeffrey Walton
//          Based on "CHAM: A Family of Lightweight Block Ciphers for
//          Resource-Constrained Devices" by Bonwook Koo, Dongyoung Roh,
//          Hyeonjin Kim, Younghoon Jung, Dong-Geon Lee, and Daesung Kwon

/// \file cham.h
/// \brief Classes for the CHAM block cipher
/// \since Crypto++ 8.0

#ifndef CRYPTOPP_CHAM_H
#define CRYPTOPP_CHAM_H

#include "config.h"
#include "seckey.h"
#include "secblock.h"
#include "algparam.h"

#if (CRYPTOPP_BOOL_X64 || CRYPTOPP_BOOL_X32 || CRYPTOPP_BOOL_X86)
# define CRYPTOPP_CHAM128_ADVANCED_PROCESS_BLOCKS 1
#endif

// Yet another SunStudio/SunCC workaround. Failed self tests
// in SSE code paths on i386 for SunStudio 12.3 and below.
#if defined(__SUNPRO_CC) && (__SUNPRO_CC <= 0x5120)
# undef CRYPTOPP_CHAM128_ADVANCED_PROCESS_BLOCKS
#endif

NAMESPACE_BEGIN(CryptoPP)

/// \brief CHAM block cipher information
/// \since Crypto++ 8.0
struct CHAM64_Info : public FixedBlockSize<8>, public FixedKeyLength<16>
{
    /// \brief The algorithm name
    /// \return the algorithm name
    /// \details StaticAlgorithmName returns the algorithm's name as a static
    ///   member function.
    static const std::string StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize
        return "CHAM-64";
    }
};

/// \brief CHAM block cipher information
/// \since Crypto++ 8.0
struct CHAM128_Info : public FixedBlockSize<16>, public VariableKeyLength<16,16,32,16>
{
    /// \brief The algorithm name
    /// \return the algorithm name
    /// \details StaticAlgorithmName returns the algorithm's name as a static
    ///   member function.
    static const std::string StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize
        return "CHAM-128";
    }
};

/// \brief CHAM 64-bit block cipher
/// \details CHAM64 provides 64-bit block size. The valid key size is 128-bit.
/// \note Crypto++ provides a byte oriented implementation
/// \sa CHAM128, <a href="http://www.cryptopp.com/wiki/CHAM">CHAM</a>,
///   <a href="https://pdfs.semanticscholar.org/2f57/61b5c2614cffd58a09cc83c375a2b32a2ed3.pdf">
///   CHAM: A Family of Lightweight Block Ciphers for Resource-Constrained Devices</a>
/// \since Crypto++ 8.0
class CRYPTOPP_NO_VTABLE CHAM64 : public CHAM64_Info, public BlockCipherDocumentation
{
public:
    /// \brief CHAM block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<CHAM64_Info>
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);

        SecBlock<word16> m_rk;
        mutable FixedSizeSecBlock<word16, 4> m_x;
        unsigned int m_kw;
    };

    /// \brief Encryption transformation
    /// \details Enc provides implementation for encryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    /// \brief Decryption transformation
    /// \details Dec provides implementation for decryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Dec : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    /// \brief CHAM64 encryption
    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    /// \brief CHAM64 decryption
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

/// \brief CHAM64 encryption
typedef CHAM64::Encryption CHAM64Encryption;
/// \brief CHAM64 decryption
typedef CHAM64::Decryption CHAM64Decryption;

/// \brief CHAM 128-bit block cipher
/// \details CHAM128 provides 128-bit block size. The valid key size is 128-bit and 256-bit.
/// \note Crypto++ provides a byte oriented implementation
/// \sa CHAM64, <a href="http://www.cryptopp.com/wiki/CHAM">CHAM</a>,
///   <a href="https://pdfs.semanticscholar.org/2f57/61b5c2614cffd58a09cc83c375a2b32a2ed3.pdf">
///   CHAM: A Family of Lightweight Block Ciphers for Resource-Constrained Devices</a>
/// \since Crypto++ 8.0
class CRYPTOPP_NO_VTABLE CHAM128 : public CHAM128_Info, public BlockCipherDocumentation
{
public:
    /// \brief CHAM block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<CHAM128_Info>
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);
        std::string AlgorithmProvider() const;

        SecBlock<word32> m_rk;
        mutable FixedSizeSecBlock<word32, 4> m_x;
        unsigned int m_kw;
    };

    /// \brief Encryption transformation
    /// \details Enc provides implementation for encryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

#if CRYPTOPP_CHAM128_ADVANCED_PROCESS_BLOCKS
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

#if CRYPTOPP_CHAM128_ADVANCED_PROCESS_BLOCKS
        size_t AdvancedProcessBlocks(const byte *inBlocks, const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags) const;
#endif
    };

    /// \brief CHAM128 encryption
    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    /// \brief CHAM128 decryption
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

/// \brief CHAM128 encryption
typedef CHAM128::Encryption CHAM128Encryption;
/// \brief CHAM128 decryption
typedef CHAM128::Decryption CHAM128Decryption;

NAMESPACE_END

#endif  // CRYPTOPP_CHAM_H
