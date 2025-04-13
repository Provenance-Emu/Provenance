// safer.h - originally written and placed in the public domain by Wei Dai

/// \file safer.h
/// \brief Classes for the SAFER and SAFER-K block ciphers

#ifndef CRYPTOPP_SAFER_H
#define CRYPTOPP_SAFER_H

#include "seckey.h"
#include "secblock.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief SAFER block cipher
class SAFER
{
public:
	/// \brief SAFER block cipher default operation
	class CRYPTOPP_NO_VTABLE Base : public BlockCipher
	{
	public:
		unsigned int OptimalDataAlignment() const {return 1;}
		void UncheckedSetKey(const byte *userkey, unsigned int length, const NameValuePairs &params);

	protected:
		virtual bool Strengthened() const =0;

		SecByteBlock keySchedule;
		static const byte exp_tab[256];
		static const byte log_tab[256];
	};

	/// \brief SAFER block cipher encryption operation
	class CRYPTOPP_NO_VTABLE Enc : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};

	/// \brief SAFER block cipher decryption operation
	class CRYPTOPP_NO_VTABLE Dec : public Base
	{
	public:
		void ProcessAndXorBlock(const byte *inBlock, const byte *xorBlock, byte *outBlock) const;
	};
};

/// \brief SAFER block cipher default implementation
/// \tparam BASE SAFER::Enc or SAFER::Dec derived base class
/// \tparam INFO SAFER_Info derived class
/// \tparam STR flag indicating a strengthened implementation
/// \details SAFER-K is not strengthened; while SAFER-SK is strengthened.
template <class BASE, class INFO, bool STR>
class CRYPTOPP_NO_VTABLE SAFER_Impl : public BlockCipherImpl<INFO, BASE>
{
protected:
	bool Strengthened() const {return STR;}
};

/// \brief SAFER-K block cipher information
struct SAFER_K_Info : public FixedBlockSize<8>, public VariableKeyLength<16, 8, 16, 8>, public VariableRounds<10, 1, 13>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "SAFER-K";}
};

/// \brief SAFER-K block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/SAFER-K">SAFER-K</a>
class SAFER_K : public SAFER_K_Info, public SAFER, public BlockCipherDocumentation
{
public:
	typedef BlockCipherFinal<ENCRYPTION, SAFER_Impl<Enc, SAFER_K_Info, false> > Encryption;
	typedef BlockCipherFinal<DECRYPTION, SAFER_Impl<Dec, SAFER_K_Info, false> > Decryption;
};

/// \brief SAFER-SK block cipher information
struct SAFER_SK_Info : public FixedBlockSize<8>, public VariableKeyLength<16, 8, 16, 8>, public VariableRounds<10, 1, 13>
{
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "SAFER-SK";}
};

/// \brief SAFER-SK block cipher
/// \sa <a href="http://www.cryptopp.com/wiki/SAFER-SK">SAFER-SK</a>
class SAFER_SK : public SAFER_SK_Info, public SAFER, public BlockCipherDocumentation
{
public:
	typedef BlockCipherFinal<ENCRYPTION, SAFER_Impl<Enc, SAFER_SK_Info, true> > Encryption;
	typedef BlockCipherFinal<DECRYPTION, SAFER_Impl<Dec, SAFER_SK_Info, true> > Decryption;
};

typedef SAFER_K::Encryption SAFER_K_Encryption;
typedef SAFER_K::Decryption SAFER_K_Decryption;

typedef SAFER_SK::Encryption SAFER_SK_Encryption;
typedef SAFER_SK::Decryption SAFER_SK_Decryption;

NAMESPACE_END

#endif
