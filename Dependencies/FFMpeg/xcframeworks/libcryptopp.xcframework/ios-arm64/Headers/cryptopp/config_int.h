// config_int.h - written and placed in public domain by Jeffrey Walton
//                the bits that make up this source file are from the
//                library's monolithic config.h.

/// \file config_int.h
/// \brief Library configuration file
/// \details <tt>config_int.h</tt> provides defines and typedefs for fixed
///  size integers. The library's choices for fixed size integers predates other
///  standard-based integers by about 5 years. After fixed sizes were
///  made standard, the library continued to use its own definitions for
///  compatibility with previous versions of the library.
/// \details <tt>config.h</tt> was split into components in May 2019 to better
///  integrate with Autoconf and its feature tests. The splitting occurred so
///  users could continue to include <tt>config.h</tt> while allowing Autoconf
///  to write new <tt>config_asm.h</tt> and new <tt>config_cxx.h</tt> using
///  its feature tests.
/// \note You should include <tt>config.h</tt> rather than <tt>config_int.h</tt>
///  directly.
/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/835">Issue 835,
///  Make config.h more autoconf friendly</A>,
///  <A HREF="https://www.cryptopp.com/wiki/Configure.sh">Configure.sh script</A>
///  on the Crypto++ wiki
/// \since Crypto++ 8.3

#ifndef CRYPTOPP_CONFIG_INT_H
#define CRYPTOPP_CONFIG_INT_H

#include "config_ns.h"
#include "config_ver.h"
#include "config_misc.h"

// C5264 new for VS2022/v17.4, MSC v17.3.4
// https://github.com/weidai11/cryptopp/issues/1185
#if (CRYPTOPP_MSC_VERSION)
# pragma warning(push)
# if (CRYPTOPP_MSC_VERSION >= 1933)
#  pragma warning(disable: 5264)
# endif
#endif

/// \brief Library byte guard
/// \details CRYPTOPP_NO_GLOBAL_BYTE indicates <tt>byte</tt> is in the Crypto++
///  namespace.
/// \details The Crypto++ <tt>byte</tt> was originally in global namespace to avoid
///  ambiguity with other byte typedefs. <tt>byte</tt> was moved to CryptoPP namespace
///  at Crypto++ 6.0 due to C++17, <tt>std::byte</tt> and potential compile problems.
/// \sa <A HREF="http://github.com/weidai11/cryptopp/issues/442">Issue 442</A>,
///  <A HREF="https://www.cryptopp.com/wiki/Configure.sh">std::byte</A> on the
///  Crypto++ wiki
/// \since Crypto++ 6.0
#define CRYPTOPP_NO_GLOBAL_BYTE 1

NAMESPACE_BEGIN(CryptoPP)

// Signed words added at Issue 609 for early versions of and Visual Studio and
// the NaCl gear. Also see https://github.com/weidai11/cryptopp/issues/609.

/// \brief 8-bit unsigned datatype
/// \details The Crypto++ <tt>byte</tt> was originally in global namespace to avoid
///  ambiguity with other byte typedefs. <tt>byte</tt> was moved to CryptoPP namespace
///  at Crypto++ 6.0 due to C++17, <tt>std::byte</tt> and potential compile problems.
/// \sa CRYPTOPP_NO_GLOBAL_BYTE, <A HREF="http://github.com/weidai11/cryptopp/issues/442">Issue 442</A>,
///  <A HREF="https://www.cryptopp.com/wiki/Configure.sh">std::byte</A> on the
///  Crypto++ wiki
/// \since Crypto++ 1.0, CryptoPP namespace since Crypto++ 6.0
typedef unsigned char byte;
/// \brief 16-bit unsigned datatype
/// \since Crypto++ 1.0
typedef unsigned short word16;
/// \brief 32-bit unsigned datatype
/// \since Crypto++ 1.0
typedef unsigned int word32;

/// \brief 8-bit signed datatype
/// \details The 8-bit signed datatype was added to support constant time
///  implementations for curve25519, X25519 key agreement and ed25519
///  signatures.
/// \since Crypto++ 8.0
typedef signed char sbyte;
/// \brief 16-bit signed datatype
/// \details The 32-bit signed datatype was added to support constant time
///  implementations for curve25519, X25519 key agreement and ed25519
///  signatures.
/// \since Crypto++ 8.0
typedef signed short sword16;
/// \brief 32-bit signed datatype
/// \details The 32-bit signed datatype was added to support constant time
///  implementations for curve25519, X25519 key agreement and ed25519
///  signatures.
/// \since Crypto++ 8.0
typedef signed int sword32;

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)

	/// \brief 64-bit unsigned datatype
	/// \details The typedef for <tt>word64</tt> varies depending on the platform.
	///  On Microsoft platforms it is <tt>unsigned __int64</tt>. On Unix &amp; Linux
	///  with LP64 data model it is <tt>unsigned long</tt>. On Unix &amp; Linux with ILP32
	///  data model it is <tt>unsigned long long</tt>.
	/// \since Crypto++ 1.0
	typedef unsigned long long word64;

	/// \brief 64-bit signed datatype
	/// \details The typedef for <tt>sword64</tt> varies depending on the platform.
	///  On Microsoft platforms it is <tt>signed __int64</tt>. On Unix &amp; Linux
	///  with LP64 data model it is <tt>signed long</tt>. On Unix &amp; Linux with ILP32
	///  data model it is <tt>signed long long</tt>.
	/// \since Crypto++ 8.0
	typedef signed long long sword64;

	/// \brief 128-bit unsigned datatype
	/// \details The typedef for <tt>word128</tt> varies depending on the platform.
	///  <tt>word128</tt> is only available on 64-bit machines when
	///  <tt>CRYPTOPP_WORD128_AVAILABLE</tt> is defined.
	///  On Unix &amp; Linux with LP64 data model it is <tt>__uint128_t</tt>.
	///  Microsoft platforms do not provide a 128-bit integer type. 32-bit platforms
	///  do not provide a 128-bit integer type.
	/// \since Crypto++ 5.6
	typedef __uint128_t word128;

	/// \brief Declare an unsigned word64
	/// \details W64LIT is used to portability declare or assign 64-bit literal values.
	///  W64LIT will append the proper suffix to ensure the compiler accepts the literal.
	/// \details Use the macro like shown below.
	///  <pre>
	///    word64 x = W64LIT(0xffffffffffffffff);
	///  </pre>
	/// \since Crypto++ 1.0
	#define W64LIT(x) ...

	/// \brief Declare a signed word64
	/// \details SW64LIT is used to portability declare or assign 64-bit literal values.
	///  SW64LIT will append the proper suffix to ensure the compiler accepts the literal.
	/// \details Use the macro like shown below.
	///  <pre>
	///    sword64 x = SW64LIT(0xffffffffffffffff);
	///  </pre>
	/// \since Crypto++ 8.0
	#define SW64LIT(x) ...

	/// \brief Declare ops on word64 are slow
	/// \details CRYPTOPP_BOOL_SLOW_WORD64 is typically defined to 1 on platforms
	///  that have a machine word smaller than 64-bits. That is, the define
	///  is present on 32-bit platforms. The define is also present on platforms
	///  where the cpu is slow even with a 64-bit cpu.
	#define CRYPTOPP_BOOL_SLOW_WORD64 ...

#elif defined(CRYPTOPP_MSC_VERSION) || defined(__BORLANDC__)
	typedef signed __int64 sword64;
	typedef unsigned __int64 word64;
	#define SW64LIT(x) x##i64
	#define W64LIT(x) x##ui64
#elif (_LP64 || __LP64__)
	typedef signed long sword64;
	typedef unsigned long word64;
	#define SW64LIT(x) x##L
	#define W64LIT(x) x##UL
#else
	typedef signed long long sword64;
	typedef unsigned long long word64;
	#define SW64LIT(x) x##LL
	#define W64LIT(x) x##ULL
#endif

/// \brief Large word type
/// \details lword is a typedef for large word types. It is used for file
///  offsets and such.
typedef word64 lword;

/// \brief Large word type max value
/// \details LWORD_MAX is the maximum value for large word types.
///  Since an <tt>lword</tt> is an unsigned type, the value is
///  <tt>0xffffffffffffffff</tt>. W64LIT will append the proper suffix.
CRYPTOPP_CONST_OR_CONSTEXPR lword LWORD_MAX = W64LIT(0xffffffffffffffff);

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
	/// \brief Half word used for multiprecision integer arithmetic
	/// \details hword is used for multiprecision integer arithmetic.
	///  The typedef for <tt>hword</tt> varies depending on the platform.
	///  On 32-bit platforms it is usually <tt>word16</tt>. On 64-bit platforms
	///  it is usually <tt>word32</tt>.
	/// \details Library users typically use byte, word16, word32 and word64.
	/// \since Crypto++ 2.0
	typedef word32 hword;
	/// \brief Full word used for multiprecision integer arithmetic
	/// \details word is used for multiprecision integer arithmetic.
	///  The typedef for <tt>word</tt> varies depending on the platform.
	///  On 32-bit platforms it is usually <tt>word32</tt>. On 64-bit platforms
	///  it is usually <tt>word64</tt>.
	/// \details Library users typically use byte, word16, word32 and word64.
	/// \since Crypto++ 2.0
	typedef word64 word;
	/// \brief Double word used for multiprecision integer arithmetic
	/// \details dword is used for multiprecision integer arithmetic.
	///  The typedef for <tt>dword</tt> varies depending on the platform.
	///  On 32-bit platforms it is usually <tt>word64</tt>. On 64-bit Unix &amp;
	///  Linux platforms it is usually <tt>word128</tt>. <tt>word128</tt> is
	///  not available on Microsoft platforms. <tt>word128</tt> is only available
	///  when <tt>CRYPTOPP_WORD128_AVAILABLE</tt> is defined.
	/// \details Library users typically use byte, word16, word32 and word64.
	/// \sa CRYPTOPP_WORD128_AVAILABLE
	/// \since Crypto++ 2.0
	typedef word128 dword;

	/// \brief 128-bit word availability
	/// \details CRYPTOPP_WORD128_AVAILABLE indicates a 128-bit word is
	///  available from the platform. 128-bit words are usually available on
	///  64-bit platforms, but not available 32-bit platforms.
	/// \details If CRYPTOPP_WORD128_AVAILABLE is not defined, then 128-bit
	///  words are not available.
	/// \details GCC and compatible compilers signal 128-bit word availability
	///  with the preporcessor macro <tt>__SIZEOF_INT128__ >= 16</tt>.
	/// \since Crypto++ 2.0
	#define CRYPTOPP_WORD128_AVAILABLE ...
#else
	// define hword, word, and dword. these are used for multiprecision integer arithmetic
	// Intel compiler won't have _umul128 until version 10.0. See http://softwarecommunity.intel.com/isn/Community/en-US/forums/thread/30231625.aspx
	#if (defined(CRYPTOPP_MSC_VERSION) && (!defined(__INTEL_COMPILER) || __INTEL_COMPILER >= 1000) && (defined(_M_X64) || defined(_M_IA64))) || (defined(__DECCXX) && defined(__alpha__)) || (defined(__INTEL_COMPILER) && defined(__x86_64__)) || (defined(__SUNPRO_CC) && defined(__x86_64__))
		typedef word32 hword;
		typedef word64 word;
	#else
		#define CRYPTOPP_NATIVE_DWORD_AVAILABLE 1
		#if defined(__alpha__) || defined(__ia64__) || defined(_ARCH_PPC64) || defined(__x86_64__) || defined(__mips64) || defined(__sparc64__) || defined(__aarch64__)
			#if ((CRYPTOPP_GCC_VERSION >= 30400) || (CRYPTOPP_LLVM_CLANG_VERSION >= 30000) || (CRYPTOPP_APPLE_CLANG_VERSION >= 40300)) && (__SIZEOF_INT128__ >= 16)
				// GCC 4.0.1 on MacOS X is missing __umodti3 and __udivti3
				// GCC 4.8.3 and bad uint128_t ops on PPC64/POWER7 (Issue 421)
				// mode(TI) division broken on amd64 with GCC earlier than GCC 3.4
				typedef word32 hword;
				typedef word64 word;
				typedef __uint128_t dword;
				typedef __uint128_t word128;
				#define CRYPTOPP_WORD128_AVAILABLE 1
			#else
				// if we're here, it means we're on a 64-bit CPU but we don't have a way to obtain 128-bit multiplication results
				typedef word16 hword;
				typedef word32 word;
				typedef word64 dword;
			#endif
		#else
			// being here means the native register size is probably 32 bits or less
			#define CRYPTOPP_BOOL_SLOW_WORD64 1
			typedef word16 hword;
			typedef word32 word;
			typedef word64 dword;
		#endif
	#endif
#endif

#ifndef CRYPTOPP_BOOL_SLOW_WORD64
# define CRYPTOPP_BOOL_SLOW_WORD64 0
#endif

/// \brief Size of a platform word in bytes
/// \details The size of a platform word, in bytes
CRYPTOPP_CONST_OR_CONSTEXPR unsigned int WORD_SIZE = sizeof(word);

/// \brief Size of a platform word in bits
/// \details The size of a platform word, in bits
/// \sa https://github.com/weidai11/cryptopp/issues/1185
CRYPTOPP_CONST_OR_CONSTEXPR unsigned int WORD_BITS = WORD_SIZE * 8;

NAMESPACE_END

#if (CRYPTOPP_MSC_VERSION)
# pragma warning(pop)
#endif

#endif  // CRYPTOPP_CONFIG_INT_H
