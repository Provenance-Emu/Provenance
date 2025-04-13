// threefish.h - written and placed in the public domain by Jeffrey Walton
//               Based on public domain code by Keru Kuro. Kuro's code is
//               available at http://cppcrypto.sourceforge.net/.

/// \file Threefish.h
/// \brief Classes for the Threefish block cipher
/// \since Crypto++ 6.0

#ifndef CRYPTOPP_THREEFISH_H
#define CRYPTOPP_THREEFISH_H

#include "config.h"
#include "seckey.h"
#include "secblock.h"
#include "algparam.h"
#include "argnames.h"
#include "stdcpp.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Threefish block cipher information
/// \tparam BS block size of the cipher, in bytes
/// \since Crypto++ 6.0
template <unsigned int BS>
struct Threefish_Info : public FixedBlockSize<BS>, FixedKeyLength<BS>
{
    static const std::string StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize(Keylength)
        return "Threefish-" + IntToString(BS*8) + "(" + IntToString(BS*8) + ")";
    }
};

/// \brief Threefish block cipher base class
/// \tparam BS block size of the cipher, in bytes
/// \details User code should use Threefish256, Threefish512, Threefish1024
/// \sa Threefish256, Threefish512, Threefish1024, <a href="http://www.cryptopp.com/wiki/Threefish">Threefish</a>
/// \since Crypto++ 6.0
template <unsigned int BS>
struct CRYPTOPP_NO_VTABLE Threefish_Base
{
	virtual ~Threefish_Base() {}

    void SetTweak(const NameValuePairs &params)
    {
        m_tweak.New(3);
        ConstByteArrayParameter t;
        if (params.GetValue(Name::Tweak(), t))
        {
            // Tweak size is fixed at 16 for Threefish
            CRYPTOPP_ASSERT(t.size() == 16);
            GetUserKey(LITTLE_ENDIAN_ORDER, m_tweak.begin(), 2, t.begin(), 16);
            m_tweak[2] = m_tweak[0] ^ m_tweak[1];
        }
        else
        {
            std::memset(m_tweak.begin(), 0x00, 24);
        }
    }

    typedef SecBlock<word64, AllocatorWithCleanup<word64, true> > AlignedSecBlock64;
    mutable AlignedSecBlock64 m_wspace;   // workspace
    AlignedSecBlock64         m_rkey;     // keys
    AlignedSecBlock64         m_tweak;
};

/// \brief Threefish 256-bit block cipher
/// \details Threefish256 provides 256-bit block size. The valid key size is 256-bit.
/// \note Crypto++ provides a byte oriented implementation
/// \sa Threefish512, Threefish1024, <a href="http://www.cryptopp.com/wiki/Threefish">Threefish</a>
/// \since Crypto++ 6.0
class CRYPTOPP_NO_VTABLE Threefish256 : public Threefish_Info<32>, public BlockCipherDocumentation
{
public:
    /// \brief Threefish block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Base : public Threefish_Base<32>, public BlockCipherImpl<Threefish_Info<32> >
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);
    };

    /// \brief Encryption transformation
    /// \details Enc provides implementation for encryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    protected:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    /// \brief Decryption transformation
    /// \details Dec provides implementation for decryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Dec : public Base
    {
    protected:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef Threefish256::Encryption Threefish256Encryption;
typedef Threefish256::Decryption Threefish256Decryption;

/// \brief Threefish 512-bit block cipher
/// \details Threefish512 provides 512-bit block size. The valid key size is 512-bit.
/// \note Crypto++ provides a byte oriented implementation
/// \sa Threefish256, Threefish1024, <a href="http://www.cryptopp.com/wiki/Threefish">Threefish</a>
/// \since Crypto++ 6.0
class CRYPTOPP_NO_VTABLE Threefish512 : public Threefish_Info<64>, public BlockCipherDocumentation
{
public:
    /// \brief Threefish block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Base : public Threefish_Base<64>, public BlockCipherImpl<Threefish_Info<64> >
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);
    };

    /// \brief Encryption transformation
    /// \details Enc provides implementation for encryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    protected:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    /// \brief Decryption transformation
    /// \details Dec provides implementation for decryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Dec : public Base
    {
    protected:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef Threefish512::Encryption Threefish512Encryption;
typedef Threefish512::Decryption Threefish512Decryption;

/// \brief Threefish 1024-bit block cipher
/// \details Threefish1024 provides 1024-bit block size. The valid key size is 1024-bit.
/// \note Crypto++ provides a byte oriented implementation
/// \sa Threefish256, Threefish512, <a href="http://www.cryptopp.com/wiki/Threefish">Threefish</a>
/// \since Crypto++ 6.0
class CRYPTOPP_NO_VTABLE Threefish1024 : public Threefish_Info<128>, public BlockCipherDocumentation
{
public:
    /// \brief Threefish block cipher transformation functions
    /// \details Provides implementation common to encryption and decryption
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Base : public Threefish_Base<128>, public BlockCipherImpl<Threefish_Info<128> >
    {
    protected:
        void UncheckedSetKey(const byte *userKey, unsigned int keyLength, const NameValuePairs &params);
    };

    /// \brief Encryption transformation
    /// \details Enc provides implementation for encryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Enc : public Base
    {
    protected:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    /// \brief Encryption transformation
    /// \details Dec provides implementation for decryption transformation. All key and block
    ///   sizes are supported.
    /// \since Crypto++ 6.0
    class CRYPTOPP_NO_VTABLE Dec : public Base
    {
    protected:
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    typedef BlockCipherFinal<ENCRYPTION, Enc> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Dec> Decryption;
};

typedef Threefish1024::Encryption Threefish1024Encryption;
typedef Threefish1024::Decryption Threefish1024Decryption;

NAMESPACE_END

#endif  // CRYPTOPP_THREEFISH_H
