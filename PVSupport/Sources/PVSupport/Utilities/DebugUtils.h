//
//  DebugUtils.h
//  PVSupport
//
//  Created by James Addyman on 18/01/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#ifndef PVSupport_DebugUtils_h
#define PVSupport_DebugUtils_h

//MARK: Strong/Weak
#define MAKEWEAK(x)\
__weak __typeof(x)weak##x = x

#define MAKESTRONG(x)\
__strong __typeof(weak##x) strong##x = weak##x;

#define MAKESTRONG_RETURN_IF_NIL(x)\
if (weak##x == nil) return; \
__strong __typeof(weak##x) strong##x = weak##x;


//MARK: System Version
#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

// MARK: BOOLs
#define BOOL_TOGGLE(x) \
x ^= true

// MARK: X-Macros
#define QUOTE(...) @#__VA_ARGS__

//MARK: Threading

#define FORCEMAIN(x)                      \
if (![NSThread isMainThread]) {           \
	[self performSelectorOnMainThread:_cmd  \
	withObject:x   \
	waitUntilDone:YES]; \
	return;                                 \
}
#define PVAssertMainThread \
NSAssert([NSThread isMainThread], @"Not main thread");

// MARK: String

#define PVStringF( s, ... ) [NSString stringWithFormat:(s), ##__VA_ARGS__]

//MARK: Likely
#define UNLIKELY(n) __builtin_expect((n) != 0, 0)
#define LIKELY(n) __builtin_expect((n) != 0, 1)

#endif

//MARK: Direct OBJC

// Direct method and property calls with Xcode 12 and above.
#if defined(__IPHONE_14_0) || defined(__MAC_10_16) || defined(__TVOS_14_0) || defined(__WATCHOS_7_0)
#define PV_OBJC_DIRECT_MEMBERS __attribute__((objc_direct_members))
#define PV_OBJC_DIRECT __attribute__((objc_direct))
#define PV_DIRECT ,direct
#else
#define PV_OBJC_DIRECT_MEMBERS
#define PV_OBJC_DIRECT
#define PV_DIRECT
#endif

#define VISIBLE_DEFAULT __attribute__((visibility("default")))

#define PVCORE VISIBLE_DEFAULT
#define PVCORE_DIRECT_MEMBERS VISIBLE_DEFAULT PV_OBJC_DIRECT_MEMBERS
