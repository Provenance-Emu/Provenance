//
//  DebugUtils.h
//  PVSupport
//
//  Created by James Addyman on 18/01/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#ifndef PVSupport_DebugUtils_h
#define PVSupport_DebugUtils_h

// Define log levels
#define LOG_LEVEL_VERBOSE 0
#define LOG_LEVEL_DEBUG 1
#define LOG_LEVEL_INFO 2
#define LOG_LEVEL_WARN 3
#define LOG_LEVEL_ERROR 4

// Set current log level
#ifdef DEBUG
#define CURRENT_LOG_LEVEL LOG_LEVEL_DEBUG
#else
#define CURRENT_LOG_LEVEL LOG_LEVEL_INFO
#endif

#define LOG_MACRO(emoji, lvlString, fmt,...) \
    NSLog(@"%@ [%s] %s:%d\n  ↪︎ " fmt, emoji, lvlString, __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

#if CURRENT_LOG_LEVEL <= LOG_LEVEL_VERBOSE
    #define VLOG(fmt,...) LOG_MACRO(@"🔀", "V", fmt, ##__VA_ARGS__)
#else
    #define VLOG(...)
#endif

#if CURRENT_LOG_LEVEL <= LOG_LEVEL_DEBUG
    #define DLOG(fmt,...) LOG_MACRO(@"🔹", "Debug", fmt, ##__VA_ARGS__)
    #define DLog(fmt,...) DLOG(fmt, ##__VA_ARGS__)
#else
    #define DLog(...)
    #define DLOG(...)
#endif

#if CURRENT_LOG_LEVEL <= LOG_LEVEL_INFO
    #define ILOG(fmt,...) LOG_MACRO(@"🔸", "Info", fmt, ##__VA_ARGS__)
#else
    #define ILOG(...)
#endif

#if CURRENT_LOG_LEVEL <= LOG_LEVEL_WARN
    #define WLOG(fmt,...) LOG_MACRO(@"⚠️", "Warning", fmt, ##__VA_ARGS__)
#else
    #define WLOG(...)
#endif

#if CURRENT_LOG_LEVEL <= LOG_LEVEL_ERROR
    #define ELOG(fmt,...) LOG_MACRO(@"❗", "Error", fmt, ##__VA_ARGS__)
#else
    #define ELOG(...)
#endif

#endif
