// Copyright 2021 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#import "DOLJitManager.h"

#define _USE_ALTKIT (!TARGET_OS_TV && !TARGET_OS_WATCH && !TARGET_OS_MACCATALYST)

#if _USE_ALTKIT
@import AltKit;
#endif

#import <dlfcn.h>

#import <sys/sysctl.h>
#import "Provenance-Swift.h"

#import "CodeSignatureUtils.h"
#import "DebuggerUtils.h"
#import "StringUtils.h"

NSString* const DOLJitAcquiredNotification = @"org.provenance-emu.provenance.jit-acquired";
NSString* const DOLJitAltJitFailureNotification = @"org.provenance-emu.provenance.jit-altjit-failure";

@implementation DOLJitManager
{
    DOLJitType _m_jit_type;
    NSString* _m_aux_error;
    bool _m_has_acquired_jit;
    bool _m_is_discovering_altserver;
}

+ (DOLJitManager*)sharedManager
{
    static dispatch_once_t _once_token = 0;
    static DOLJitManager* _shared_manager = nil;
    
    dispatch_once(&_once_token, ^{
        _shared_manager = [[self alloc] init];
    });
    
    return _shared_manager;
}

- (id)init {
    if ((self = [super init]))
    {
        _m_jit_type = DOLJitTypeNone;
        _m_aux_error = nil;
        _m_has_acquired_jit = false;
        _m_is_discovering_altserver = false;
    }
    
    return self;
}

- (NSString*)getCpuArchitecture {
    // Query MobileGestalt for the CPU architecture
    void* gestalt_handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (!gestalt_handle)
    {
        return nil;
    }
    
    typedef NSString* (*MGCopyAnswer_ptr)(NSString*);
    MGCopyAnswer_ptr MGCopyAnswer = (MGCopyAnswer_ptr)dlsym(gestalt_handle, "MGCopyAnswer");
    
    if (!MGCopyAnswer)
    {
        return nil;
    }
    
    NSString* cpu_architecture = MGCopyAnswer(@"k7QIBwZJJOVw+Sej/8h8VA"); // "CPUArchitecture"
    
    dlclose(gestalt_handle);
    
    return cpu_architecture;
}

- (bool)canAcquireJitByUnsigned {
    NSString* cpu_architecture = [self getCpuArchitecture];
    
    if (cpu_architecture == nil)
    {
        [self setAuxiliaryError:@"CPU architecture check failed."];
        return false;
    }
    else if (![cpu_architecture isEqualToString:@"arm64e"])
    {
        return false;
    }
    else if (!HasValidCodeSignature())
    {
        return false;
    }
    
    return true;
}

- (void)attemptToAcquireJitOnStartup {
#if TARGET_OS_SIMULATOR
    // We're running on macOS, so JITs aren't restricted.
    self->_m_jit_type = DOLJitTypeNotRestricted;
#elif defined(NONJAILBROKEN)
    if (@available(iOS 14.5, *))
    {
        self->_m_jit_type = DOLJitTypeDebugger;
    }
    else if (@available(iOS 14.4, *))
    {
        size_t build_str_size;
        sysctlbyname("kern.osversion", NULL, &build_str_size, NULL, 0);
        
        char build_c_str[build_str_size];
        sysctlbyname("kern.osversion", &build_c_str, &build_str_size, NULL, 0);
        
        // iOS 14.4 developer beta 1 still has the JIT workaround, so check if we're running
        // that version
        NSString* build_str = CToFoundationString(build_c_str);
        if ([build_str isEqualToString:@"18D5030e"] && [self canAcquireJitByUnsigned])
        {
            self->_m_jit_type = DOLJitTypeAllowUnsigned;
        }
        else
        {
            self->_m_jit_type = DOLJitTypeDebugger;
        }
    }
    else if (@available(iOS 14.2, *))
    {
        bool success = [self canAcquireJitByUnsigned];
        if (success)
        {
            self->_m_jit_type = DOLJitTypeAllowUnsigned;
        }
        else
        {
            self->_m_jit_type = DOLJitTypeDebugger;
        }
    }
    else if (@available(iOS 14, *))
    {
        self->_m_jit_type = DOLJitTypeDebugger;
    }
    else if (@available(iOS 13.5, *))
    {
        self->_m_jit_type = DOLJitTypePTrace;
    }
    else
    {
        self->_m_jit_type = DOLJitTypeDebugger;
    }
#else // jailbroken
    self->_m_jit_type = DOLJitTypeDebugger;
#endif
    
    switch (self->_m_jit_type)
    {
        case DOLJitTypeDebugger:
#ifdef NONJAILBROKEN
            self->_m_has_acquired_jit = IsProcessDebugged();
#else
            // Check for jailbreakd (Chimera, Electra, Odyssey...)
            if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/run/jailbreakd.pid"])
            {
                self->_m_has_acquired_jit = SetProcessDebuggedWithJailbreakd();
            }
            else
            {
                self->_m_has_acquired_jit = SetProcessDebuggedWithDaemon();
            }
#endif
            break;
        case DOLJitTypeAllowUnsigned:
        case DOLJitTypeNotRestricted:
            self->_m_has_acquired_jit = true;
            
            break;
        case DOLJitTypePTrace:
            SetProcessDebuggedWithPTrace();
            
            self->_m_has_acquired_jit = true;
            
            break;
        case DOLJitTypeNone: // should never happen
            break;
    }
}

- (void)recheckHasAcquiredJit {
    if (self->_m_has_acquired_jit) {
        return;
    }
    
#ifdef NONJAILBROKEN
    if (self->_m_jit_type == DOLJitTypeDebugger) {
        self->_m_has_acquired_jit = IsProcessDebugged();
    }
#endif
}

- (void)attemptToAcquireJitByWaitingForDebuggerUsingCancellationToken:(DOLCancellationToken*)token {
    if (self->_m_jit_type != DOLJitTypeDebugger) {
        return;
    }
    
    if (self->_m_has_acquired_jit) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        while (!IsProcessDebugged()) {
            if ([token isCancelled]) {
                return;
            }
            
            sleep(1);
        }
        
        self->_m_has_acquired_jit = true;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DOLJitAcquiredNotification object:self];
    });
}

- (void)attemptToAcquireJitByAltJIT {
#if _USE_ALTKIT
    if (self->_m_jit_type != DOLJitTypeDebugger) {
        return;
    }
    if (self->_m_has_acquired_jit) {
        return;
    }
    
    if (_m_is_discovering_altserver) {
        return;
    }
    
    self->_m_is_discovering_altserver = true;
    
    [[ALTServerManager sharedManager] startDiscovering];
    
    [[ALTServerManager sharedManager] autoconnectWithCompletionHandler:^(ALTServerConnection* connection, NSError* error) {
        [[ALTServerManager sharedManager] stopDiscovering];
        
        if (error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:DOLJitAltJitFailureNotification object:self userInfo:@{
                @"nserror": error
            }];
            
            self->_m_is_discovering_altserver = false;
            
            return;
        }
        
        [connection enableUnsignedCodeExecutionWithCompletionHandler:^(bool success, NSError* error) {
            if (success) {
                // Don't post a notification here, since attemptToAcquireJitByWaitingForDebuggerUsingCancellationToken
                // will do it for us.
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:DOLJitAltJitFailureNotification object:self userInfo:@{
                    @"nserror": error
                }];
            }
            
            [connection disconnect];
            
            self->_m_is_discovering_altserver = false;
        }];
    }];
#else
    return;
#endif
}

- (void)attemptToAcquireJitByJitStreamer {
    if (self->_m_jit_type != DOLJitTypeDebugger) {
        ELOG(@"self->_m_jit_type != DOLJitTypeDebugger. Is %i", self->_m_jit_type);
        return;
    }
    
    if (self->_m_has_acquired_jit) {
        ILOG(@"_m_has_acquired_jit == true");
        return;
    }
    // 69.69.0.1 or my ip?
    NSString* url_string = [NSString stringWithFormat:@"http://69.69.0.1/attach/%ld/", (long)getpid()];
    ILOG(@"JIT: URL <%@>", url_string);
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url_string]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[@"" dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(error != nil) {
            ELOG(@"JIT: %@", error.localizedDescription);
            return;
        }
        if(response) {
            ILOG(@"JIT: Response: %@", response.debugDescription);
        }
        if(data && data.length > 0) {
            NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            ILOG(@"JIT: %@", dataString);
        }
    }];
    [dataTask resume];
}

- (DOLJitType)jitType {
    return _m_jit_type;
}

- (BOOL)appHasAcquiredJit {
    return _m_has_acquired_jit;
}

- (void)setAuxiliaryError:(NSString*)error {
    self->_m_aux_error = error;
}

- (nullable NSString*)getAuxiliaryError {
    return self->_m_aux_error;
}

@end
