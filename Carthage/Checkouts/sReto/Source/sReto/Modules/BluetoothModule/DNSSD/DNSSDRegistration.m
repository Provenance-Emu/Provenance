/*
    File:       DNSSDRegistration.m

    Contains:   Uses the low-level DNS-SD API to manage a Bonjour service registration.

    Written by: DTS

    Copyright:  Copyright (c) 2011 Apple Inc. All Rights Reserved.

    Disclaimer: IMPORTANT: This Apple software is supplied to you by Apple Inc.
                ("Apple") in consideration of your agreement to the following
                terms, and your use, installation, modification or
                redistribution of this Apple software constitutes acceptance of
                these terms.  If you do not agree with these terms, please do
                not use, install, modify or redistribute this Apple software.

                In consideration of your agreement to abide by the following
                terms, and subject to these terms, Apple grants you a personal,
                non-exclusive license, under Apple's copyrights in this
                original Apple software (the "Apple Software"), to use,
                reproduce, modify and redistribute the Apple Software, with or
                without modifications, in source and/or binary forms; provided
                that if you redistribute the Apple Software in its entirety and
                without modifications, you must retain this notice and the
                following text and disclaimers in all such redistributions of
                the Apple Software. Neither the name, trademarks, service marks
                or logos of Apple Inc. may be used to endorse or promote
                products derived from the Apple Software without specific prior
                written permission from Apple.  Except as expressly stated in
                this notice, no other rights or licenses, express or implied,
                are granted by Apple herein, including but not limited to any
                patent rights that may be infringed by your derivative works or
                by other works in which the Apple Software may be incorporated.

                The Apple Software is provided by Apple on an "AS IS" basis. 
                APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
                WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
                MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING
                THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                COMBINATION WITH YOUR PRODUCTS.

                IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT,
                INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
                TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
                DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY
                OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY
                OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
                OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF
                SUCH DAMAGE.

*/

#import "DNSSDRegistration.h"

#include <dns_sd.h>

#pragma mark * DNSSDRegistration

@interface DNSSDRegistration ()

// read-write versions of public properties

@property (copy,   readwrite) NSString * registeredDomain;
@property (copy,   readwrite) NSString * registeredName;

// private properties

@property (assign, readwrite) DNSServiceRef      sdRef;

// forward declarations

- (void)stopWithError:(NSError *)error notify:(BOOL)notify;

@end

@implementation DNSSDRegistration

@synthesize domain = domain_;
@synthesize type = type_;
@synthesize name = name_;
@synthesize port = port_;

@synthesize delegate = delegate_;

@synthesize registeredDomain = registeredDomain_;
@synthesize registeredName = registeredName_;

@synthesize sdRef = sdRef_;

- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name port:(NSUInteger)port
    // See comment in header.
{
    // domain may be nil or empty
    assert( ! [domain hasPrefix:@"."] );
    assert(type != nil);
    assert([type length] != 0);
    assert( ! [type hasPrefix:@"."] );
    assert(port > 0);
    assert(port < 65536);

    self = [super init];
    if (self != nil) {
        if ( ([domain length] != 0) && ! [domain hasSuffix:@"."] ) {
            domain = [domain stringByAppendingString:@"."];
        }
        if ( ! [type hasSuffix:@"."] ) {
            type = [type stringByAppendingString:@"."];
        }
        self->domain_ = [domain copy];
        self->type_   = [type copy];
        self->name_   = [name copy];
        self->port_   = port;
    }
    return self;
}

- (void)dealloc
{
    if (self->sdRef_ != NULL) {
        DNSServiceRefDeallocate(self->sdRef_);
    }
    [self->domain_ release];
    [self->type_ release];
    [self->name_ release];
    [self->registeredName_ release];
    [self->registeredDomain_ release];
    [super dealloc];
}

- (void)didRegisterWithDomain:(NSString *)domain name:(NSString *)name
    // Called when DNS-SD tells us that a registration has been added.
{
    // On the Mac this routine can get called multiple times, once for the "local." domain and again 
    // for wide-area domains.  As a matter of policy we ignore everything except the "local." 
    // domain.  The "local." domain is really the flagship domain here; that's what our clients 
    // care about.  If it works but a wide-area registration fails, we don't want to error out. 
    // Conversely, if a wide-area registration succeeds but the "local." domain fails, that 
    // is a good reason to fail totally.

    assert([domain caseInsensitiveCompare:@"local"] != NSOrderedSame);      // DNS-SD always gives us the trailing dot; complain otherwise.
    
    if ( [domain caseInsensitiveCompare:@"local."] == NSOrderedSame ) {
        self.registeredDomain = domain;
        self.registeredName   = name;
        if ([self.delegate respondsToSelector:@selector(dnssdRegistrationDidRegister:)]) {
            [self.delegate dnssdRegistrationDidRegister:self];
        }
    }
}

- (void)didUnregisterWithDomain:(NSString *)domain name:(NSString *)name
    // Called when DNS-SD tells us that a registration has been removed.
{
    #pragma unused(name)
    
    // The registration can be removed in the following cases:
    //
    // A. When you register with the default name (that is, passing the empty string 
    //    to the "name" parameter of DNSServiceRegister) /and/ you specify the 'no rename' 
    //    flags (kDNSServiceFlagsNoAutoRename) /and/ the computer name changes.
    //
    // B. When you successfully register in a domain and then the domain becomes unavailable 
    //    (for example, if you turn off Back to My Mac after registering).
    //
    // Case B we ignore based on the same policy outlined in -didRegisterWithDomain:name:.
    //
    // Case A is interesting and we handle it here.
    
    assert([domain caseInsensitiveCompare:@"local"] != NSOrderedSame);      // DNS-SD always gives us the trailing dot; complain otherwise.
    
    if ( [domain caseInsensitiveCompare:@"local."] == NSOrderedSame ) {
        [self stopWithError:[NSError errorWithDomain:NSNetServicesErrorDomain code:kDNSServiceErr_NameConflict userInfo:nil] notify:YES];
    }
}

static void RegisterReplyCallback(
    DNSServiceRef       sdRef,
    DNSServiceFlags     flags,
    DNSServiceErrorType errorCode,
    const char *        name,
    const char *        regtype,
    const char *        domain,
    void *              context
)
    // Called by DNS-SD when something happens with the registered service.
{
    DNSSDRegistration *    obj;
    #pragma unused(flags)
    #pragma unused(regtype)

    assert([NSThread isMainThread]);        // because sdRef dispatches to the main queue
    
    obj = (DNSSDRegistration *) context;
    assert([obj isKindOfClass:[DNSSDRegistration class]]);
    assert(sdRef == obj->sdRef_);
    #pragma unused(sdRef)
    
    if (errorCode == kDNSServiceErr_NoError) {
        assert([[NSString stringWithUTF8String:regtype] caseInsensitiveCompare:obj.type] == NSOrderedSame);
        if (flags & kDNSServiceFlagsAdd) {
            [obj didRegisterWithDomain:[NSString stringWithUTF8String:domain] name:[NSString stringWithUTF8String:name]];
        } else {
            [obj didUnregisterWithDomain:[NSString stringWithUTF8String:domain] name:[NSString stringWithUTF8String:name]];
        }
    } else {
        [obj stopWithError:[NSError errorWithDomain:NSNetServicesErrorDomain code:errorCode userInfo:nil] notify:YES];
    }
}

- (void)start
    // See comment in header.
{
    DNSServiceErrorType     errorCode;

    if (self.sdRef == NULL) {
        NSString *  name;
        NSString *  domain;
        
        domain = self.domain;
        if (domain == nil) {
            domain = @"";
        }
        name = self.name;
        if (name == nil) {
            name = @"";
        }
    
        errorCode = DNSServiceRegister(&self->sdRef_, kDNSServiceFlagsIncludeP2P, kDNSServiceInterfaceIndexP2P, [name UTF8String], [self.type UTF8String], [domain UTF8String], NULL, htons(self.port), 0, NULL, RegisterReplyCallback, self);
        if (errorCode == kDNSServiceErr_NoError) {
            errorCode = DNSServiceSetDispatchQueue(self.sdRef, dispatch_get_main_queue());
        }
        if (errorCode == kDNSServiceErr_NoError) {
            if ([self.delegate respondsToSelector:@selector(dnssdRegistrationWillRegister:)]) {
                [self.delegate dnssdRegistrationWillRegister:self];
            }
        } else {
            [self stopWithError:[NSError errorWithDomain:NSNetServicesErrorDomain code:errorCode userInfo:nil] notify:YES];
        }
    }
}

- (void)stopWithError:(NSError *)error notify:(BOOL)notify
    // An internal bottleneck for shutting down the object.
{
    if (notify) {
        if (error != nil) {
            if ([self.delegate respondsToSelector:@selector(dnssdRegistration:didNotRegister:)]) {
                [self.delegate dnssdRegistration:self didNotRegister:error];
            }
        }
    }
    self.registeredDomain = nil;
    self.registeredName = nil;
    if (self.sdRef != NULL) {
        DNSServiceRefDeallocate(self.sdRef);
        self.sdRef = NULL;
    }
    if (notify) {
        if ([self.delegate respondsToSelector:@selector(dnssdRegistrationDidStop:)]) {
            [self.delegate dnssdRegistrationDidStop:self];
        }
    }
}

- (void)stop
    // See comment in header.
{
    [self stopWithError:nil notify:NO];
}

@end
