 /*
    File:       DNSSDService.m

    Contains:   Represents a Bonjour service found by the low-level DNS-SD API.

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

#import "DNSSDService.h"

#include <dns_sd.h>

#pragma mark * DNSSDService

@interface DNSSDService ()

// read-write versions of public properties

@property (copy,   readwrite) NSString * resolvedHost;
@property (assign, readwrite) NSUInteger resolvedPort;

// private properties

@property (assign, readwrite) DNSServiceRef      sdRef;
@property (retain, readwrite) NSTimer *          resolveTimeoutTimer;

// forward declarations

- (void)stopWithError:(NSError *)error notify:(BOOL)notify;

@end

@implementation DNSSDService

@synthesize domain = domain_;
@synthesize type = type_;
@synthesize name = name_;

@synthesize delegate = delegate_;

@synthesize resolvedHost = resolvedHost_;
@synthesize resolvedPort = resolvedPort_;

@synthesize sdRef = sdRef_;
@synthesize resolveTimeoutTimer = resolveTimeoutTimer_;

- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name
    // See comment in header.
{
    assert(domain != nil);
    assert([domain length] != 0);
    assert( ! [domain hasPrefix:@"."] );
    assert(type != nil);
    assert([type length] != 0);
    assert( ! [type hasPrefix:@"."] );
    assert(name != nil);
    assert([name length] != 0);
    self = [super init];
    if (self != nil) {
        if ( ! [domain hasSuffix:@"."] ) {
            domain = [domain stringByAppendingString:@"."];
        }
        if ( ! [type hasSuffix:@"."] ) {
            type = [type stringByAppendingString:@"."];
        }
        self->domain_ = [domain copy];
        self->type_   = [type copy];
        self->name_   = [name copy];
    }
    return self;
}

- (void)dealloc
{
    if (self->sdRef_ != NULL) {
        DNSServiceRefDeallocate(self->sdRef_);
    }
    [self->resolveTimeoutTimer_ invalidate];
    [self->resolveTimeoutTimer_ release];
    [self->domain_ release];
    [self->type_ release];
    [self->name_ release];
    [self->resolvedHost_ release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
    // Part of the NSCopying protocol, as discussed in the header.
{
    return [[[self class] allocWithZone:zone] initWithDomain:self.domain type:self.type name:self.name];
}

// We have to implement -isEqual: and -hash to allow the object to function correctly 
// when placed in sets.

- (BOOL)isEqual:(id)object
    // See comment in header.
{
    DNSSDService *   other;

    // Boilerplate stuff.
    
    if (object == self) {
        return YES;
    }
    if ( ! [object isKindOfClass:[self class]] ) {
        return NO;
    }
    
    // Compare the domain, type and name.
    
    other = (DNSSDService *) object;
    return [self.domain isEqualToString:other.domain] && [self.type isEqualToString:other.type] && [self.name isEqualToString:other.name];
}

- (NSUInteger)hash
    // See comment in header.
{
    return [self.domain hash] ^ [self.type hash] ^ [self.name hash];
}

- (NSString *)description
    // We override description to make it easier to debug operations that involve lots of DNSSDService 
    // objects.  This is really helpful, for example, when you have an NSSet of discovered services and 
    // you want to check that new services are being added correctly.
{
    return [NSString stringWithFormat:@"%@ {%@, %@, %@}", [super description], self.domain, self.type, self.name];
}

- (void)resolveReplyWithTarget:(NSString *)resolvedHost port:(NSUInteger)port
    // Called when DNS-SD tells us that a resolve has succeeded.
{
    assert(resolvedHost != nil);
    
    // Latch the results.
    
    self.resolvedHost = resolvedHost;
    self.resolvedPort = port;
    
    // Tell our delegate.
    
    if ([self.delegate respondsToSelector:@selector(dnssdServiceDidResolveAddress:)]) {
        [self.delegate dnssdServiceDidResolveAddress:self];
    }
    
    // Stop resolving.  It's common for clients to forget to do this, so we always do 
    // it as a matter of policy.  If you want to issue a long-running resolve, you're going 
    // to have tweak this code.
    
    [self stopWithError:nil notify:YES];
}

static void ResolveReplyCallback(
    DNSServiceRef           sdRef,
    DNSServiceFlags         flags,
    uint32_t                interfaceIndex,
    DNSServiceErrorType     errorCode,
    const char *            fullname,
    const char *            hosttarget,
    uint16_t                port,
    uint16_t                txtLen,
    const unsigned char *   txtRecord,
    void *                  context
)
    // Called by DNS-SD when something happens with the resolve operation.
{
    DNSSDService *       obj;
    #pragma unused(interfaceIndex)

    assert([NSThread isMainThread]);        // because sdRef dispatches to the main queue
    
    obj = (DNSSDService *) context;
    
    assert([obj isKindOfClass:[DNSSDService class]]);
    assert(sdRef == obj->sdRef_);
    #pragma unused(sdRef)
    #pragma unused(flags)
    #pragma unused(fullname)
    #pragma unused(txtLen)
    #pragma unused(txtRecord)
    
    if (errorCode == kDNSServiceErr_NoError) {
        [obj resolveReplyWithTarget:[NSString stringWithUTF8String:hosttarget] port:ntohs(port)];
    } else {
        [obj stopWithError:[NSError errorWithDomain:NSNetServicesErrorDomain code:errorCode userInfo:nil] notify:YES];
    }
}

- (void)startResolve
    // See comment in header.
{
    if (self.sdRef == NULL) {
        DNSServiceErrorType errorCode;

        errorCode = DNSServiceResolve(&self->sdRef_, kDNSServiceFlagsIncludeP2P, kDNSServiceInterfaceIndexP2P, [self.name UTF8String], [self.type UTF8String], [self.domain UTF8String], ResolveReplyCallback, self);
        if (errorCode == kDNSServiceErr_NoError) {
            errorCode = DNSServiceSetDispatchQueue(self.sdRef, dispatch_get_main_queue());
        }
        if (errorCode == kDNSServiceErr_NoError) {

            // Service resolution /never/ times out.  This is convenient in some circumstances, 
            // but it's generally best to use some reasonable timeout.  Here we use an NSTimer 
            // to trigger a failure if we spend more than 30 seconds waiting for the resolve.

            self.resolveTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(didFireResolveTimeoutTimer:) userInfo:nil repeats:NO];

            if ([self.delegate respondsToSelector:@selector(dnssdServiceWillResolve:)]) {
                [self.delegate dnssdServiceWillResolve:self];
            }
        } else {
            [self stopWithError:[NSError errorWithDomain:NSNetServicesErrorDomain code:errorCode userInfo:nil] notify:YES];
        }
    }
}

- (void)didFireResolveTimeoutTimer:(NSTimer *)timer
{
    assert(timer == self.resolveTimeoutTimer);
    [self stopWithError:[NSError errorWithDomain:NSNetServicesErrorDomain code:kDNSServiceErr_Timeout userInfo:nil] notify:YES];
}

- (void)stopWithError:(NSError *)error notify:(BOOL)notify
    // An internal bottleneck for shutting down the object.
{
    if (notify) {
        if (error != nil) {
            if ([self.delegate respondsToSelector:@selector(dnssdService:didNotResolve:)]) {
                [self.delegate dnssdService:self didNotResolve:error];
            }
        }
    }
    if (self.sdRef != NULL) {
        DNSServiceRefDeallocate(self.sdRef);
        self.sdRef = NULL;
    }
    [self.resolveTimeoutTimer invalidate];
    self.resolveTimeoutTimer = nil;
    if (notify) {
        if ([self.delegate respondsToSelector:@selector(dnssdServiceDidStop:)]) {
            [self.delegate dnssdServiceDidStop:self];
        }
    }
}

- (void)stop
    // See comment in header.
{
    [self stopWithError:nil notify:NO];
}

@end
