/*
 * LoggerClient.h
 *
 * version 1.7.0 23-MAY-2016
 *
 * Part of NSLogger (client side)
 * https://github.com/fpillet/NSLogger
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010-2016 Florent Pillet All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of  Florent
 * Pillet nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 * 
 */
#import <unistd.h>
#import <pthread.h>
#import <dispatch/dispatch.h>
#import <libkern/OSAtomic.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#if !TARGET_OS_IPHONE
#import <CoreServices/CoreServices.h>
#endif

// This define is here so that user application can test whether NSLogger Client is
// being included in the project, and potentially configure their macros accordingly
#define NSLOGGER_WAS_HERE		1

/* -----------------------------------------------------------------
 * Logger option flags & default options
 * -----------------------------------------------------------------
 */
enum {
	kLoggerOption_LogToConsole						= 0x01,
	kLoggerOption_BufferLogsUntilConnection			= 0x02,
	kLoggerOption_BrowseBonjour						= 0x04,
	kLoggerOption_BrowseOnlyLocalDomain				= 0x08,
	kLoggerOption_UseSSL							= 0x10,
	kLoggerOption_CaptureSystemConsole				= 0x20,
	kLoggerOption_BrowsePeerToPeer					= 0x40
};

#define LOGGER_DEFAULT_OPTIONS	(kLoggerOption_BufferLogsUntilConnection |	\
								 kLoggerOption_BrowseBonjour |				\
								 kLoggerOption_BrowsePeerToPeer |			\
								 kLoggerOption_BrowseOnlyLocalDomain |		\
								 kLoggerOption_UseSSL |						\
								 kLoggerOption_CaptureSystemConsole)

// The Logger struct is no longer public, use the new LoggerGet[...] functions instead
typedef struct Logger Logger;

/* -----------------------------------------------------------------
 * LOGGING FUNCTIONS
 * -----------------------------------------------------------------
 */

#ifdef __cplusplus
extern "C" {
#endif

// Prevents the linker from stripping NSLogger functions
// This is mainly for linked frameworks to be able to use NSLogger dynamically.
// If you DO WANT this functionality, you need to define NSLOGGER_ALLOW_NOSTRIP
// somewhere in the header files included before this one.
#ifdef NSLOGGER_ALLOW_NOSTRIP
#define NSLOGGER_NOSTRIP __attribute__((used))
#else
#define NSLOGGER_NOSTRIP
#endif

// Set the default logger which will be the one used when passing NULL for logge
extern void LoggerSetDefaultLogger(Logger *aLogger) NSLOGGER_NOSTRIP;

// Get the default logger, create one if it does not exist
extern Logger *LoggerGetDefaultLogger(void) NSLOGGER_NOSTRIP;

// Checks whether the default logger exists, returns it if YES, otherwise do NO create one
extern Logger *LoggerCheckDefaultLogger(void) NSLOGGER_NOSTRIP;

// Initialize a new logger, set as default logger if this is the first one
// Options default to:
// - logging to console = NO
// - buffer until connection = YES
// - browse Bonjour = YES
// - browse only locally on Bonjour = YES
extern Logger* LoggerInit(void) NSLOGGER_NOSTRIP;

// Set logger options if you don't want the default options (see above)
extern void LoggerSetOptions(Logger *logger, uint32_t options) NSLOGGER_NOSTRIP;
extern uint32_t LoggerGetOptions(Logger *logger) NSLOGGER_NOSTRIP;

// Set Bonjour logging names, so you can force the logger to use a specific service type
// or direct logs to the machine on your network which publishes a specific name
extern void LoggerSetupBonjour(Logger *logger, CFStringRef bonjourServiceType, CFStringRef bonjourServiceName) NSLOGGER_NOSTRIP;
extern CFStringRef LoggerGetBonjourServiceType(Logger *logger) NSLOGGER_NOSTRIP;
extern CFStringRef LoggerGetBonjourServiceName(Logger *logger) NSLOGGER_NOSTRIP;

// Directly set the viewer host (hostname or IP address) and port we want to connect to. If set, LoggerStart() will
// try to connect there first before trying Bonjour
extern void LoggerSetViewerHost(Logger *logger, CFStringRef hostName, UInt32 port) NSLOGGER_NOSTRIP;
extern CFStringRef LoggerGetViewerHostName(Logger *logger) NSLOGGER_NOSTRIP;
extern UInt32 LoggerGetViewerPort(Logger *logger) NSLOGGER_NOSTRIP;

// Configure the logger to use a local file for buffering, instead of memory.
// - If you initially set a buffer file after logging started but while a logger connection
//   has not been acquired, the contents of the log queue will be written to the buffer file
//	 the next time a logging function is called, or when LoggerStop() is called.
// - If you want to change the buffering file after logging started, you should first
//   call LoggerStop() the call LoggerSetBufferFile(). Note that all logs stored in the previous
//   buffer file WON'T be transferred to the new file in this case.
extern void LoggerSetBufferFile(Logger *logger, CFStringRef absolutePath) NSLOGGER_NOSTRIP;
extern CFStringRef LoggerGetBufferFile(Logger *logger) NSLOGGER_NOSTRIP;

// Activate the logger, try connecting. You can pass NULL to start the default logger,
// it will return a pointer to it.
extern Logger* LoggerStart(Logger *logger) NSLOGGER_NOSTRIP;

//extern void LoggerConnectToHost(CFDataRef address, int port);

// Deactivate and free the logger.
extern void LoggerStop(Logger *logger) NSLOGGER_NOSTRIP;

// Pause the current thread until all messages from the logger have been transmitted
// this is useful to use before an assert() aborts your program. If waitForConnection is YES,
// LoggerFlush() will block even if the client is not currently connected to the desktop
// viewer. You should be using NO most of the time, but in some cases it can be useful.
extern void LoggerFlush(Logger *logger, BOOL waitForConnection) NSLOGGER_NOSTRIP;

/* Logging functions. Each function exists in four versions:
 *
 * - one without a Logger instance (uses default logger) and without filename/line/function (no F suffix)
 * - one without a Logger instance but with filename/line/function (F suffix)
 * - one with a Logger instance (use a specific Logger) and without filename/line/function (no F suffix)
 * - one with a Logger instance (use a specific Logger) and with filename/line/function (F suffix)
 *
 * The exception being the single LogMessageCompat() function which is designed to be a drop-in replacement for NSLog()
 *
 */

// Log a message, calling format compatible with NSLog
extern void LogMessageCompat(NSString *format, ...) NSLOGGER_NOSTRIP;

// Log a message without any formatting (just log the given string)
extern void LogMessageRaw(NSString *message) NSLOGGER_NOSTRIP;
extern void LogMessageRawF(const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *message) NSLOGGER_NOSTRIP;
extern void LogMessageRawToF(Logger *logger, const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *message) NSLOGGER_NOSTRIP;

// Log a message. domain can be nil if default domain.
extern void LogMessage(NSString *domain, int level, NSString *format, ...) NS_FORMAT_FUNCTION(3,4) NSLOGGER_NOSTRIP;
extern void LogMessageF(const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *format, ...) NS_FORMAT_FUNCTION(6,7) NSLOGGER_NOSTRIP;
extern void LogMessageTo(Logger *logger, NSString *domain, int level, NSString *format, ...) NS_FORMAT_FUNCTION(4,5) NSLOGGER_NOSTRIP;
extern void LogMessageToF(Logger *logger, const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *format, ...) NS_FORMAT_FUNCTION(7,8) NSLOGGER_NOSTRIP;

// Log a message. domain can be nil if default domain (versions with va_list format args instead of ...)
extern void LogMessage_va(NSString *domain, int level, NSString *format, va_list args) NS_FORMAT_FUNCTION(3,0) NSLOGGER_NOSTRIP;
extern void LogMessageF_va(const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *format, va_list args) NS_FORMAT_FUNCTION(6,0) NSLOGGER_NOSTRIP;
extern void LogMessageTo_va(Logger *logger, NSString *domain, int level, NSString *format, va_list args) NS_FORMAT_FUNCTION(4,0) NSLOGGER_NOSTRIP;
extern void LogMessageToF_va(Logger *logger, const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *format, va_list args) NS_FORMAT_FUNCTION(7,0) NSLOGGER_NOSTRIP;

// Send binary data to remote logger
extern void LogData(NSString *domain, int level, NSData *data) NSLOGGER_NOSTRIP;
extern void LogDataF(const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSData *data) NSLOGGER_NOSTRIP;
extern void LogDataTo(Logger *logger, NSString *domain, int level, NSData *data) NSLOGGER_NOSTRIP;
extern void LogDataToF(Logger *logger, const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSData *data) NSLOGGER_NOSTRIP;

// Send image data to remote logger
extern void LogImageData(NSString *domain, int level, int width, int height, NSData *data) NSLOGGER_NOSTRIP;
extern void LogImageDataF(const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, int width, int height, NSData *data) NSLOGGER_NOSTRIP;
extern void LogImageDataTo(Logger *logger, NSString *domain, int level, int width, int height, NSData *data) NSLOGGER_NOSTRIP;
extern void LogImageDataToF(Logger *logger, const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, int width, int height, NSData *data) NSLOGGER_NOSTRIP;

// Mark the start of a block. This allows the remote logger to group blocks together
extern void LogStartBlock(NSString *format, ...) NS_FORMAT_FUNCTION(1,2) NSLOGGER_NOSTRIP;
extern void LogStartBlockTo(Logger *logger, NSString *format, ...) NS_FORMAT_FUNCTION(2,3) NSLOGGER_NOSTRIP;

// Mark the end of a block
extern void LogEndBlock(void) NSLOGGER_NOSTRIP;
extern void LogEndBlockTo(Logger *logger) NSLOGGER_NOSTRIP;

// Log a marker (text can be null)
extern void LogMarker(NSString *text) NSLOGGER_NOSTRIP;
extern void LogMarkerTo(Logger *logger, NSString *text) NSLOGGER_NOSTRIP;

#ifdef __cplusplus
};
#endif
