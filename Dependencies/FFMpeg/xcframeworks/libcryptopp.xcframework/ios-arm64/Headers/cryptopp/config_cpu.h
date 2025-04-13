// config_cpu.h - written and placed in public domain by Jeffrey Walton
//                the bits that make up this source file are from the
//                library's monolithic config.h.

/// \file config_cpu.h
/// \brief Library configuration file
/// \details <tt>config_cpu.h</tt> provides defines for the cpu and machine
///  architecture.
/// \details <tt>config.h</tt> was split into components in May 2019 to better
///  integrate with Autoconf and its feature tests. The splitting occurred so
///  users could continue to include <tt>config.h</tt> while allowing Autoconf
///  to write new <tt>config_asm.h</tt> and new <tt>config_cxx.h</tt> using
///  its feature tests.
/// \note You should include <tt>config.h</tt> rather than <tt>config_cpu.h</tt>
///  directly.
/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/835">Issue 835,
///  Make config.h more autoconf friendly</A>,
///  <A HREF="https://www.cryptopp.com/wiki/Configure.sh">Configure.sh script</A>
///  on the Crypto++ wiki,
///  <A HREF="https://sourceforge.net/p/predef/wiki/Architectures/">Sourceforge
///  Pre-defined Compiler Macros</A>
/// \since Crypto++ 8.3

#ifndef CRYPTOPP_CONFIG_CPU_H
#define CRYPTOPP_CONFIG_CPU_H

#include "config_ver.h"

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
	/// \brief 32-bit x32 platform
	/// \details CRYPTOPP_BOOL_X32 is defined to 1 when building the library
	///  for a 32-bit x32 platform. Otherwise, the macro is not defined.
	/// \details x32 is sometimes referred to as x86_32. x32 is the ILP32 data
	///  model on a 64-bit cpu. Integers, longs and pointers are 32-bit but the
	///  program runs on a 64-bit cpu.
	/// \details The significance of x32 is, inline assembly must operate on
	///  64-bit registers, not 32-bit registers. That means, for example,
	///  function prologues and epilogues must push and pop RSP, not ESP.
	/// \note: Clang defines __ILP32__ on any 32-bit platform. Therefore,
	///  CRYPTOPP_BOOL_X32 depends upon both __ILP32__ and __x86_64__.
	/// \sa <A HREF="https://wiki.debian.org/X32Port">Debian X32 Port</A>,
	///  <A HREF="https://wiki.gentoo.org/wiki/Project:Multilib/Concepts">Gentoo
	///  Multilib Concepts</A>
	#define CRYPTOPP_BOOL_X32 ...
	/// \brief 32-bit x86 platform
	/// \details CRYPTOPP_BOOL_X64 is defined to 1 when building the library
	///  for a 64-bit x64 platform. Otherwise, the macro is not defined.
	#define CRYPTOPP_BOOL_X64 ...
	/// \brief 32-bit x86 platform
	/// \details CRYPTOPP_BOOL_X86 is defined to 1 when building the library
	///  for a 32-bit x86 platform. Otherwise, the macro is not defined.
	#define CRYPTOPP_BOOL_X86 ...
#elif (defined(__ILP32__) || defined(_ILP32)) && defined(__x86_64__)
	#define CRYPTOPP_BOOL_X32 1
#elif (defined(_M_X64) || defined(__x86_64__))
	#define CRYPTOPP_BOOL_X64 1
#elif (defined(_M_IX86) || defined(__i386__) || defined(__i386) || defined(_X86_) || defined(__I86__) || defined(__INTEL__))
	#define CRYPTOPP_BOOL_X86 1
#endif

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
	/// \brief ARMv8 platform
	/// \details CRYPTOPP_BOOL_ARMV8 is defined to 1 when building the library
	///  for an ARMv8 platform. Otherwise, the macro is not defined.
	/// \details ARMv8 includes both Aarch32 and Aarch64. Aarch32 is a 32-bit
	///  execution environment on Aarch64.
	#define CRYPTOPP_BOOL_ARMV8 ...
	/// \brief 64-bit ARM platform
	/// \details CRYPTOPP_BOOL_ARM64 is defined to 1 when building the library
	///  for a 64-bit x64 platform. Otherwise, the macro is not defined.
	/// \details Currently the macro indicates an ARM 64-bit architecture.
	#define CRYPTOPP_BOOL_ARM64 ...
	/// \brief 32-bit ARM platform
	/// \details CRYPTOPP_BOOL_ARM32 is defined to 1 when building the library
	///  for a 32-bit ARM platform. Otherwise, the macro is not defined.
	/// \details Currently the macro indicates an ARM A-32 architecture.
	#define CRYPTOPP_BOOL_ARM32 ...
#elif defined(__arm64__) || defined(__aarch32__) || defined(__aarch64__) || defined(_M_ARM64)
	// Microsoft added ARM64 define December 2017.
	#define CRYPTOPP_BOOL_ARMV8 1
#endif
#if defined(__arm64__) || defined(__aarch64__) || defined(_M_ARM64)
	#define CRYPTOPP_BOOL_ARM64 1
#elif defined(__arm__) || defined(_M_ARM)
	#define CRYPTOPP_BOOL_ARM32 1
#endif

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
	/// \brief 64-bit PowerPC platform
	/// \details CRYPTOPP_BOOL_PPC64 is defined to 1 when building the library
	///  for a 64-bit PowerPC platform. Otherwise, the macro is not defined.
	#define CRYPTOPP_BOOL_PPC64 ...
	/// \brief 32-bit PowerPC platform
	/// \details CRYPTOPP_BOOL_PPC32 is defined to 1 when building the library
	///  for a 32-bit PowerPC platform. Otherwise, the macro is not defined.
	#define CRYPTOPP_BOOL_PPC32 ...
#elif defined(__ppc64__) || defined(__powerpc64__) || defined(__PPC64__) || defined(_ARCH_PPC64)
	#define CRYPTOPP_BOOL_PPC64 1
#elif defined(__powerpc__) || defined(__ppc__) || defined(__PPC__) || defined(_ARCH_PPC)
	#define CRYPTOPP_BOOL_PPC32 1
#endif

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
	/// \brief 64-bit MIPS platform
	/// \details CRYPTOPP_BOOL_MIPS64 is defined to 1 when building the library
	///  for a 64-bit MIPS platform. Otherwise, the macro is not defined.
	#define CRYPTOPP_BOOL_MIPS64 ...
	/// \brief 64-bit MIPS platform
	/// \details CRYPTOPP_BOOL_MIPS32 is defined to 1 when building the library
	///  for a 32-bit MIPS platform. Otherwise, the macro is not defined.
	#define CRYPTOPP_BOOL_MIPS32 ...
#elif defined(__mips64__)
	#define CRYPTOPP_BOOL_MIPS64 1
#elif defined(__mips__)
	#define CRYPTOPP_BOOL_MIPS32 1
#endif

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
	/// \brief 64-bit SPARC platform
	/// \details CRYPTOPP_BOOL_SPARC64 is defined to 1 when building the library
	///  for a 64-bit SPARC platform. Otherwise, the macro is not defined.
	#define CRYPTOPP_BOOL_SPARC64 ...
	/// \brief 32-bit SPARC platform
	/// \details CRYPTOPP_BOOL_SPARC32 is defined to 1 when building the library
	///  for a 32-bit SPARC platform. Otherwise, the macro is not defined.
	#define CRYPTOPP_BOOL_SPARC32 ...
#elif defined(__sparc64__) || defined(__sparc64) || defined(__sparcv9) || defined(__sparc_v9__)
	#define CRYPTOPP_BOOL_SPARC64 1
#elif defined(__sparc__) || defined(__sparc) || defined(__sparcv8) || defined(__sparc_v8__)
	#define CRYPTOPP_BOOL_SPARC32 1
#endif

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
	/// \brief L1 data cache line size
	/// \details CRYPTOPP_L1_CACHE_LINE_SIZE should be a lower bound on the L1
	///  data cache line size. It is used for defense against some timing attacks.
	/// \details CRYPTOPP_L1_CACHE_LINE_SIZE default value on 32-bit platforms
	///  is 32, and the default value on 64-bit platforms is 64. On PowerPC the
	///  default value is 128 since all PowerPC cpu's starting at PPC 970 provide
	///  it.
	/// \note The runtime library on some PowerPC platforms misreport the size
	///  of the cache line size. The runtime library reports 64, while the cpu
	///  has a cache line size of 128.
	/// \sa <A HREF="https://bugs.centos.org/view.php?id=14599">CentOS Issue
	///  14599: sysconf(_SC_LEVEL1_DCACHE_LINESIZE) returns 0 instead of 128</A>
	/// \since Crypto++ 5.3
	#define CRYPTOPP_L1_CACHE_LINE_SIZE ...
#else
	#ifndef CRYPTOPP_L1_CACHE_LINE_SIZE
		#if defined(CRYPTOPP_BOOL_X32) || defined(CRYPTOPP_BOOL_X64) || defined(CRYPTOPP_BOOL_ARMV8) || \
		    defined(CRYPTOPP_BOOL_MIPS64) || defined(CRYPTOPP_BOOL_SPARC64)
			#define CRYPTOPP_L1_CACHE_LINE_SIZE 64
		#elif defined(CRYPTOPP_BOOL_PPC32) || defined(CRYPTOPP_BOOL_PPC64)
			// http://lists.llvm.org/pipermail/llvm-dev/2017-March/110982.html
			#define CRYPTOPP_L1_CACHE_LINE_SIZE 128
		#else
			// L1 cache line size is 32 on Pentium III and earlier
			#define CRYPTOPP_L1_CACHE_LINE_SIZE 32
		#endif
	#endif
#endif

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
	/// \brief Initialized data section
	/// \details CRYPTOPP_SECTION_INIT is added to variables to place them in the
	///  initialized data section (sometimes denoted <tt>.data</tt>). The placement
	///  helps avoid "uninitialized variable" warnings from Valgrind and other tools.
	#define CRYPTOPP_SECTION_INIT ...
#else
	// The section attribute attempts to initialize CPU flags to avoid Valgrind findings above -O1
	#if ((defined(__MACH__) && defined(__APPLE__)) && ((CRYPTOPP_LLVM_CLANG_VERSION >= 30600) || \
	    (CRYPTOPP_APPLE_CLANG_VERSION >= 70100) || (CRYPTOPP_GCC_VERSION >= 40300)))
		#define CRYPTOPP_SECTION_INIT __attribute__((section ("__DATA,__data")))
	#elif (defined(__ELF__) && (CRYPTOPP_GCC_VERSION >= 40300))
		#define CRYPTOPP_SECTION_INIT __attribute__((section ("nocommon")))
	#elif defined(__ELF__) && (defined(__xlC__) || defined(__ibmxl__))
		#define CRYPTOPP_SECTION_INIT __attribute__((section ("nocommon")))
	#else
		#define CRYPTOPP_SECTION_INIT
	#endif
#endif

// How to disable CPU feature probing. We determine machine
// capabilities by performing an os/platform *query* first,
// like getauxv(). If the *query* fails, we move onto a
// cpu *probe*. The cpu *probe* tries to exeute an instruction
// and then catches a SIGILL on Linux or the exception
// EXCEPTION_ILLEGAL_INSTRUCTION on Windows. Some OSes
// fail to hangle a SIGILL gracefully, like Apple OSes. Apple
// machines corrupt memory and variables around the probe.
#if defined(__APPLE__)
	#define CRYPTOPP_NO_CPU_FEATURE_PROBES 1
#endif

// Flavor of inline assembly language
#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
	/// \brief Microsoft style inline assembly
	/// \details CRYPTOPP_MS_STYLE_INLINE_ASSEMBLY is defined when either
	///  <tt>_MSC_VER</tt> or <tt>__BORLANDC__</tt> are defined.
	#define CRYPTOPP_MS_STYLE_INLINE_ASSEMBLY ...
	/// \brief GNU style inline assembly
	/// \details CRYPTOPP_GNU_STYLE_INLINE_ASSEMBLY is defined when neither
	///  <tt>_MSC_VER</tt> nor <tt>__BORLANDC__</tt> are defined.
	#define CRYPTOPP_GNU_STYLE_INLINE_ASSEMBLY ...
#elif defined(CRYPTOPP_MSC_VERSION) || defined(__BORLANDC__) || \
	defined(CRYPTOPP_MSVC_CLANG_VERSION)
	#define CRYPTOPP_MS_STYLE_INLINE_ASSEMBLY 1
#else
	#define CRYPTOPP_GNU_STYLE_INLINE_ASSEMBLY 1
#endif

#endif  // CRYPTOPP_CONFIG_CPU_H
