/*
    File:       DNSSDService.h

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

#import <Foundation/Foundation.h>

// forward declarations

@protocol DNSSDServiceDelegate;

#pragma mark * DNSSDService

// DNSSDService represents a service discovered on the network.  You can use it to 
// resolve that service, and get a DNS name and port to connect to.

@interface DNSSDService : NSObject <NSCopying>

- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name;
    // In most cases you don't need to construct a DNSSDService object because you get it 
    // back from a DNSSDBrowser.  However, if you do need to construct one, it's fine to 
    // do so by calling this method.
    //
    // domain, type and name must not be nil or the empty string.  type must be of the 
    // form "_foo._tcp." or "_foo._udp." (possibly without the trailing dot, see below).
    // 
    // domain and type should include the trailing dot; if they don't, one is added 
    // and that change is reflected in the domain and type properties.
    // 
    // domain and type must not include a leading dot.

// DNSSDService implements -isEqual: based on a comparison of the domain, type and name, and  
// it implements -hash correspondingly.  This allows you to use DNSSDService objects in sets, 
// as dictionary keys, and so on.
//
// IMPORTANT: This uses case-sensitive comparison.  In general DNS is case insensitive. 
// DNS-SD will always pass you services with a consistent case, so using case sensitive 
// comparison here is not a problem.  You might run into problems, however, if you do 
// odd things like manually create a DNSSDService with the domain set to "LOCAL." instead 
// of "local.".
// 
// DNSSDService also implements NSCopying.  When you copy a service, the copy has the same 
// domain, type and name as the original.  However, the copy does not bring across any of 
// the resolution state.  Specifically:
//
// o If the original was resolving, the copy is not.
//
// o If the original had successfully resolved (and thus has resolvedHost and resolvedPort set), 
//   these results are not present in the copy.
//
// However, because the domain, type and name are copied, and these are the only things 
// considered by -isEqual: and -hash, DNSSDService can be used as a dictionary key.

// properties that are set up by the init method

@property (copy,   readonly ) NSString * domain;
@property (copy,   readonly ) NSString * type;
@property (copy,   readonly ) NSString * name;

// properties that you can change any time

@property (assign, readwrite) id<DNSSDServiceDelegate> delegate;

- (void)startResolve;
    // Starts a resolve.  Starting a resolve on a service that is currently resolving 
    // is a no-op.  If the resolve does not complete within 30 seconds, it will fail 
    // with a time out.

- (void)stop;
    // Stops a resolve.  Stopping a resolve on a service that is not resolving is a no-op.

// properties that are set up once the resolve completes

@property (copy,   readonly ) NSString * resolvedHost;
@property (assign, readonly ) NSUInteger resolvedPort;

@end

@protocol DNSSDServiceDelegate <NSObject>

// All delegate methods are called on the main thread.

@optional

- (void)dnssdServiceWillResolve:(DNSSDService *)service;
    // Called before the service starts resolving.

- (void)dnssdServiceDidResolveAddress:(DNSSDService *)service;
    // Called when the service successfully resolves.  The resolve will be stopped 
    // immediately after this delegate method returns.

- (void)dnssdService:(DNSSDService *)service didNotResolve:(NSError *)error;
    // Called when the service fails to resolve.  The resolve will be stopped 
    // immediately after this delegate method returns.

- (void)dnssdServiceDidStop:(DNSSDService *)service;
    // Called when a resolve stops (except if you call -stop on it).

@end
