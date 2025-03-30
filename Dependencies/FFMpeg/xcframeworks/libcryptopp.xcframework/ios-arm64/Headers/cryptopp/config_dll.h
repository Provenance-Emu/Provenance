// config_dll.h - written and placed in public domain by Jeffrey Walton
//                the bits that make up this source file are from the
//                library's monolithic config.h.

/// \file config_dll.h
/// \brief Library configuration file
/// \details <tt>config_dll.h</tt> provides defines for shared objects and
///  dynamic libraries. Generally speaking the macros are used to export
///  classes and template classes from the Win32 dynamic link library.
///  When not building the Win32 dynamic link library they are mostly an extern
///  template declaration.
/// \details In practice they are a furball coughed up by a cat and then peed
///  on by a dog. They are awful to get just right because of inconsistent
///  compiler support for extern templates, manual instantiation and the FIPS DLL.
/// \details <tt>config.h</tt> was split into components in May 2019 to better
///  integrate with Autoconf and its feature tests. The splitting occurred so
///  users could continue to include <tt>config.h</tt> while allowing Autoconf
///  to write new <tt>config_asm.h</tt> and new <tt>config_cxx.h</tt> using
///  its feature tests.
/// \note You should include <tt>config.h</tt> rather than <tt>config_dll.h</tt>
///  directly.
/// \sa <A HREF="https://github.com/weidai11/cryptopp/issues/835">Issue 835,
///  Make config.h more autoconf friendly</A>,
///  <A HREF="https://www.cryptopp.com/wiki/Configure.sh">Configure.sh script</A>,
///  <A HREF="https://www.cryptopp.com/wiki/Visual_Studio">Visual Studio</A>,
///  and <A HREF="https://www.cryptopp.com/wiki/FIPS_DLL">FIPS DLL</A>
///  on the Crypto++ wiki
/// \since Crypto++ 8.3

#ifndef CRYPTOPP_CONFIG_DLL_H
#define CRYPTOPP_CONFIG_DLL_H

#include "config_os.h"

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)

	/// \brief Win32 define for dynamic link libraries
	/// \details CRYPTOPP_IMPORTS is set in the Visual Studio project files.
	///  When the macro is set, <tt>CRYPTOPP_DLL</tt> is defined to
	///  <tt>__declspec(dllimport)</tt>.
	/// \details This macro has no effect on Unix &amp; Linux.
	/// \sa <A HREF="https://www.cryptopp.com/wiki/Visual_Studio">Visual Studio</A>,
	///  and <A HREF="https://www.cryptopp.com/wiki/FIPS_DLL">FIPS DLL</A>
	///  on the Crypto++ wiki
	#define CRYPTOPP_IMPORTS ...

	/// \brief Win32 define for dynamic link libraries
	/// \details CRYPTOPP_EXPORTS is set in the Visual Studio project files.
	///  When the macro is set, <tt>CRYPTOPP_DLL</tt> is defined to
	///  <tt>__declspec(dllexport)</tt>.
	/// \details This macro has no effect on Unix &amp; Linux.
	/// \sa <A HREF="https://www.cryptopp.com/wiki/Visual_Studio">Visual Studio</A>,
	///  and <A HREF="https://www.cryptopp.com/wiki/FIPS_DLL">FIPS DLL</A>
	///  on the Crypto++ wiki
	#define CRYPTOPP_EXPORTS ...

	/// \brief Win32 define for dynamic link libraries
	/// \details CRYPTOPP_IS_DLL is set in the Visual Studio project files.
	/// \sa <A HREF="https://www.cryptopp.com/wiki/Visual_Studio">Visual Studio</A>,
	///  and <A HREF="https://www.cryptopp.com/wiki/FIPS_DLL">FIPS DLL</A>
	///  on the Crypto++ wiki
	#define CRYPTOPP_IS_DLL

	/// \brief Instantiate templates in a dynamic library
	/// \details CRYPTOPP_DLL_TEMPLATE_CLASS decoration should be used
	///  for classes intended to be exported from dynamic link libraries.
	/// \details This macro is primarily used on Win32, but sees some
	///  action on Unix &amp; Linux due to the source file <tt>dll.cpp</tt>.
	/// \sa <A HREF="https://www.cryptopp.com/wiki/Visual_Studio">Visual Studio</A>,
	///  and <A HREF="https://www.cryptopp.com/wiki/FIPS_DLL">FIPS DLL</A>
	///  on the Crypto++ wiki
	#define CRYPTOPP_DLL_TEMPLATE_CLASS ...

	/// \brief Instantiate templates in a dynamic library
	/// \details CRYPTOPP_EXTERN_DLL_TEMPLATE_CLASS decoration should be used
	///  for template classes intended to be exported from dynamic link libraries.
	/// \details This macro is primarily used on Win32, but sees some
	///  action on Unix &amp; Linux due to the source file <tt>dll.cpp</tt>.
	/// \sa <A HREF="https://www.cryptopp.com/wiki/Visual_Studio">Visual Studio</A>,
	///  and <A HREF="https://www.cryptopp.com/wiki/FIPS_DLL">FIPS DLL</A>
	///  on the Crypto++ wiki
	#define CRYPTOPP_EXTERN_DLL_TEMPLATE_CLASS ...

	/// \brief Instantiate templates in a dynamic library
	/// \details CRYPTOPP_STATIC_TEMPLATE_CLASS decoration should be used
	///  for template classes intended to be exported from dynamic link libraries.
	/// \details This macro is primarily used on Win32, but sees some
	///  action on Unix &amp; Linux due to the source file <tt>dll.cpp</tt>.
	/// \sa <A HREF="https://www.cryptopp.com/wiki/Visual_Studio">Visual Studio</A>,
	///  and <A HREF="https://www.cryptopp.com/wiki/FIPS_DLL">FIPS DLL</A>
	///  on the Crypto++ wiki
	#define CRYPTOPP_STATIC_TEMPLATE_CLASS ...

	/// \brief Instantiate templates in a dynamic library
	/// \details CRYPTOPP_EXTERN_STATIC_TEMPLATE_CLASS decoration should be used
	///  for template classes intended to be exported from dynamic link libraries.
	/// \details This macro is primarily used on Win32, but sees some
	///  action on Unix &amp; Linux due to the source file <tt>dll.cpp</tt>.
	/// \sa <A HREF="https://www.cryptopp.com/wiki/Visual_Studio">Visual Studio</A>,
	///  and <A HREF="https://www.cryptopp.com/wiki/FIPS_DLL">FIPS DLL</A>
	///  on the Crypto++ wiki
	#define CRYPTOPP_EXTERN_STATIC_TEMPLATE_CLASS ...

	/// \brief Override for internal linkage
	/// \details CRYPTOPP_TABLE can be used to override internal linkage
	///  on tables with the <tt>const</tt> qualifier. According to C++ rules
	///  a declaration with <tt>const</tt> qualifier is internal linkage.
	/// \note The name CRYPTOPP_TABLE was chosen because it is often used to
	///  export a table, like AES or SHA constants. The name avoids collisions
	///  with the DLL gear macros, like CRYPTOPP_EXPORTS and CRYPTOPP_EXTERN.
	#define CRYPTOPP_TABLE extern

	/// \brief Win32 calling convention
	/// \details CRYPTOPP_API sets the calling convention on Win32.
	///  On Win32 CRYPTOPP_API is <tt>__cedcl</tt>. On Unix &amp; Linux
	///  CRYPTOPP_API is defined to nothing.
	/// \sa <A HREF="https://www.cryptopp.com/wiki/Visual_Studio">Visual Studio</A>
	///  on the Crypto++ wiki
	#define CRYPTOPP_API ...

#else  // CRYPTOPP_DOXYGEN_PROCESSING

#if defined(CRYPTOPP_WIN32_AVAILABLE)

	#if defined(CRYPTOPP_EXPORTS)
	#  define CRYPTOPP_IS_DLL
	#  define CRYPTOPP_DLL __declspec(dllexport)
	#elif defined(CRYPTOPP_IMPORTS)
	#  define CRYPTOPP_IS_DLL
	#  define CRYPTOPP_DLL __declspec(dllimport)
	#else
	#  define CRYPTOPP_DLL
	#endif

	// C++ makes const internal linkage
	#define CRYPTOPP_TABLE extern
	#define CRYPTOPP_API __cdecl

#else	// not CRYPTOPP_WIN32_AVAILABLE

	// C++ makes const internal linkage
	#define CRYPTOPP_TABLE extern
	#define CRYPTOPP_DLL
	#define CRYPTOPP_API

#endif	// CRYPTOPP_WIN32_AVAILABLE

#if defined(__MWERKS__)
#  define CRYPTOPP_EXTERN_DLL_TEMPLATE_CLASS extern class CRYPTOPP_DLL
#elif defined(__BORLANDC__) || defined(__SUNPRO_CC)
#  define CRYPTOPP_EXTERN_DLL_TEMPLATE_CLASS template class CRYPTOPP_DLL
#else
#  define CRYPTOPP_EXTERN_DLL_TEMPLATE_CLASS extern template class CRYPTOPP_DLL
#endif

#if defined(CRYPTOPP_MANUALLY_INSTANTIATE_TEMPLATES) && !defined(CRYPTOPP_IMPORTS)
#  define CRYPTOPP_DLL_TEMPLATE_CLASS template class CRYPTOPP_DLL
#else
#  define CRYPTOPP_DLL_TEMPLATE_CLASS CRYPTOPP_EXTERN_DLL_TEMPLATE_CLASS
#endif

#if defined(__MWERKS__)
#  define CRYPTOPP_EXTERN_STATIC_TEMPLATE_CLASS extern class
#elif defined(__BORLANDC__) || defined(__SUNPRO_CC)
#  define CRYPTOPP_EXTERN_STATIC_TEMPLATE_CLASS template class
#else
#  define CRYPTOPP_EXTERN_STATIC_TEMPLATE_CLASS extern template class
#endif

#if defined(CRYPTOPP_MANUALLY_INSTANTIATE_TEMPLATES) && !defined(CRYPTOPP_EXPORTS)
#  define CRYPTOPP_STATIC_TEMPLATE_CLASS template class
#else
#  define CRYPTOPP_STATIC_TEMPLATE_CLASS CRYPTOPP_EXTERN_STATIC_TEMPLATE_CLASS
#endif

#endif  // CRYPTOPP_DOXYGEN_PROCESSING

#endif  // CRYPTOPP_CONFIG_DLL_H
