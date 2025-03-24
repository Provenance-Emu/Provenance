// sm4.h - written and placed in the public domain by Jeffrey Walton and Han Lulu

/// \file sm4.h
/// \brief Classes for the SM4 block cipher
/// \details SM4 is a block cipher designed by Xiaoyun Wang, et al. The block cipher is part of the
///   Chinese State Cryptography Administration portfolio. The cipher was formerly known as SMS4.
/// \details SM4 encryption is accelerated on machines with AES-NI. Decryption is not accelerated because
///   it is not profitable. Thanks to Markku-Juhani Olavi Saarinen for help and the code.
/// \sa <A HREF="http://eprint.iacr.org/2008/329.pdf">SMS4 Encryption Algorithm for Wireless Networks</A>,
///   <A HREF="http://github.com/guanzhi/GmSSL">Reference implementation using OpenSSL</A> and
///   <A HREF="https://github.com/mjosaarinen/sm4ni">Markku-Juhani Olavi Saarinen GitHub</A>.
/// \since Crypto++ 6.0

#ifndef CRYPTOPP_SM4_H
#define CRYPTOPP_SM4_H

#include "config.h"
#include "seckey.h"
#include "secblock.h"

#if (CRYPTOPP_BOOL_X64 || CRYPTOPP_BOOL_X32 || CRYPTOPP_BOOL_X86)
# ifndef CRYPTOPP_DISABLE_SM4_SIMD
#  define CRYPTOPP_SM4_ADVANCED_PROCESS_BLOCKS 1
# endif
#endif

NAMESPACE_BEGIN(CryptoPP)

/// \brief SM4 block cipher information
/// \since Crypto++ 6.0
struct SM4_Info : public FixedBlockSize<16>, FixedKeyLength<16>
{
    static const std::string StaticAlgorithmName()
    {
        return "SM4";
    }
};

/// \brief Classes for the SM4 block cipher
/// \details SM4 is a block cipher designed by Xiaoyun Wang, et al. The block cipher is part of the
///   Chinese State Cryptography Administration portfolio. The cipher was formerly known as SMS4.
/// \sa <A HREF="http://eprint.iacr.org/2008/329.pdf">SMS4 Encryption Algorithm for Wireless Networks</A>
/// \since Crypto++ 6.0
class CRYPTOPP_NO_VTABLE SM4 : public SM4_Info, public BlockCipherDocumentation
{
public:
    /// \brief SM4 block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<SM4_Info>
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);

        SecBlock<word32, AllocatorWithCleanup<word32> > m_rkeys;
        mutable SecBlock<word32, AllocatorWithCleanup<word32> > m_wspace;
    };

    /// \brief Encryption transformation
    /// \details Enc provides implementation for encryption transformation. All key
    ///   sizes are supported.
    /// \details SM4 encryption is accelerated on machines with AES-NI. Decryption is
    ///   not accelerated because it is not profitable. Thanks to Markku-Juhani Olavi
    ///   Saarinen.
    /// \since Crypto++ 6.0, AESNI encryption since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    public:
        std::string AlgorithmProvider() const;
    protected:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
#if CRYPTOPP_SM4_ADVANCED_PROCESS_BLOCKS
        size_t AdvancedProcessBlocks(const byte *inBlocks, const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags) const;
#endif
    };

    /// \brief Decryption transformation
    /// \details Dec provides implementation for decryption transformation. All key
    ///   sizes are supported.
    /// \details SM4 encryption is accelerated on machines with AES-NI. Decryption is
    ///   not accelerated because it is not profitable. Thanks to Markku-Juhani Olavi
    ///   Saarinen.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Dec : public Base
    {
    protected:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

NAMESPACE_END

#endif // CRYPTOPP_SM4_H
