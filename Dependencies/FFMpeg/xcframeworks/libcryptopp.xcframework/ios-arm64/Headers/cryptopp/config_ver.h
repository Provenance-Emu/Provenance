// config_ver.h - written and placed in public domain by Jeffrey Walton
//                the bits that make up this source file are from the
//                library's monolithic config.h.

/// \file config_ver.h
/// \brief Library configuration file
/// \details <tt>config_ver.h</tt> provides defines for library and compiler
///  versions.
/// \details <tt>config.h</tt> was split into components in May 2019 to better
///  integrate with Autoconf and its feature tests. The splitting occurred so
///  users could continue to include <tt>config.h</tt> while allowing Autoconf
///  to write new <tt>config_asm.h</tt> and new <tt>config_cxx.h</tt> using
///  its feature tests.
/// \note You should include <tt>config.h</tt> rather than <tt>config_ver.h</tt>
///  directly.
/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/835">Issue 835,
///  Make config.h more autoconf friendly</A>,
///  <A HREF="https://www.cryptopp.com/wiki/Configure.sh">Configure.sh script</A>
///  on the Crypto++ wiki
/// \since Crypto++ 8.3

#ifndef CRYPTOPP_CONFIG_VERSION_H
#define CRYPTOPP_CONFIG_VERSION_H

/// \brief Library major version
/// \details CRYPTOPP_MAJOR reflects the major version of the library the
///  headers came from. It is not necessarily the version of the library built
///  as a shared object if versions are inadvertently mixed and matched.
/// \sa CRYPTOPP_VERSION, LibraryVersion(), HeaderVersion()
/// \since Crypto++ 8.2
#define CRYPTOPP_MAJOR 8
/// \brief Library minor version
/// \details CRYPTOPP_MINOR reflects the minor version of the library the
///  headers came from. It is not necessarily the version of the library built
///  as a shared object if versions are inadvertently mixed and matched.
/// \sa CRYPTOPP_VERSION, LibraryVersion(), HeaderVersion()
/// \since Crypto++ 8.2
#define CRYPTOPP_MINOR 9
/// \brief Library revision number
/// \details CRYPTOPP_REVISION reflects the revision number of the library the
///  headers came from. It is not necessarily the revision of the library built
///  as a shared object if versions are inadvertently mixed and matched.
/// \sa CRYPTOPP_VERSION, LibraryVersion(), HeaderVersion()
/// \since Crypto++ 8.2
#define CRYPTOPP_REVISION 0

/// \brief Full library version
/// \details CRYPTOPP_VERSION reflects the version of the library the headers
///  came from. It is not necessarily the version of the library built as a
///  shared object if versions are inadvertently mixed and matched.
/// \sa CRYPTOPP_MAJOR, CRYPTOPP_MINOR, CRYPTOPP_REVISION, LibraryVersion(), HeaderVersion()
/// \since Crypto++ 5.6
#define CRYPTOPP_VERSION 890

// Compiler version macros

// Apple and LLVM Clang versions. Apple Clang version 7.0 roughly equals
// LLVM Clang version 3.7. Also see https://gist.github.com/yamaya/2924292
#if defined(__clang__) && defined(__apple_build_version__)
# define CRYPTOPP_APPLE_CLANG_VERSION (__clang_major__ * 10000 + __clang_minor__ * 100 + __clang_patchlevel__)
#elif defined(__clang__) && defined(_MSC_VER)
# define CRYPTOPP_MSVC_CLANG_VERSION (__clang_major__ * 10000 + __clang_minor__ * 100 + __clang_patchlevel__)
#elif defined(__clang__)
# define CRYPTOPP_LLVM_CLANG_VERSION  (__clang_major__ * 10000 + __clang_minor__ * 100 + __clang_patchlevel__)
#endif

// Clang pretends to be other compilers. The compiler gets into
// code paths that it cannot compile. Unset Clang to save the grief.
// Also see http://github.com/weidai11/cryptopp/issues/147.

#if defined(__GNUC__) && !defined(__clang__)
# undef CRYPTOPP_APPLE_CLANG_VERSION
# undef CRYPTOPP_LLVM_CLANG_VERSION
# define CRYPTOPP_GCC_VERSION (__GNUC__ * 10000 + __GNUC_MINOR__ * 100 + __GNUC_PATCHLEVEL__)
#endif

#if defined(__xlc__) || defined(__xlC__) && !defined(__clang__)
# undef CRYPTOPP_LLVM_CLANG_VERSION
# define CRYPTOPP_XLC_VERSION ((__xlC__ / 256) * 10000 + (__xlC__ % 256) * 100)
#endif

#if defined(__INTEL_COMPILER) && !defined(__clang__)
# undef CRYPTOPP_LLVM_CLANG_VERSION
# define CRYPTOPP_INTEL_VERSION (__INTEL_COMPILER)
#endif

#if defined(_MSC_VER) && !defined(__clang__)
# undef CRYPTOPP_LLVM_CLANG_VERSION
# define CRYPTOPP_MSC_VERSION (_MSC_VER)
#endif

// To control <x86intrin.h> include. May need a guard, like GCC 4.5 and above
// Also see https://stackoverflow.com/a/42493893 and https://github.com/weidai11/cryptopp/issues/1198
#if defined(CRYPTOPP_GCC_VERSION) || defined(CRYPTOPP_APPLE_CLANG_VERSION) || defined(CRYPTOPP_LLVM_CLANG_VERSION)
# define CRYPTOPP_GCC_COMPATIBLE 1
#endif

#endif  // CRYPTOPP_CONFIG_VERSION_H
