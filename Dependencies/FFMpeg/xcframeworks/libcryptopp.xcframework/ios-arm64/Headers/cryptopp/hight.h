// hight.h - written and placed in the public domain by Kim Sung Hee and Jeffrey Walton
//           Based on "HIGHT: A New Block Cipher Suitable for Low-Resource Device"
//           by Deukjo Hong, Jaechul Sung, Seokhie Hong, Jongin Lim, Sangjin Lee,
//           Bon-Seok Koo, Changhoon Lee, Donghoon Chang, Jesang Lee, Kitae Jeong,
//           Hyun Kim, Jongsung Kim, and Seongtaek Chee

/// \file hight.h
/// \brief Classes for the HIGHT block cipher
/// \since Crypto++ 8.0

#ifndef CRYPTOPP_HIGHT_H
#define CRYPTOPP_HIGHT_H

#include "config.h"
#include "seckey.h"
#include "secblock.h"
#include "algparam.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief HIGHT block cipher information
/// \since Crypto++ 8.0
struct HIGHT_Info : public FixedBlockSize<8>, public FixedKeyLength<16>
{
    static const std::string StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize
        return "HIGHT";
    }
};

/// \brief HIGHT 64-bit block cipher
/// \details HIGHT provides 64-bit block size. The valid key size is 128-bits.
/// \note Crypto++ provides a byte oriented implementation
/// \sa <a href="http://www.cryptopp.com/wiki/HIGHT">HIGHT</a>,
///   <a href="https://seed.kisa.or.kr/">Korea Internet &amp; Security
///   Agency</a> website
/// \since Crypto++ 8.0
class CRYPTOPP_NO_VTABLE HIGHT : public HIGHT_Info, public BlockCipherDocumentation
{
public:
    /// \brief HIGHT block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Base : public BlockCipherImpl<HIGHT_Info>
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);

        FixedSizeSecBlock<byte, 136> m_rkey;
        mutable FixedSizeSecBlock<word32, 8> m_xx;
    };

    /// \brief Encryption transformation
    /// \details Enc provides implementation for encryption transformation.
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    /// \brief Decryption transformation
    /// \details Dec provides implementation for decryption transformation.
    /// \since Crypto++ 8.0
    class CRYPTOPP_NO_VTABLE Dec : public Base
    {
    public:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef HIGHT::Encryption HIGHTEncryption;
typedef HIGHT::Decryption HIGHTDecryption;

NAMESPACE_END

#endif  // CRYPTOPP_HIGHT_H
