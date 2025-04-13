// strciphr.h - originally written and placed in the public domain by Wei Dai

/// \file strciphr.h
/// \brief Classes for implementing stream ciphers
/// \details This file contains helper classes for implementing stream ciphers.
///  All this infrastructure may look very complex compared to what's in Crypto++ 4.x,
///  but stream ciphers implementations now support a lot of new functionality,
///  including better performance (minimizing copying), resetting of keys and IVs, and
///  methods to query which features are supported by a cipher.
/// \details Here's an explanation of these classes. The word "policy" is used here to
///  mean a class with a set of methods that must be implemented by individual stream
///  cipher implementations. This is usually much simpler than the full stream cipher
///  API, which is implemented by either AdditiveCipherTemplate or CFB_CipherTemplate
///  using the policy. So for example, an implementation of SEAL only needs to implement
///  the AdditiveCipherAbstractPolicy interface (since it's an additive cipher, i.e., it
///  xors a keystream into the plaintext). See this line in seal.h:
/// <pre>
///     typedef SymmetricCipherFinal\<ConcretePolicyHolder\<SEAL_Policy\<B\>, AdditiveCipherTemplate\<\> \> \> Encryption;
/// </pre>
/// \details AdditiveCipherTemplate and CFB_CipherTemplate are designed so that they don't
///  need to take a policy class as a template parameter (although this is allowed), so
///  that their code is not duplicated for each new cipher. Instead they each get a
///  reference to an abstract policy interface by calling AccessPolicy() on itself, so
///  AccessPolicy() must be overridden to return the actual policy reference. This is done
///  by the ConcretePolicyHolder class. Finally, SymmetricCipherFinal implements the
///  constructors and other functions that must be implemented by the most derived class.

#ifndef CRYPTOPP_STRCIPHR_H
#define CRYPTOPP_STRCIPHR_H

#include "config.h"

#if CRYPTOPP_MSC_VERSION
# pragma warning(push)
# pragma warning(disable: 4127 4189 4231 4275)
#endif

#include "cryptlib.h"
#include "seckey.h"
#include "secblock.h"
#include "argnames.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Access a stream cipher policy object
/// \tparam POLICY_INTERFACE class implementing AbstractPolicyHolder
/// \tparam BASE class or type to use as a base class
template <class POLICY_INTERFACE, class BASE = Empty>
class CRYPTOPP_NO_VTABLE AbstractPolicyHolder : public BASE
{
public:
	typedef POLICY_INTERFACE PolicyInterface;
	virtual ~AbstractPolicyHolder() {}

protected:
	virtual const POLICY_INTERFACE & GetPolicy() const =0;
	virtual POLICY_INTERFACE & AccessPolicy() =0;
};

/// \brief Stream cipher policy object
/// \tparam POLICY class implementing AbstractPolicyHolder
/// \tparam BASE class or type to use as a base class
template <class POLICY, class BASE, class POLICY_INTERFACE = typename BASE::PolicyInterface>
class ConcretePolicyHolder : public BASE, protected POLICY
{
public:
	virtual ~ConcretePolicyHolder() {}
protected:
	const POLICY_INTERFACE & GetPolicy() const {return *this;}
	POLICY_INTERFACE & AccessPolicy() {return *this;}
};

/// \brief Keystream operation flags
/// \sa AdditiveCipherAbstractPolicy::GetBytesPerIteration(), AdditiveCipherAbstractPolicy::GetOptimalBlockSize()
///  and AdditiveCipherAbstractPolicy::GetAlignment()
enum KeystreamOperationFlags {
	/// \brief Output buffer is aligned
	OUTPUT_ALIGNED=1,
	/// \brief Input buffer is aligned
	INPUT_ALIGNED=2,
	/// \brief Input buffer is NULL
	INPUT_NULL = 4
};

/// \brief Keystream operation flags
/// \sa AdditiveCipherAbstractPolicy::GetBytesPerIteration(), AdditiveCipherAbstractPolicy::GetOptimalBlockSize()
///  and AdditiveCipherAbstractPolicy::GetAlignment()
enum KeystreamOperation {
	/// \brief Write the keystream to the output buffer, input is NULL
	WRITE_KEYSTREAM				= INPUT_NULL,
	/// \brief Write the keystream to the aligned output buffer, input is NULL
	WRITE_KEYSTREAM_ALIGNED		= INPUT_NULL | OUTPUT_ALIGNED,
	/// \brief XOR the input buffer and keystream, write to the output buffer
	XOR_KEYSTREAM				= 0,
	/// \brief XOR the aligned input buffer and keystream, write to the output buffer
	XOR_KEYSTREAM_INPUT_ALIGNED = INPUT_ALIGNED,
	/// \brief XOR the input buffer and keystream, write to the aligned output buffer
	XOR_KEYSTREAM_OUTPUT_ALIGNED= OUTPUT_ALIGNED,
	/// \brief XOR the aligned input buffer and keystream, write to the aligned output buffer
	XOR_KEYSTREAM_BOTH_ALIGNED	= OUTPUT_ALIGNED | INPUT_ALIGNED
};

/// \brief Policy object for additive stream ciphers
struct CRYPTOPP_DLL CRYPTOPP_NO_VTABLE AdditiveCipherAbstractPolicy
{
	virtual ~AdditiveCipherAbstractPolicy() {}

	/// \brief Provides data alignment requirements
	/// \return data alignment requirements, in bytes
	/// \details Internally, the default implementation returns 1. If the stream cipher is implemented
	///  using an SSE2 ASM or intrinsics, then the value returned is usually 16.
	virtual unsigned int GetAlignment() const {return 1;}

	/// \brief Provides number of bytes operated upon during an iteration
	/// \return bytes operated upon during an iteration, in bytes
	/// \sa GetOptimalBlockSize()
	virtual unsigned int GetBytesPerIteration() const =0;

	/// \brief Provides number of ideal bytes to process
	/// \return the ideal number of bytes to process
	/// \details Internally, the default implementation returns GetBytesPerIteration()
	/// \sa GetBytesPerIteration()
	virtual unsigned int GetOptimalBlockSize() const {return GetBytesPerIteration();}

	/// \brief Provides buffer size based on iterations
	/// \return the buffer size based on iterations, in bytes
	virtual unsigned int GetIterationsToBuffer() const =0;

	/// \brief Generate the keystream
	/// \param keystream the key stream
	/// \param iterationCount the number of iterations to generate the key stream
	/// \sa CanOperateKeystream(), OperateKeystream(), WriteKeystream()
	virtual void WriteKeystream(byte *keystream, size_t iterationCount)
		{OperateKeystream(KeystreamOperation(INPUT_NULL | static_cast<KeystreamOperationFlags>(IsAlignedOn(keystream, GetAlignment()))), keystream, NULLPTR, iterationCount);}

	/// \brief Flag indicating
	/// \return true if the stream can be generated independent of the transformation input, false otherwise
	/// \sa CanOperateKeystream(), OperateKeystream(), WriteKeystream()
	virtual bool CanOperateKeystream() const {return false;}

	/// \brief Operates the keystream
	/// \param operation the operation with additional flags
	/// \param output the output buffer
	/// \param input the input buffer
	/// \param iterationCount the number of iterations to perform on the input
	/// \details OperateKeystream() will attempt to operate upon GetOptimalBlockSize() buffer,
	///  which will be derived from GetBytesPerIteration().
	/// \sa CanOperateKeystream(), OperateKeystream(), WriteKeystream(), KeystreamOperation()
	virtual void OperateKeystream(KeystreamOperation operation, byte *output, const byte *input, size_t iterationCount)
		{CRYPTOPP_UNUSED(operation); CRYPTOPP_UNUSED(output); CRYPTOPP_UNUSED(input);
		CRYPTOPP_UNUSED(iterationCount); CRYPTOPP_ASSERT(false);}

	/// \brief Key the cipher
	/// \param params set of NameValuePairs use to initialize this object
	/// \param key a byte array used to key the cipher
	/// \param length the size of the key array
	virtual void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length) =0;

	/// \brief Resynchronize the cipher
	/// \param keystreamBuffer the keystream buffer
	/// \param iv a byte array used to resynchronize the cipher
	/// \param length the size of the IV array
	virtual void CipherResynchronize(byte *keystreamBuffer, const byte *iv, size_t length)
		{CRYPTOPP_UNUSED(keystreamBuffer); CRYPTOPP_UNUSED(iv); CRYPTOPP_UNUSED(length);
		throw NotImplemented("SimpleKeyingInterface: this object doesn't support resynchronization");}

	/// \brief Flag indicating random access
	/// \return true if the cipher is seekable, false otherwise
	/// \sa SeekToIteration()
	virtual bool CipherIsRandomAccess() const =0;

	/// \brief Seeks to a random position in the stream
	/// \sa CipherIsRandomAccess()
	virtual void SeekToIteration(lword iterationCount)
		{CRYPTOPP_UNUSED(iterationCount); CRYPTOPP_ASSERT(!CipherIsRandomAccess());
		throw NotImplemented("StreamTransformation: this object doesn't support random access");}

	/// \brief Retrieve the provider of this algorithm
	/// \return the algorithm provider
	/// \details The algorithm provider can be a name like "C++", "SSE", "NEON", "AESNI",
	///  "ARMv8" and "Power8". C++ is standard C++ code. Other labels, like SSE,
	///  usually indicate a specialized implementation using instructions from a higher
	///  instruction set architecture (ISA). Future labels may include external hardware
	///  like a hardware security module (HSM).
	/// \details Generally speaking Wei Dai's original IA-32 ASM code falls under "SSE2".
	///  Labels like "SSSE3" and "SSE4.1" follow after Wei's code and use intrinsics
	///  instead of ASM.
	/// \details Algorithms which combine different instructions or ISAs provide the
	///  dominant one. For example on x86 <tt>AES/GCM</tt> returns "AESNI" rather than
	///  "CLMUL" or "AES+SSE4.1" or "AES+CLMUL" or "AES+SSE4.1+CLMUL".
	/// \note Provider is not universally implemented yet.
	virtual std::string AlgorithmProvider() const { return "C++"; }
};

/// \brief Base class for additive stream ciphers
/// \tparam WT word type
/// \tparam W count of words
/// \tparam X bytes per iteration count
/// \tparam BASE AdditiveCipherAbstractPolicy derived base class
template <typename WT, unsigned int W, unsigned int X = 1, class BASE = AdditiveCipherAbstractPolicy>
struct CRYPTOPP_NO_VTABLE AdditiveCipherConcretePolicy : public BASE
{
	/// \brief Word type for the cipher
	typedef WT WordType;

	/// \brief Number of bytes for an iteration
	/// \details BYTES_PER_ITERATION is the product <tt>sizeof(WordType) * W</tt>.
	///  For example, ChaCha uses 16 each <tt>word32</tt>, and the value of
	///  BYTES_PER_ITERATION is 64. Each invocation of the ChaCha block function
	///  produces 64 bytes of keystream.
	CRYPTOPP_CONSTANT(BYTES_PER_ITERATION = sizeof(WordType) * W);

	virtual ~AdditiveCipherConcretePolicy() {}

	/// \brief Provides data alignment requirements
	/// \return data alignment requirements, in bytes
	/// \details Internally, the default implementation returns 1. If the stream
	///  cipher is implemented using an SSE2 ASM or intrinsics, then the value
	///  returned is usually 16.
	unsigned int GetAlignment() const {return GetAlignmentOf<WordType>();}

	/// \brief Provides number of bytes operated upon during an iteration
	/// \return bytes operated upon during an iteration, in bytes
	/// \sa GetOptimalBlockSize()
	unsigned int GetBytesPerIteration() const {return BYTES_PER_ITERATION;}

	/// \brief Provides buffer size based on iterations
	/// \return the buffer size based on iterations, in bytes
	unsigned int GetIterationsToBuffer() const {return X;}

	/// \brief Flag indicating
	/// \return true if the stream can be generated independent of the
	///  transformation input, false otherwise
	/// \sa CanOperateKeystream(), OperateKeystream(), WriteKeystream()
	bool CanOperateKeystream() const {return true;}

	/// \brief Operates the keystream
	/// \param operation the operation with additional flags
	/// \param output the output buffer
	/// \param input the input buffer
	/// \param iterationCount the number of iterations to perform on the input
	/// \details OperateKeystream() will attempt to operate upon GetOptimalBlockSize() buffer,
	///  which will be derived from GetBytesPerIteration().
	/// \sa CanOperateKeystream(), OperateKeystream(), WriteKeystream(), KeystreamOperation()
	virtual void OperateKeystream(KeystreamOperation operation, byte *output, const byte *input, size_t iterationCount) =0;
};

/// \brief Helper macro to implement OperateKeystream
/// \param x KeystreamOperation mask
/// \param b Endian order
/// \param i index in output buffer
/// \param a value to output
#define CRYPTOPP_KEYSTREAM_OUTPUT_WORD(x, b, i, a)	\
	PutWord(((x & OUTPUT_ALIGNED) != 0), b, output+i*sizeof(WordType), (x & INPUT_NULL) ? (a) : (a) ^ GetWord<WordType>(((x & INPUT_ALIGNED) != 0), b, input+i*sizeof(WordType)));

/// \brief Helper macro to implement OperateKeystream
/// \param x KeystreamOperation mask
/// \param i index in output buffer
/// \param a value to output
#define CRYPTOPP_KEYSTREAM_OUTPUT_XMM(x, i, a)	{\
	__m128i t = (x & INPUT_NULL) ? a : _mm_xor_si128(a, (x & INPUT_ALIGNED) ? _mm_load_si128((__m128i *)input+i) : _mm_loadu_si128((__m128i *)input+i));\
	if (x & OUTPUT_ALIGNED) _mm_store_si128((__m128i *)output+i, t);\
	else _mm_storeu_si128((__m128i *)output+i, t);}

/// \brief Helper macro to implement OperateKeystream
#define CRYPTOPP_KEYSTREAM_OUTPUT_SWITCH(x, y)		\
	switch (operation)								\
	{												\
		case WRITE_KEYSTREAM:						\
			x(EnumToInt(WRITE_KEYSTREAM))	\
			break;									\
		case XOR_KEYSTREAM:							\
			x(EnumToInt(XOR_KEYSTREAM))		\
			input += y;								\
			break;									\
		case XOR_KEYSTREAM_INPUT_ALIGNED:			\
			x(EnumToInt(XOR_KEYSTREAM_INPUT_ALIGNED))		\
			input += y;								\
			break;									\
		case XOR_KEYSTREAM_OUTPUT_ALIGNED:			\
			x(EnumToInt(XOR_KEYSTREAM_OUTPUT_ALIGNED))		\
			input += y;								\
			break;									\
		case WRITE_KEYSTREAM_ALIGNED:				\
			x(EnumToInt(WRITE_KEYSTREAM_ALIGNED))			\
			break;									\
		case XOR_KEYSTREAM_BOTH_ALIGNED:			\
			x(EnumToInt(XOR_KEYSTREAM_BOTH_ALIGNED))		\
			input += y;								\
			break;									\
	}												\
	output += y;

/// \brief Base class for additive stream ciphers with SymmetricCipher interface
/// \tparam BASE AbstractPolicyHolder base class
template <class BASE = AbstractPolicyHolder<AdditiveCipherAbstractPolicy, SymmetricCipher> >
class CRYPTOPP_NO_VTABLE AdditiveCipherTemplate : public BASE, public RandomNumberGenerator
{
public:
	virtual ~AdditiveCipherTemplate() {}
	AdditiveCipherTemplate() : m_leftOver(0) {}

	/// \brief Generate random array of bytes
	/// \param output the byte buffer
	/// \param size the length of the buffer, in bytes
	/// \details All generated values are uniformly distributed over the range specified
	///  within the constraints of a particular generator.
	void GenerateBlock(byte *output, size_t size);

	/// \brief Apply keystream to data
	/// \param outString a buffer to write the transformed data
	/// \param inString a buffer to read the data
	/// \param length the size of the buffers, in bytes
	/// \details This is the primary method to operate a stream cipher. For example:
	/// <pre>
	///     size_t size = 30;
	///     byte plain[size] = "Do or do not; there is no try";
	///     byte cipher[size];
	///     ...
	///     ChaCha20 chacha(key, keySize);
	///     chacha.ProcessData(cipher, plain, size);
	/// </pre>
	/// \details You should use distinct buffers for inString and outString. If the buffers
	///  are the same, then the data will be copied to an internal buffer to avoid GCC alias
	///  violations. The internal copy will impact performance.
	/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/1088">Issue 1088, 36% loss
	///  of performance with AES</A>, <A HREF="https://github.com/weidai11/cryptopp/issues/1010">Issue
	///  1010, HIGHT cipher troubles with FileSource</A>
	void ProcessData(byte *outString, const byte *inString, size_t length);

	/// \brief Resynchronize the cipher
	/// \param iv a byte array used to resynchronize the cipher
	/// \param length the size of the IV array
	void Resynchronize(const byte *iv, int length=-1);

	/// \brief Provides number of ideal bytes to process
	/// \return the ideal number of bytes to process
	/// \details Internally, the default implementation returns GetBytesPerIteration()
	/// \sa GetBytesPerIteration() and GetOptimalNextBlockSize()
	unsigned int OptimalBlockSize() const {return this->GetPolicy().GetOptimalBlockSize();}

	/// \brief Provides number of ideal bytes to process
	/// \return the ideal number of bytes to process
	/// \details Internally, the default implementation returns remaining unprocessed bytes
	/// \sa GetBytesPerIteration() and OptimalBlockSize()
	unsigned int GetOptimalNextBlockSize() const {return (unsigned int)this->m_leftOver;}

	/// \brief Provides number of ideal data alignment
	/// \return the ideal data alignment, in bytes
	/// \sa GetAlignment() and OptimalBlockSize()
	unsigned int OptimalDataAlignment() const {return this->GetPolicy().GetAlignment();}

	/// \brief Determines if the cipher is self inverting
	/// \return true if the stream cipher is self inverting, false otherwise
	bool IsSelfInverting() const {return true;}

	/// \brief Determines if the cipher is a forward transformation
	/// \return true if the stream cipher is a forward transformation, false otherwise
	bool IsForwardTransformation() const {return true;}

	/// \brief Flag indicating random access
	/// \return true if the cipher is seekable, false otherwise
	/// \sa Seek()
	bool IsRandomAccess() const {return this->GetPolicy().CipherIsRandomAccess();}

	/// \brief Seeks to a random position in the stream
	/// \param position the absolute position in the stream
	/// \sa IsRandomAccess()
	void Seek(lword position);

	/// \brief Retrieve the provider of this algorithm
	/// \return the algorithm provider
	/// \details The algorithm provider can be a name like "C++", "SSE", "NEON", "AESNI",
	///  "ARMv8" and "Power8". C++ is standard C++ code. Other labels, like SSE,
	///  usually indicate a specialized implementation using instructions from a higher
	///  instruction set architecture (ISA). Future labels may include external hardware
	///  like a hardware security module (HSM).
	/// \details Generally speaking Wei Dai's original IA-32 ASM code falls under "SSE2".
	///  Labels like "SSSE3" and "SSE4.1" follow after Wei's code and use intrinsics
	///  instead of ASM.
	/// \details Algorithms which combine different instructions or ISAs provide the
	///  dominant one. For example on x86 <tt>AES/GCM</tt> returns "AESNI" rather than
	///  "CLMUL" or "AES+SSE4.1" or "AES+CLMUL" or "AES+SSE4.1+CLMUL".
	/// \note Provider is not universally implemented yet.
	std::string AlgorithmProvider() const { return this->GetPolicy().AlgorithmProvider(); }

	typedef typename BASE::PolicyInterface PolicyInterface;

protected:
	void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params);

	unsigned int GetBufferByteSize(const PolicyInterface &policy) const {return policy.GetBytesPerIteration() * policy.GetIterationsToBuffer();}

	inline byte * KeystreamBufferBegin() {return this->m_buffer.data();}
	inline byte * KeystreamBufferEnd() {return (PtrAdd(this->m_buffer.data(), this->m_buffer.size()));}

	AlignedSecByteBlock m_buffer;
	size_t m_leftOver;
};

/// \brief Policy object for feedback based stream ciphers
class CRYPTOPP_DLL CRYPTOPP_NO_VTABLE CFB_CipherAbstractPolicy
{
public:
	virtual ~CFB_CipherAbstractPolicy() {}

	/// \brief Provides data alignment requirements
	/// \return data alignment requirements, in bytes
	/// \details Internally, the default implementation returns 1. If the stream cipher is implemented
	///  using an SSE2 ASM or intrinsics, then the value returned is usually 16.
	virtual unsigned int GetAlignment() const =0;

	/// \brief Provides number of bytes operated upon during an iteration
	/// \return bytes operated upon during an iteration, in bytes
	/// \sa GetOptimalBlockSize()
	virtual unsigned int GetBytesPerIteration() const =0;

	/// \brief Access the feedback register
	/// \return pointer to the first byte of the feedback register
	virtual byte * GetRegisterBegin() =0;

	/// \brief TODO
	virtual void TransformRegister() =0;

	/// \brief Flag indicating iteration support
	/// \return true if the cipher supports iteration, false otherwise
	virtual bool CanIterate() const {return false;}

	/// \brief Iterate the cipher
	/// \param output the output buffer
	/// \param input the input buffer
	/// \param dir the direction of the cipher
	/// \param iterationCount the number of iterations to perform on the input
	/// \sa IsSelfInverting() and IsForwardTransformation()
	virtual void Iterate(byte *output, const byte *input, CipherDir dir, size_t iterationCount)
		{CRYPTOPP_UNUSED(output); CRYPTOPP_UNUSED(input); CRYPTOPP_UNUSED(dir);
		CRYPTOPP_UNUSED(iterationCount); CRYPTOPP_ASSERT(false);
		throw Exception(Exception::OTHER_ERROR, "SimpleKeyingInterface: unexpected error");}

	/// \brief Key the cipher
	/// \param params set of NameValuePairs use to initialize this object
	/// \param key a byte array used to key the cipher
	/// \param length the size of the key array
	virtual void CipherSetKey(const NameValuePairs &params, const byte *key, size_t length) =0;

	/// \brief Resynchronize the cipher
	/// \param iv a byte array used to resynchronize the cipher
	/// \param length the size of the IV array
	virtual void CipherResynchronize(const byte *iv, size_t length)
		{CRYPTOPP_UNUSED(iv); CRYPTOPP_UNUSED(length);
		throw NotImplemented("SimpleKeyingInterface: this object doesn't support resynchronization");}

	/// \brief Retrieve the provider of this algorithm
	/// \return the algorithm provider
	/// \details The algorithm provider can be a name like "C++", "SSE", "NEON", "AESNI",
	///  "ARMv8" and "Power8". C++ is standard C++ code. Other labels, like SSE,
	///  usually indicate a specialized implementation using instructions from a higher
	///  instruction set architecture (ISA). Future labels may include external hardware
	///  like a hardware security module (HSM).
	/// \details Generally speaking Wei Dai's original IA-32 ASM code falls under "SSE2".
	///  Labels like "SSSE3" and "SSE4.1" follow after Wei's code and use intrinsics
	///  instead of ASM.
	/// \details Algorithms which combine different instructions or ISAs provide the
	///  dominant one. For example on x86 <tt>AES/GCM</tt> returns "AESNI" rather than
	///  "CLMUL" or "AES+SSE4.1" or "AES+CLMUL" or "AES+SSE4.1+CLMUL".
	/// \note Provider is not universally implemented yet.
	virtual std::string AlgorithmProvider() const { return "C++"; }
};

/// \brief Base class for feedback based stream ciphers
/// \tparam WT word type
/// \tparam W count of words
/// \tparam BASE CFB_CipherAbstractPolicy derived base class
template <typename WT, unsigned int W, class BASE = CFB_CipherAbstractPolicy>
struct CRYPTOPP_NO_VTABLE CFB_CipherConcretePolicy : public BASE
{
	typedef WT WordType;

	virtual ~CFB_CipherConcretePolicy() {}

	/// \brief Provides data alignment requirements
	/// \return data alignment requirements, in bytes
	/// \details Internally, the default implementation returns 1. If the stream cipher is implemented
	///   using an SSE2 ASM or intrinsics, then the value returned is usually 16.
	unsigned int GetAlignment() const {return sizeof(WordType);}

	/// \brief Provides number of bytes operated upon during an iteration
	/// \return bytes operated upon during an iteration, in bytes
	/// \sa GetOptimalBlockSize()
	unsigned int GetBytesPerIteration() const {return sizeof(WordType) * W;}

	/// \brief Flag indicating iteration support
	/// \return true if the cipher supports iteration, false otherwise
	bool CanIterate() const {return true;}

	/// \brief Perform one iteration in the forward direction
	void TransformRegister() {this->Iterate(NULLPTR, NULLPTR, ENCRYPTION, 1);}

	/// \brief Provides alternate access to a feedback register
	/// \tparam B enumeration indicating endianness
	/// \details RegisterOutput() provides alternate access to the feedback register. The
	///   enumeration B is BigEndian or LittleEndian. Repeatedly applying operator()
	///   results in advancing in the register.
	template <class B>
	struct RegisterOutput
	{
		RegisterOutput(byte *output, const byte *input, CipherDir dir)
			: m_output(output), m_input(input), m_dir(dir) {}

		/// \brief XOR feedback register with data
		/// \param registerWord data represented as a word type
		/// \return reference to the next feedback register word
		inline RegisterOutput& operator()(WordType &registerWord)
		{
			//CRYPTOPP_ASSERT(IsAligned<WordType>(m_output));
			//CRYPTOPP_ASSERT(IsAligned<WordType>(m_input));

			if (!NativeByteOrderIs(B::ToEnum()))
				registerWord = ByteReverse(registerWord);

			if (m_dir == ENCRYPTION)
			{
				if (m_input == NULLPTR)
				{
					CRYPTOPP_ASSERT(m_output == NULLPTR);
				}
				else
				{
					// WordType ct = *(const WordType *)m_input ^ registerWord;
					WordType ct = GetWord<WordType>(false, NativeByteOrder::ToEnum(), m_input) ^ registerWord;
					registerWord = ct;

					// *(WordType*)m_output = ct;
					PutWord<WordType>(false, NativeByteOrder::ToEnum(), m_output, ct);

					m_input += sizeof(WordType);
					m_output += sizeof(WordType);
				}
			}
			else
			{
				// WordType ct = *(const WordType *)m_input;
				WordType ct = GetWord<WordType>(false, NativeByteOrder::ToEnum(), m_input);

				// *(WordType*)m_output = registerWord ^ ct;
				PutWord<WordType>(false, NativeByteOrder::ToEnum(), m_output, registerWord ^ ct);
				registerWord = ct;

				m_input += sizeof(WordType);
				m_output += sizeof(WordType);
			}

			// registerWord is left unreversed so it can be xor-ed with further input

			return *this;
		}

		byte *m_output;
		const byte *m_input;
		CipherDir m_dir;
	};
};

/// \brief Base class for feedback based stream ciphers with SymmetricCipher interface
/// \tparam BASE AbstractPolicyHolder base class
template <class BASE>
class CRYPTOPP_NO_VTABLE CFB_CipherTemplate : public BASE
{
public:
	virtual ~CFB_CipherTemplate() {}
	CFB_CipherTemplate() : m_leftOver(0) {}

	/// \brief Apply keystream to data
	/// \param outString a buffer to write the transformed data
	/// \param inString a buffer to read the data
	/// \param length the size of the buffers, in bytes
	/// \details This is the primary method to operate a stream cipher. For example:
	/// <pre>
	///     size_t size = 30;
	///     byte plain[size] = "Do or do not; there is no try";
	///     byte cipher[size];
	///     ...
	///     ChaCha20 chacha(key, keySize);
	///     chacha.ProcessData(cipher, plain, size);
	/// </pre>
	/// \details You should use distinct buffers for inString and outString. If the buffers
	///  are the same, then the data will be copied to an internal buffer to avoid GCC alias
	///  violations. The internal copy will impact performance.
	/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/1088">Issue 1088, 36% loss
	///  of performance with AES</A>, <A HREF="https://github.com/weidai11/cryptopp/issues/1010">Issue
	///  1010, HIGHT cipher troubles with FileSource</A>
	void ProcessData(byte *outString, const byte *inString, size_t length);

	/// \brief Resynchronize the cipher
	/// \param iv a byte array used to resynchronize the cipher
	/// \param length the size of the IV array
	void Resynchronize(const byte *iv, int length=-1);

	/// \brief Provides number of ideal bytes to process
	/// \return the ideal number of bytes to process
	/// \details Internally, the default implementation returns GetBytesPerIteration()
	/// \sa GetBytesPerIteration() and GetOptimalNextBlockSize()
	unsigned int OptimalBlockSize() const {return this->GetPolicy().GetBytesPerIteration();}

	/// \brief Provides number of ideal bytes to process
	/// \return the ideal number of bytes to process
	/// \details Internally, the default implementation returns remaining unprocessed bytes
	/// \sa GetBytesPerIteration() and OptimalBlockSize()
	unsigned int GetOptimalNextBlockSize() const {return (unsigned int)m_leftOver;}

	/// \brief Provides number of ideal data alignment
	/// \return the ideal data alignment, in bytes
	/// \sa GetAlignment() and OptimalBlockSize()
	unsigned int OptimalDataAlignment() const {return this->GetPolicy().GetAlignment();}

	/// \brief Flag indicating random access
	/// \return true if the cipher is seekable, false otherwise
	/// \sa Seek()
	bool IsRandomAccess() const {return false;}

	/// \brief Determines if the cipher is self inverting
	/// \return true if the stream cipher is self inverting, false otherwise
	bool IsSelfInverting() const {return false;}

	/// \brief Retrieve the provider of this algorithm
	/// \return the algorithm provider
	/// \details The algorithm provider can be a name like "C++", "SSE", "NEON", "AESNI",
	///  "ARMv8" and "Power8". C++ is standard C++ code. Other labels, like SSE,
	///  usually indicate a specialized implementation using instructions from a higher
	///  instruction set architecture (ISA). Future labels may include external hardware
	///  like a hardware security module (HSM).
	/// \details Generally speaking Wei Dai's original IA-32 ASM code falls under "SSE2".
	///  Labels like "SSSE3" and "SSE4.1" follow after Wei's code and use intrinsics
	///  instead of ASM.
	/// \details Algorithms which combine different instructions or ISAs provide the
	///  dominant one. For example on x86 <tt>AES/GCM</tt> returns "AESNI" rather than
	///  "CLMUL" or "AES+SSE4.1" or "AES+CLMUL" or "AES+SSE4.1+CLMUL".
	/// \note Provider is not universally implemented yet.
	std::string AlgorithmProvider() const { return this->GetPolicy().AlgorithmProvider(); }

	typedef typename BASE::PolicyInterface PolicyInterface;

protected:
	virtual void CombineMessageAndShiftRegister(byte *output, byte *reg, const byte *message, size_t length) =0;

	void UncheckedSetKey(const byte *key, unsigned int length, const NameValuePairs &params);

	size_t m_leftOver;
};

/// \brief Base class for feedback based stream ciphers in the forward direction with SymmetricCipher interface
/// \tparam BASE AbstractPolicyHolder base class
template <class BASE = AbstractPolicyHolder<CFB_CipherAbstractPolicy, SymmetricCipher> >
class CRYPTOPP_NO_VTABLE CFB_EncryptionTemplate : public CFB_CipherTemplate<BASE>
{
	bool IsForwardTransformation() const {return true;}
	void CombineMessageAndShiftRegister(byte *output, byte *reg, const byte *message, size_t length);
};

/// \brief Base class for feedback based stream ciphers in the reverse direction with SymmetricCipher interface
/// \tparam BASE AbstractPolicyHolder base class
template <class BASE = AbstractPolicyHolder<CFB_CipherAbstractPolicy, SymmetricCipher> >
class CRYPTOPP_NO_VTABLE CFB_DecryptionTemplate : public CFB_CipherTemplate<BASE>
{
	bool IsForwardTransformation() const {return false;}
	void CombineMessageAndShiftRegister(byte *output, byte *reg, const byte *message, size_t length);
};

/// \brief Base class for feedback based stream ciphers with a mandatory block size
/// \tparam BASE CFB_EncryptionTemplate or CFB_DecryptionTemplate base class
template <class BASE>
class CFB_RequireFullDataBlocks : public BASE
{
public:
	unsigned int MandatoryBlockSize() const {return this->OptimalBlockSize();}
};

/// \brief SymmetricCipher implementation
/// \tparam BASE AbstractPolicyHolder derived base class
/// \tparam INFO AbstractPolicyHolder derived information class
/// \sa Weak::ARC4, ChaCha8, ChaCha12, ChaCha20, Salsa20, SEAL, Sosemanuk, WAKE
template <class BASE, class INFO = BASE>
class SymmetricCipherFinal : public AlgorithmImpl<SimpleKeyingInterfaceImpl<BASE, INFO>, INFO>
{
public:
	virtual ~SymmetricCipherFinal() {}

	/// \brief Construct a stream cipher
 	SymmetricCipherFinal() {}

	/// \brief Construct a stream cipher
	/// \param key a byte array used to key the cipher
	/// \details This overload uses DEFAULT_KEYLENGTH
	SymmetricCipherFinal(const byte *key)
		{this->SetKey(key, this->DEFAULT_KEYLENGTH);}

	/// \brief Construct a stream cipher
	/// \param key a byte array used to key the cipher
	/// \param length the size of the key array
	SymmetricCipherFinal(const byte *key, size_t length)
		{this->SetKey(key, length);}

	/// \brief Construct a stream cipher
	/// \param key a byte array used to key the cipher
	/// \param length the size of the key array
	/// \param iv a byte array used as an initialization vector
	SymmetricCipherFinal(const byte *key, size_t length, const byte *iv)
		{this->SetKeyWithIV(key, length, iv);}

	/// \brief Clone a SymmetricCipher
	/// \return a new SymmetricCipher based on this object
	Clonable * Clone() const {return static_cast<SymmetricCipher *>(new SymmetricCipherFinal<BASE, INFO>(*this));}
};

NAMESPACE_END

// Used by dll.cpp to ensure objects are in dll.o, and not strciphr.o.
#ifdef CRYPTOPP_MANUALLY_INSTANTIATE_TEMPLATES
# include "strciphr.cpp"
#endif

NAMESPACE_BEGIN(CryptoPP)

CRYPTOPP_DLL_TEMPLATE_CLASS AbstractPolicyHolder<AdditiveCipherAbstractPolicy, SymmetricCipher>;
CRYPTOPP_DLL_TEMPLATE_CLASS AdditiveCipherTemplate<AbstractPolicyHolder<AdditiveCipherAbstractPolicy, SymmetricCipher> >;

CRYPTOPP_DLL_TEMPLATE_CLASS CFB_CipherTemplate<AbstractPolicyHolder<CFB_CipherAbstractPolicy, SymmetricCipher> >;
CRYPTOPP_DLL_TEMPLATE_CLASS CFB_EncryptionTemplate<AbstractPolicyHolder<CFB_CipherAbstractPolicy, SymmetricCipher> >;
CRYPTOPP_DLL_TEMPLATE_CLASS CFB_DecryptionTemplate<AbstractPolicyHolder<CFB_CipherAbstractPolicy, SymmetricCipher> >;

NAMESPACE_END

#if CRYPTOPP_MSC_VERSION
# pragma warning(pop)
#endif

#endif
