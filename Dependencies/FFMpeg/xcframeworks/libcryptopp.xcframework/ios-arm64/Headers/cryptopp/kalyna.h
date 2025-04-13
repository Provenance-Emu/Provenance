// kalyna.h - written and placed in the public domain by Jeffrey Walton
//            Based on public domain code by Keru Kuro.

/// \file kalyna.h
/// \brief Classes for the Kalyna block cipher
/// \details The Crypto++ implementation relied upon three sources. First was Oliynykov, Gorbenko, Kazymyrov,
///   Ruzhentsev, Kuznetsov, Gorbenko, Dyrda, Dolgov, Pushkaryov, Mordvinov and Kaidalov's "A New Encryption
///   Standard of Ukraine: The Kalyna Block Cipher" (http://eprint.iacr.org/2015/650.pdf). Second was Roman
///   Oliynykov and Oleksandr Kazymyrov's GitHub with the reference implementation
///   (http://github.com/Roman-Oliynykov/Kalyna-reference). The third resource was Keru Kuro's implementation
///   of Kalyna in CppCrypto (http://sourceforge.net/projects/cppcrypto/). Kuro has an outstanding
///   implementation that performed better than the reference implementation and our initial attempts.

#ifndef CRYPTOPP_KALYNA_H
#define CRYPTOPP_KALYNA_H

#include "config.h"
#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Kalyna-128 block cipher information
/// \since Crypto++ 6.0
struct CRYPTOPP_NO_VTABLE Kalyna128_Info : public FixedBlockSize<16>, VariableKeyLength<16, 16, 32>
{
    static const char* StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize(Keylength)
        return "Kalyna-128";
    }
};

/// \brief Kalyna-256 block cipher information
/// \since Crypto++ 6.0
struct CRYPTOPP_NO_VTABLE Kalyna256_Info : public FixedBlockSize<32>, VariableKeyLength<32, 32, 64>
{
    static const char* StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize(Keylength)
        return "Kalyna-256";
    }
};

/// \brief Kalyna-512 block cipher information
/// \since Crypto++ 6.0
struct CRYPTOPP_NO_VTABLE Kalyna512_Info : public FixedBlockSize<64>, FixedKeyLength<64>
{
    static const char* StaticAlgorithmName()
    {
        // Format is Cipher-Blocksize(Keylength)
        return "Kalyna-512";
    }
};

/// \brief Kalyna block cipher base class
/// \since Crypto++ 6.0
class CRYPTOPP_NO_VTABLE Kalyna_Base
{
public:
    virtual ~Kalyna_Base() {}

protected:
    typedef SecBlock<word64, AllocatorWithCleanup<word64, true> > AlignedSecBlock64;
    mutable AlignedSecBlock64 m_wspace;  // work space
    AlignedSecBlock64         m_mkey;    // master key
    AlignedSecBlock64         m_rkeys;   // round keys
    unsigned int     m_kl, m_nb, m_nk;   // number 64-bit blocks and keys
};

/// \brief Kalyna 128-bit block cipher
/// \details Kalyna128 provides 128-bit block size. The valid key sizes are 128-bit and 256-bit.
/// \since Crypto++ 6.0
class Kalyna128 : public Kalyna128_Info, public BlockCipherDocumentation
{
public:
    class CRYPTOPP_NO_VTABLE Base : public Kalyna_Base, public BlockCipherImpl<Kalyna128_Info>
    {
    public:
        /// \brief Provides the name of this algorithm
        /// \return the standard algorithm name
        /// \details If the object is unkeyed, then the generic name "Kalyna" is returned
        ///   to the caller. If the algorithm is keyed, then a two or three part name is
        ///   returned to the caller. The name follows DSTU 7624:2014, where block size is
        ///   provided first and then key length. The library uses a dash to identify block size
        ///   and parenthesis to identify key length. For example, Kalyna-128(256) is Kalyna
        ///   with a 128-bit block size and a 256-bit key length. If a mode is associated
        ///   with the object, then it follows as expected. For example, Kalyna-128(256)/ECB.
        ///   DSTU is a little more complex with more parameters, dashes, underscores, but the
        ///   library does not use the delimiters or full convention.
        std::string AlgorithmName() const {
            return std::string("Kalyna-128") + "(" + IntToString(m_kl*8) + ")";
        }

        /// \brief Provides input and output data alignment for optimal performance.
        /// \return the input data alignment that provides optimal performance
        /// \sa GetAlignment() and OptimalBlockSize()
        unsigned int OptimalDataAlignment() const {
            return GetAlignmentOf<word64>();
        }

    protected:
        void UncheckedSetKey(const byte *key, unsigned int keylen, const NameValuePairs &params);
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

    protected:
        void SetKey_22(const word64 key[2]);
        void SetKey_24(const word64 key[4]);
        void ProcessBlock_22(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
        void ProcessBlock_24(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    typedef BlockCipherFinal<ENCRYPTION, Base> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Base> Decryption;
};

/// \brief Kalyna 256-bit block cipher
/// \details Kalyna256 provides 256-bit block size. The valid key sizes are 256-bit and 512-bit.
/// \since Crypto++ 6.0
class Kalyna256 : public Kalyna256_Info, public BlockCipherDocumentation
{
public:
    class CRYPTOPP_NO_VTABLE Base : public Kalyna_Base, public BlockCipherImpl<Kalyna256_Info>
    {
    public:
        /// \brief Provides the name of this algorithm
        /// \return the standard algorithm name
        /// \details If the object is unkeyed, then the generic name "Kalyna" is returned
        ///   to the caller. If the algorithm is keyed, then a two or three part name is
        ///   returned to the caller. The name follows DSTU 7624:2014, where block size is
        ///   provided first and then key length. The library uses a dash to identify block size
        ///   and parenthesis to identify key length. For example, Kalyna-128(256) is Kalyna
        ///   with a 128-bit block size and a 256-bit key length. If a mode is associated
        ///   with the object, then it follows as expected. For example, Kalyna-128(256)/ECB.
        ///   DSTU is a little more complex with more parameters, dashes, underscores, but the
        ///   library does not use the delimiters or full convention.
        std::string AlgorithmName() const {
            return std::string("Kalyna-256") + "(" + IntToString(m_kl*8) + ")";
        }

        /// \brief Provides input and output data alignment for optimal performance.
        /// \return the input data alignment that provides optimal performance
        /// \sa GetAlignment() and OptimalBlockSize()
        unsigned int OptimalDataAlignment() const {
            return GetAlignmentOf<word64>();
        }

    protected:
        void UncheckedSetKey(const byte *key, unsigned int keylen, const NameValuePairs &params);
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

    protected:
        void SetKey_44(const word64 key[4]);
        void SetKey_48(const word64 key[8]);
        void ProcessBlock_44(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
        void ProcessBlock_48(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    typedef BlockCipherFinal<ENCRYPTION, Base> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Base> Decryption;
};

/// \brief Kalyna 512-bit block cipher
/// \details Kalyna512 provides 512-bit block size. The valid key size is 512-bit.
/// \since Crypto++ 6.0
class Kalyna512 : public Kalyna512_Info, public BlockCipherDocumentation
{
public:
    class CRYPTOPP_NO_VTABLE Base : public Kalyna_Base, public BlockCipherImpl<Kalyna512_Info>
    {
    public:
        /// \brief Provides the name of this algorithm
        /// \return the standard algorithm name
        /// \details If the object is unkeyed, then the generic name "Kalyna" is returned
        ///   to the caller. If the algorithm is keyed, then a two or three part name is
        ///   returned to the caller. The name follows DSTU 7624:2014, where block size is
        ///   provided first and then key length. The library uses a dash to identify block size
        ///   and parenthesis to identify key length. For example, Kalyna-128(256) is Kalyna
        ///   with a 128-bit block size and a 256-bit key length. If a mode is associated
        ///   with the object, then it follows as expected. For example, Kalyna-128(256)/ECB.
        ///   DSTU is a little more complex with more parameters, dashes, underscores, but the
        ///   library does not use the delimiters or full convention.
        std::string AlgorithmName() const {
            return std::string("Kalyna-512") + "(" + IntToString(m_kl*8) + ")";
        }

        /// \brief Provides input and output data alignment for optimal performance.
        /// \return the input data alignment that provides optimal performance
        /// \sa GetAlignment() and OptimalBlockSize()
        unsigned int OptimalDataAlignment() const {
            return GetAlignmentOf<word64>();
        }

    protected:
        void UncheckedSetKey(const byte *key, unsigned int keylen, const NameValuePairs &params);
        void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;

    protected:
        void SetKey_88(const word64 key[8]);
        void ProcessBlock_88(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
    };

    typedef BlockCipherFinal<ENCRYPTION, Base> Encryption;
    typedef BlockCipherFinal<DECRYPTION, Base> Decryption;
};

typedef Kalyna128::Encryption Kalyna128Encryption;
typedef Kalyna128::Decryption Kalyna128Decryption;

typedef Kalyna256::Encryption Kalyna256Encryption;
typedef Kalyna256::Decryption Kalyna256Decryption;

typedef Kalyna512::Encryption Kalyna512Encryption;
typedef Kalyna512::Decryption Kalyna512Decryption;

NAMESPACE_END

#endif  // CRYPTOPP_KALYNA_H
