// arc4.h - originally written and placed in the public domain by Wei Dai

/// \file arc4.h
/// \brief Classes for ARC4 cipher
/// \since Crypto++ 3.1

#ifndef CRYPTOPP_ARC4_H
#define CRYPTOPP_ARC4_H

#include "cryptlib.h"
#include "strciphr.h"
#include "secblock.h"
#include "smartptr.h"

NAMESPACE_BEGIN(CryptoPP)

namespace Weak1 {

/// \brief ARC4 base class
/// \details Implementations and overrides in \p Base apply to both \p ENCRYPTION and \p DECRYPTION directions
/// \since Crypto++ 3.1
class CRYPTOPP_NO_VTABLE ARC4_Base : public VariableKeyLength<16, 1, 256>, public RandomNumberGenerator, public SymmetricCipher, public SymmetricCipherDocumentation
{
public:
	~ARC4_Base();

	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "ARC4";}

	void GenerateBlock(byte *output, size_t size);
	void DiscardBytes(size_t n);

    void ProcessData(byte *outString, const byte *inString, size_t length);

	bool IsRandomAccess() const {return false;}
	bool IsSelfInverting() const {return true;}
	bool IsForwardTransformation() const {return true;}

	typedef SymmetricCipherFinal<ARC4_Base> Encryption;
	typedef SymmetricCipherFinal<ARC4_Base> Decryption;

protected:
	void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params);
	virtual unsigned int GetDefaultDiscardBytes() const {return 0;}

    FixedSizeSecBlock<byte, 256> m_state;
    byte m_x, m_y;
};

/// \brief Alleged RC4
/// \sa <a href="http://www.cryptopp.com/wiki/RC4">Alleged RC4</a>
/// \since Crypto++ 3.1
DOCUMENTED_TYPEDEF(SymmetricCipherFinal<ARC4_Base>, ARC4);

/// \brief MARC4 base class
/// \details Implementations and overrides in \p Base apply to both \p ENCRYPTION and \p DECRYPTION directions
/// \details MARC4 discards the first 256 bytes of keystream, which may be weaker than the rest
/// \since Crypto++ 3.1
class CRYPTOPP_NO_VTABLE MARC4_Base : public ARC4_Base
{
public:
	CRYPTOPP_STATIC_CONSTEXPR const char* StaticAlgorithmName() {return "MARC4";}

	typedef SymmetricCipherFinal<MARC4_Base> Encryption;
	typedef SymmetricCipherFinal<MARC4_Base> Decryption;

protected:
	unsigned int GetDefaultDiscardBytes() const {return 256;}
};

/// \brief Modified Alleged RC4
/// \sa <a href="http://www.cryptopp.com/wiki/RC4">Alleged RC4</a>
/// \since Crypto++ 3.1
DOCUMENTED_TYPEDEF(SymmetricCipherFinal<MARC4_Base>, MARC4);

}
#if CRYPTOPP_ENABLE_NAMESPACE_WEAK >= 1
namespace Weak {using namespace Weak1;}		// import Weak1 into CryptoPP::Weak
#else
using namespace Weak1;	// import Weak1 into CryptoPP with warning
#ifdef __GNUC__
#warning "You may be using a weak algorithm that has been retained for backwards compatibility. Please '#define CRYPTOPP_ENABLE_NAMESPACE_WEAK 1' before including this .h file and prepend the class name with 'Weak::' to remove this warning."
#else
#pragma message("You may be using a weak algorithm that has been retained for backwards compatibility. Please '#define CRYPTOPP_ENABLE_NAMESPACE_WEAK 1' before including this .h file and prepend the class name with 'Weak::' to remove this warning.")
#endif
#endif

NAMESPACE_END

#endif
