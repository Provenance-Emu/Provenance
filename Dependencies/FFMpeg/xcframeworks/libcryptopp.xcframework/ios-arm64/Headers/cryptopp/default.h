// default.h - originally written and placed in the public domain by Wei Dai

/// \file default.h
/// \brief Classes for DefaultEncryptor, DefaultDecryptor, DefaultEncryptorWithMAC and DefaultDecryptorWithMAC

#ifndef CRYPTOPP_DEFAULT_H
#define CRYPTOPP_DEFAULT_H

#include "sha.h"
#include "hmac.h"
#include "aes.h"
#include "des.h"
#include "modes.h"
#include "filters.h"
#include "smartptr.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Legacy block cipher for LegacyEncryptor, LegacyDecryptor, LegacyEncryptorWithMAC and LegacyDecryptorWithMAC
typedef DES_EDE2 LegacyBlockCipher;
/// \brief Legacy hash for use with LegacyEncryptorWithMAC and LegacyDecryptorWithMAC
typedef SHA1 LegacyHashModule;
/// \brief Legacy HMAC for use withLegacyEncryptorWithMAC and LegacyDecryptorWithMAC
typedef HMAC<LegacyHashModule> LegacyMAC;

/// \brief Default block cipher for DefaultEncryptor, DefaultDecryptor, DefaultEncryptorWithMAC and DefaultDecryptorWithMAC
typedef AES DefaultBlockCipher;
/// \brief Default hash for use with DefaultEncryptorWithMAC and DefaultDecryptorWithMAC
typedef SHA256 DefaultHashModule;
/// \brief Default HMAC for use withDefaultEncryptorWithMAC and DefaultDecryptorWithMAC
typedef HMAC<DefaultHashModule> DefaultMAC;

/// \brief Exception thrown when LegacyDecryptorWithMAC or DefaultDecryptorWithMAC decryption error is encountered
class DataDecryptorErr : public Exception
{
public:
	DataDecryptorErr(const std::string &s)
		: Exception(DATA_INTEGRITY_CHECK_FAILED, s) {}
};

/// \brief Exception thrown when a bad key is encountered in DefaultDecryptorWithMAC and LegacyDecryptorWithMAC
class KeyBadErr : public DataDecryptorErr
{
	public: KeyBadErr()
		: DataDecryptorErr("DataDecryptor: cannot decrypt message with this passphrase") {}
};

/// \brief Exception thrown when an incorrect MAC is encountered in DefaultDecryptorWithMAC and LegacyDecryptorWithMAC
class MACBadErr : public DataDecryptorErr
{
	public: MACBadErr()
		: DataDecryptorErr("DataDecryptorWithMAC: MAC check failed") {}
};

/// \brief Algorithm information for password-based encryptors and decryptors
template <unsigned int BlockSize, unsigned int KeyLength, unsigned int DigestSize, unsigned int SaltSize, unsigned int Iterations>
struct DataParametersInfo
{
	CRYPTOPP_CONSTANT(BLOCKSIZE  = BlockSize);
	CRYPTOPP_CONSTANT(KEYLENGTH  = KeyLength);
	CRYPTOPP_CONSTANT(SALTLENGTH = SaltSize);
	CRYPTOPP_CONSTANT(DIGESTSIZE = DigestSize);
	CRYPTOPP_CONSTANT(ITERATIONS = Iterations);
};

typedef DataParametersInfo<LegacyBlockCipher::BLOCKSIZE, LegacyBlockCipher::DEFAULT_KEYLENGTH, LegacyHashModule::DIGESTSIZE, 8, 200> LegacyParametersInfo;
typedef DataParametersInfo<DefaultBlockCipher::BLOCKSIZE, DefaultBlockCipher::DEFAULT_KEYLENGTH, DefaultHashModule::DIGESTSIZE, 8, 2500> DefaultParametersInfo;

/// \brief Password-based Encryptor
/// \tparam BC BlockCipher based class used for encryption
/// \tparam H HashTransformation based class used for mashing
/// \tparam Info Constants used by the algorithms
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256.
/// \sa DefaultEncryptor, DefaultDecryptor, LegacyEncryptor, LegacyDecryptor
/// \since Crypto++ 2.0
template <class BC, class H, class Info>
class DataEncryptor : public ProxyFilter, public Info
{
public:
	CRYPTOPP_CONSTANT(BLOCKSIZE  = Info::BLOCKSIZE);
	CRYPTOPP_CONSTANT(KEYLENGTH  = Info::KEYLENGTH);
	CRYPTOPP_CONSTANT(SALTLENGTH = Info::SALTLENGTH);
	CRYPTOPP_CONSTANT(DIGESTSIZE = Info::DIGESTSIZE);
	CRYPTOPP_CONSTANT(ITERATIONS = Info::ITERATIONS);

	/// \brief Construct a DataEncryptor
	/// \param passphrase a C-String password
	/// \param attachment a BufferedTransformation to attach to this object
	DataEncryptor(const char *passphrase, BufferedTransformation *attachment = NULLPTR);

	/// \brief Construct a DataEncryptor
	/// \param passphrase a byte string password
	/// \param passphraseLength the length of the byte string password
	/// \param attachment a BufferedTransformation to attach to this object
	DataEncryptor(const byte *passphrase, size_t passphraseLength, BufferedTransformation *attachment = NULLPTR);

protected:
	void FirstPut(const byte *);
	void LastPut(const byte *inString, size_t length);

private:
	SecByteBlock m_passphrase;
	typename CBC_Mode<BC>::Encryption m_cipher;
};

/// \brief Password-based Decryptor
/// \tparam BC BlockCipher based class used for encryption
/// \tparam H HashTransformation based class used for mashing
/// \tparam Info Constants used by the algorithms
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256.
/// \sa DefaultEncryptor, DefaultDecryptor, LegacyEncryptor, LegacyDecryptor
/// \since Crypto++ 2.0
template <class BC, class H, class Info>
class DataDecryptor : public ProxyFilter, public Info
{
public:
	CRYPTOPP_CONSTANT(BLOCKSIZE  = Info::BLOCKSIZE);
	CRYPTOPP_CONSTANT(KEYLENGTH  = Info::KEYLENGTH);
	CRYPTOPP_CONSTANT(SALTLENGTH = Info::SALTLENGTH);
	CRYPTOPP_CONSTANT(DIGESTSIZE = Info::DIGESTSIZE);
	CRYPTOPP_CONSTANT(ITERATIONS = Info::ITERATIONS);

	/// \brief Constructs a DataDecryptor
	/// \param passphrase a C-String password
	/// \param attachment a BufferedTransformation to attach to this object
	/// \param throwException a flag specifying whether an Exception should be thrown on error
	DataDecryptor(const char *passphrase, BufferedTransformation *attachment = NULLPTR, bool throwException=true);

	/// \brief Constructs a DataDecryptor
	/// \param passphrase a byte string password
	/// \param passphraseLength the length of the byte string password
	/// \param attachment a BufferedTransformation to attach to this object
	/// \param throwException a flag specifying whether an Exception should be thrown on error
	DataDecryptor(const byte *passphrase, size_t passphraseLength, BufferedTransformation *attachment = NULLPTR, bool throwException=true);

	enum State {WAITING_FOR_KEYCHECK, KEY_GOOD, KEY_BAD};
	State CurrentState() const {return m_state;}

protected:
	void FirstPut(const byte *inString);
	void LastPut(const byte *inString, size_t length);

	State m_state;

private:
	void CheckKey(const byte *salt, const byte *keyCheck);

	SecByteBlock m_passphrase;
	typename CBC_Mode<BC>::Decryption m_cipher;
	member_ptr<FilterWithBufferedInput> m_decryptor;
	bool m_throwException;

};

/// \brief Password-based encryptor with MAC
/// \tparam BC BlockCipher based class used for encryption
/// \tparam H HashTransformation based class used for mashing
/// \tparam MAC HashTransformation based class used for authentication
/// \tparam Info Constants used by the algorithms
/// \details DataEncryptorWithMAC uses a non-standard mashup function called Mash() to derive key
///   bits from the password.
/// \details The purpose of the function Mash() is to take an arbitrary length input string and
///   *deterministically* produce an arbitrary length output string such that (1) it looks random,
///   (2) no information about the input is deducible from it, and (3) it contains as much entropy
///   as it can hold, or the amount of entropy in the input string, whichever is smaller.
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256.
/// \sa DefaultEncryptorWithMAC, DefaultDecryptorWithMAC, LegacyDecryptorWithMAC, LegacyEncryptorWithMAC
/// \since Crypto++ 2.0
template <class BC, class H, class MAC, class Info>
class DataEncryptorWithMAC : public ProxyFilter
{
public:
	CRYPTOPP_CONSTANT(BLOCKSIZE  = Info::BLOCKSIZE);
	CRYPTOPP_CONSTANT(KEYLENGTH  = Info::KEYLENGTH);
	CRYPTOPP_CONSTANT(SALTLENGTH = Info::SALTLENGTH);
	CRYPTOPP_CONSTANT(DIGESTSIZE = Info::DIGESTSIZE);
	CRYPTOPP_CONSTANT(ITERATIONS = Info::ITERATIONS);

	/// \brief Constructs a DataEncryptorWithMAC
	/// \param passphrase a C-String password
	/// \param attachment a BufferedTransformation to attach to this object
	DataEncryptorWithMAC(const char *passphrase, BufferedTransformation *attachment = NULLPTR);

	/// \brief Constructs a DataEncryptorWithMAC
	/// \param passphrase a byte string password
	/// \param passphraseLength the length of the byte string password
	/// \param attachment a BufferedTransformation to attach to this object
	DataEncryptorWithMAC(const byte *passphrase, size_t passphraseLength, BufferedTransformation *attachment = NULLPTR);

protected:
	void FirstPut(const byte *inString) {CRYPTOPP_UNUSED(inString);}
	void LastPut(const byte *inString, size_t length);

private:
	member_ptr<MAC> m_mac;

};

/// \brief Password-based decryptor with MAC
/// \tparam BC BlockCipher based class used for encryption
/// \tparam H HashTransformation based class used for mashing
/// \tparam MAC HashTransformation based class used for authentication
/// \tparam Info Constants used by the algorithms
/// \details DataDecryptorWithMAC uses a non-standard mashup function called Mash() to derive key
///   bits from the password.
/// \details The purpose of the function Mash() is to take an arbitrary length input string and
///   *deterministically* produce an arbitrary length output string such that (1) it looks random,
///   (2) no information about the input is deducible from it, and (3) it contains as much entropy
///   as it can hold, or the amount of entropy in the input string, whichever is smaller.
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256.
/// \sa DefaultEncryptorWithMAC, DefaultDecryptorWithMAC, LegacyDecryptorWithMAC, LegacyEncryptorWithMAC
/// \since Crypto++ 2.0
template <class BC, class H, class MAC, class Info>
class DataDecryptorWithMAC : public ProxyFilter
{
public:
	CRYPTOPP_CONSTANT(BLOCKSIZE  = Info::BLOCKSIZE);
	CRYPTOPP_CONSTANT(KEYLENGTH  = Info::KEYLENGTH);
	CRYPTOPP_CONSTANT(SALTLENGTH = Info::SALTLENGTH);
	CRYPTOPP_CONSTANT(DIGESTSIZE = Info::DIGESTSIZE);
	CRYPTOPP_CONSTANT(ITERATIONS = Info::ITERATIONS);

	/// \brief Constructs a DataDecryptor
	/// \param passphrase a C-String password
	/// \param attachment a BufferedTransformation to attach to this object
	/// \param throwException a flag specifying whether an Exception should be thrown on error
	DataDecryptorWithMAC(const char *passphrase, BufferedTransformation *attachment = NULLPTR, bool throwException=true);

	/// \brief Constructs a DataDecryptor
	/// \param passphrase a byte string password
	/// \param passphraseLength the length of the byte string password
	/// \param attachment a BufferedTransformation to attach to this object
	/// \param throwException a flag specifying whether an Exception should be thrown on error
	DataDecryptorWithMAC(const byte *passphrase, size_t passphraseLength, BufferedTransformation *attachment = NULLPTR, bool throwException=true);

	typename DataDecryptor<BC,H,Info>::State CurrentState() const;
	bool CheckLastMAC() const;

protected:
	void FirstPut(const byte *inString) {CRYPTOPP_UNUSED(inString);}
	void LastPut(const byte *inString, size_t length);

private:
	member_ptr<MAC> m_mac;
	HashVerificationFilter *m_hashVerifier;
	bool m_throwException;
};

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief Password-based encryptor (deprecated)
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256. The updated algorithms are available with the
///   <tt>Default*</tt> classes, and the old algorithms are available with the <tt>Legacy*</tt> classes.
struct LegacyEncryptor : public DataEncryptor<LegacyBlockCipher,LegacyHashModule,LegacyParametersInfo> {};
/// \brief Password-based decryptor (deprecated)
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256. The updated algorithms are available with the
///   <tt>Default*</tt> classes, and the old algorithms are available with the <tt>Legacy*</tt> classes.
struct LegacyDecryptor : public DataDecryptor<LegacyBlockCipher,LegacyHashModule,LegacyParametersInfo> {};
/// \brief Password-based encryptor
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256. The updated algorithms are available with the
///   <tt>Default*</tt> classes, and the old algorithms are available with the <tt>Legacy*</tt> classes.
struct DefaultEncryptor : public DataEncryptor<DefaultBlockCipher,DefaultHashModule,DefaultParametersInfo> {};
/// \brief Password-based decryptor
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256. The updated algorithms are available with the
///   <tt>Default*</tt> classes, and the old algorithms are available with the <tt>Legacy*</tt> classes.
struct DefaultDecryptor : public DataDecryptor<DefaultBlockCipher,DefaultHashModule,DefaultParametersInfo> {};
/// \brief Password-based encryptor with MAC (deprecated)
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256. The updated algorithms are available with the
///   <tt>Default*</tt> classes, and the old algorithms are available with the <tt>Legacy*</tt> classes.
struct LegacyEncryptorWithMAC : public DataEncryptorWithMAC<LegacyBlockCipher,LegacyHashModule,LegacyMAC,LegacyParametersInfo> {};
/// \brief Password-based decryptor with MAC (deprecated)
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256. The updated algorithms are available with the
///   <tt>Default*</tt> classes, and the old algorithms are available with the <tt>Legacy*</tt> classes.
struct LegacyDecryptorWithMAC : public DataDecryptorWithMAC<LegacyBlockCipher,LegacyHashModule,LegacyMAC,LegacyParametersInfo> {};
/// \brief Password-based encryptor with MAC
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256. The updated algorithms are available with the
///   <tt>Default*</tt> classes, and the old algorithms are available with the <tt>Legacy*</tt> classes.
struct DefaultEncryptorWithMAC : public DataEncryptorWithMAC<DefaultBlockCipher,DefaultHashModule,DefaultMAC,DefaultParametersInfo> {};
/// \brief Password-based decryptor with MAC
/// \details Crypto++ 5.6.5 and earlier used the legacy algorithms, including DES_EDE2 and SHA1.
///   Crypto++ 5.7 switched to AES and SHA256. The updated algorithms are available with the
///   <tt>Default*</tt> classes, and the old algorithms are available with the <tt>Legacy*</tt> classes.
struct DefaultDecryptorWithMAC : public DataDecryptorWithMAC<DefaultBlockCipher,DefaultHashModule,DefaultMAC,DefaultParametersInfo> {};
#else
typedef DataEncryptor<LegacyBlockCipher,LegacyHashModule,LegacyParametersInfo> LegacyEncryptor;
typedef DataDecryptor<LegacyBlockCipher,LegacyHashModule,LegacyParametersInfo> LegacyDecryptor;

typedef DataEncryptor<DefaultBlockCipher,DefaultHashModule,DefaultParametersInfo> DefaultEncryptor;
typedef DataDecryptor<DefaultBlockCipher,DefaultHashModule,DefaultParametersInfo> DefaultDecryptor;

typedef DataEncryptorWithMAC<LegacyBlockCipher,LegacyHashModule,LegacyMAC,LegacyParametersInfo> LegacyEncryptorWithMAC;
typedef DataDecryptorWithMAC<LegacyBlockCipher,LegacyHashModule,LegacyMAC,LegacyParametersInfo> LegacyDecryptorWithMAC;

typedef DataEncryptorWithMAC<DefaultBlockCipher,DefaultHashModule,DefaultMAC,DefaultParametersInfo> DefaultEncryptorWithMAC;
typedef DataDecryptorWithMAC<DefaultBlockCipher,DefaultHashModule,DefaultMAC,DefaultParametersInfo> DefaultDecryptorWithMAC;
#endif

NAMESPACE_END

#endif
