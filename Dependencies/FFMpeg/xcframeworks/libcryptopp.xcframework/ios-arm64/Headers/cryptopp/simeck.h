// simeck.h - written and placed in the public domain by Gangqiang Yang and Jeffrey Walton.
//            Based on "The Simeck Family of Lightweight Block Ciphers" by Gangqiang Yang,
//            Bo Zhu, Valentin Suder, Mark D. Aagaard, and Guang Gong

/// \file simeck.h
/// \brief Classes for the SIMECK block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/SIMECK">SIMECK</a>,
///   <a href="https://eprint.iacr.org/2015/612.pdf">The Simeck
///   Family of Lightweight Block Ciphers</a>
/// \since Crypto++ 8.0

#ifndef CRYPTOPP_SIMECK_H
#define CRYPTOPP_SIMECK_H

#include "config.h"
#include "seckey.h"
#include "secblock.h"
#include "algparam.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief SIMECK block cipher information
/// \since Crypto++ 8.0
struct SIMECK32_Info : public FixedBlockSize<4>, public FixedKeyLength<8>, public FixedRounds<32>
{
    /// \brief The algorithm name
    /// \return the algorithm name
    /// \details StaticAlgorithmName returns the algorithm's name as a static
    ///   member function.
    static const std::string StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize
        return "SIMECK-32";
    }
};

/// \brief SIMECK block cipher information
/// \since Crypto++ 8.0
struct SIMECK64_Info : public FixedBlockSize<8>, public FixedKeyLength<16>, public FixedRounds<44>
{
    /// \brief The algorithm name
    /// \return the algorithm name
    /// \details StaticAlgorithmName returns the algorithm's name as a static
    ///   member function.
    static const std::string StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize
        return "SIMECK-64";
    }
};

/// \brief SIMECK 32-bit block cipher
/// \details SIMECK32 provides 32-bit block size. The valid key size is 64-bit.
/// \note Crypto++ provides a byte oriented implementation
/// \sa SIMECK64, <a href="http://www.cryptopp.com/wiki/SIMECK">SIMECK</a>,
///   <a href="https://eprint.iacr.org/2015/612.pdf">The Simeck Family of
///   Lightweight Block Ciphers</a>
/// \since Crypto++ 8.0
class CRYPTOPP_NO_VTABLE SIMECK32 : public SIMECK32_Info, public BlockCipherDocumentation
{
public:
    /// \brief SIMECK block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<SIMECK32_Info>
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);
        std::string AlgorithmProvider() const;

        FixedSizeSecBlock<word16, ROUNDS> m_rk;
        mutable FixedSizeSecBlock<word16, 5> m_t;
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

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef SIMECK32::Encryption SIMECK32Encryption;
typedef SIMECK32::Decryption SIMECK32Decryption;

/// \brief SIMECK 64-bit block cipher
/// \details SIMECK64 provides 64-bit block size. The valid key size is 128-bit.
/// \note Crypto++ provides a byte oriented implementation
/// \sa SIMECK32, <a href="http://www.cryptopp.com/wiki/SIMECK">SIMECK</a>,
///   <a href= "https://eprint.iacr.org/2015/612.pdf">The Simeck Family of
///   Lightweight Block Ciphers</a>
/// \since Crypto++ 8.0
class CRYPTOPP_NO_VTABLE SIMECK64 : public SIMECK64_Info, public BlockCipherDocumentation
{
public:
    /// \brief SIMECK block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<SIMECK64_Info>
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);
        std::string AlgorithmProvider() const;

        FixedSizeSecBlock<word32, ROUNDS> m_rk;
        mutable FixedSizeSecBlock<word32, 5> m_t;
    };

    /// \brief Encryption transformation
    /// \details Enc provides implementation for encryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

#if CRYPTOPP_SIMECK_ADVANCED_PROCESS_BLOCKS
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

#if CRYPTOPP_SIMECK_ADVANCED_PROCESS_BLOCKS
        size_t AdvancedProcessBlocks(const byte *inBlocks, const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags) const;
#endif
    };

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef SIMECK64::Encryption SIMECK64Encryption;
typedef SIMECK64::Decryption SIMECK64Decryption;

NAMESPACE_END

#endif  // CRYPTOPP_SIMECK_H
