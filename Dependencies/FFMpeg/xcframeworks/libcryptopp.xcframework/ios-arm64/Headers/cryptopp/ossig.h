// ossig.h - written and placed in the public domain by Jeffrey Walton
//
/// \file ossig.h
/// \brief Utility class for trapping OS signals.
/// \since Crypto++ 5.6.5

#ifndef CRYPTOPP_OS_SIGNAL_H
#define CRYPTOPP_OS_SIGNAL_H

#include "config.h"

#if defined(UNIX_SIGNALS_AVAILABLE)
# include <signal.h>
#endif

NAMESPACE_BEGIN(CryptoPP)

// ************** Unix and Linux compatibles ***************

#if defined(UNIX_SIGNALS_AVAILABLE) || defined(CRYPTOPP_DOXYGEN_PROCESSING)

/// \brief Signal handler function pointer
/// \details SignalHandlerFn is provided as a stand alone function pointer with external "C" linkage
/// \sa SignalHandler, NullSignalHandler
extern "C" {
    typedef void (*SignalHandlerFn) (int);
}

/// \brief Null signal handler function
/// \param unused the signal number
/// \details NullSignalHandler is provided as a stand alone function with external "C" linkage
///  and not a static member function due to the member function's implicit
///  external "C++" linkage.
/// \sa SignalHandler, SignalHandlerFn
extern "C" {
    inline void NullSignalHandler(int unused) {CRYPTOPP_UNUSED(unused);}
}

/// Signal handler for Linux and Unix compatibles
/// \tparam S Signal number
/// \tparam O Flag indicating if an existing handler should be overwritten
/// \details SignalHandler() can be used to install a signal handler with the signature
///  <tt>void handler_fn(int)</tt>. If <tt>SignalHandlerFn</tt> is not <tt>NULL</tt>, then
///  the sigaction is set to the function and the sigaction flags is set to the flags.
///  If <tt>SignalHandlerFn</tt> is <tt>NULL</tt>, then a default handler is installed
///  using sigaction flags set to 0. The default handler only returns from the call.
/// \details Upon destruction the previous signal handler is restored if the former signal handler
///  was replaced.
/// \details On Cygwin systems using Newlib, you should define <tt>_XOPEN_SOURCE=700</tt> or
///  <tt>_GNU_SOURCE</tt>; or use <tt>-std=gnu++03</tt>, <tt>-std=gnu++11</tt>, or similar. If
///  you compile with <tt>-std=c++03</tt>, <tt>-std=c++11</tt> or similar, then define
///  <tt>_XOPEN_SOURCE=700</tt>.
/// \warning Do not use SignalHandler in a code block that uses <tt>setjmp</tt> or <tt>longjmp</tt>
///  because the destructor may not run.
/// \since Crypto++ 5.6.5
/// \sa NullSignalHandler, SignalHandlerFn, \ref CRYPTOPP_ASSERT "CRYPTOPP_ASSERT", DebugTrapHandler
template <int S, bool O=false>
struct SignalHandler
{
    /// \brief Construct a signal handler
    /// \param pfn Pointer to a signal handler function
    /// \param flags Flags to use with the signal handler
    /// \details SignalHandler() installs a signal handler with the signature
    ///  <tt>void handler_fn(int)</tt>. If <tt>SignalHandlerFn</tt> is not <tt>NULL</tt>, then
    ///  the sigaction is set to the function and the sigaction flags is set to the flags.
    ///  If <tt>SignalHandlerFn</tt> is <tt>NULL</tt>, then a default handler is installed
    ///  using sigaction flags set to 0. The default handler only returns from the call.
    /// \details Upon destruction the previous signal handler is restored if the former signal handler
    ///  was overwritten.
    /// \details On Cygwin systems using Newlib, you should define <tt>_XOPEN_SOURCE=700</tt> or
    ///  <tt>_GNU_SOURCE</tt>; or use <tt>-std=gnu++03</tt>, <tt>-std=gnu++11</tt>, or similar. If
    ///  you compile with <tt>-std=c++03</tt>, <tt>-std=c++11</tt> or similar, then define
    ///  <tt>_XOPEN_SOURCE=700</tt>.
    /// \warning Do not use SignalHandler in a code block that uses <tt>setjmp</tt> or <tt>longjmp</tt>
    ///  because the destructor may not run. <tt>setjmp</tt> is why cpu.cpp does not use SignalHandler
    ///  during CPU feature testing.
    /// \since Crypto++ 5.6.5
    SignalHandler(SignalHandlerFn pfn = NULLPTR, int flags = 0) : m_installed(false)
    {
        // http://pubs.opengroup.org/onlinepubs/007908799/xsh/sigaction.html
        struct sigaction new_handler;

        do
        {
            int ret = 0;

            ret = sigaction (S, 0, &m_old);
            if (ret != 0) break; // Failed

            // Don't step on another's handler if Overwrite=false
            if (m_old.sa_handler != 0 && !O) break;

            // Cygwin/Newlib requires -D_XOPEN_SOURCE=700
            ret = sigemptyset (&new_handler.sa_mask);
            if (ret != 0) break; // Failed

            new_handler.sa_handler = (pfn ? pfn : &NullSignalHandler);
            new_handler.sa_flags = (pfn ? flags : 0);

            // Install it
            ret = sigaction (S, &new_handler, 0);
            if (ret != 0) break; // Failed

            m_installed = true;

        } while(0);
    }

    ~SignalHandler()
    {
        if (m_installed)
            sigaction (S, &m_old, 0);
    }

private:
    struct sigaction m_old;
    bool m_installed;

private:
    // Not copyable
    SignalHandler(const SignalHandler &);
    void operator=(const SignalHandler &);
};
#endif

NAMESPACE_END

#endif // CRYPTOPP_OS_SIGNAL_H
