// dsa.h - originally written and placed in the public domain by Wei Dai

/// \file dsa.h
/// \brief Classes for the DSA signature algorithm

#ifndef CRYPTOPP_DSA_H
#define CRYPTOPP_DSA_H

#include "cryptlib.h"
#include "gfpcrypt.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief DSA Signature Format
/// \details The DSA signature format used by Crypto++ is as defined by IEEE P1363.
///  OpenSSL, Java and .Net use the DER format, and OpenPGP uses the OpenPGP format.
/// \sa <A HREF="http://www.cryptopp.com/wiki/DSAConvertSignatureFormat">DSAConvertSignatureFormat</A>
///  on the Crypto++ wiki.
/// \since Crypto++ 1.0
enum DSASignatureFormat {
	/// \brief Crypto++ native signature encoding format
	DSA_P1363,
	/// \brief signature encoding format used by OpenSSL, Java and .Net
	DSA_DER,
	/// \brief OpenPGP signature encoding format
	DSA_OPENPGP
};

/// \brief Converts between signature encoding formats
/// \param buffer byte buffer for the converted signature encoding
/// \param bufferSize the length of the converted signature encoding buffer
/// \param toFormat the source signature format
/// \param signature byte buffer for the existing signature encoding
/// \param signatureLen the length of the existing signature encoding buffer
/// \param fromFormat the source signature format
/// \return the number of bytes written during encoding
/// \details This function converts between these formats, and returns length
///  of signature in the target format. If <tt>toFormat == DSA_P1363</tt>, then
///  <tt>bufferSize</tt> must equal <tt>publicKey.SignatureLength()</tt> or
///  <tt>verifier.SignatureLength()</tt>.
/// \details If the destination buffer is too small then the output of the
///  encoded <tt>r</tt> and <tt>s</tt> will be truncated. Be sure to provide
///  an adequately sized buffer and check the return value for the number of
///  bytes written.
/// \sa <A HREF="http://www.cryptopp.com/wiki/DSAConvertSignatureFormat">DSAConvertSignatureFormat</A>
///  on the Crypto++ wiki.
/// \since Crypto++ 1.0
size_t DSAConvertSignatureFormat(byte *buffer, size_t bufferSize, DSASignatureFormat toFormat,
	const byte *signature, size_t signatureLen, DSASignatureFormat fromFormat);

NAMESPACE_END

#endif  // CRYPTOPP_DSA_H
