//
//  DebugUtils.h
//  PVSupport
//
//  Created by James Addyman on 18/01/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#ifndef PVSupport_DebugUtils_h
#define PVSupport_DebugUtils_h

#define MAKEWEAK(x)\
__weak __typeof(x)weak##x = x

#define MAKESTRONG(x)\
__strong __typeof(weak##x) strong##x = weak##x;

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define BOOL_TOGGLE(x) \
x ^= true

#define QUOTE(...) @#__VA_ARGS__

#define FORCEMAIN(x)                      \
if (![NSThread isMainThread]) {           \
	[self performSelectorOnMainThread:_cmd  \
	withObject:x   \
	waitUntilDone:YES]; \
	return;                                 \
}

#define PVStringF( s, ... ) [NSString stringWithFormat:(s), ##__VA_ARGS__]

#define PVAssertMainThread \
NSAssert([NSThread isMainThread], @"Not main thread");

#endif
