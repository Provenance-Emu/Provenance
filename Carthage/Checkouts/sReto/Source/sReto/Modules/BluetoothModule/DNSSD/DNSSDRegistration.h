/*
    File:       DNSSDRegistration.h

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

#import <Foundation/Foundation.h>

// forward declarations

@protocol DNSSDRegistrationDelegate;

#pragma mark * DNSSDRegistration

// DNSSDRegistration represents a service that you can register on the network.

@interface DNSSDRegistration : NSObject

- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name port:(NSUInteger)port;
    // domain and name can be nil or the empty string to get default behaviour.
    //
    // type must be of the form "_foo._tcp." or "_foo._udp." (possibly without the 
    // trailing dot, see below).
    //
    // port must be in the range 1..65535.
    // 
    // domain and type should include the trailing dot; if they don't, one is added 
    // and that change is reflected in the domain and type properties.
    // 
    // domain and type must not include a leading dot.

// properties that are set up by the init method

@property (copy,   readonly ) NSString * domain;
@property (copy,   readonly ) NSString * type;
@property (copy,   readonly ) NSString * name;
@property (assign, readonly ) NSUInteger port;

// properties that you can change any time

@property (assign, readwrite) id<DNSSDRegistrationDelegate> delegate;

- (void)start;
    // Starts the registration process.  Does nothing if the registration is currently started.

- (void)stop;
    // Stops a registration, deregistering the service from the network.  Does nothing if the 
    // registration is not started.

// properties that are set up once the registration is in place

@property (copy,   readonly ) NSString * registeredDomain;
@property (copy,   readonly ) NSString * registeredName;

@end

@protocol DNSSDRegistrationDelegate <NSObject>

// All delegate methods are called on the main thread.

@optional

- (void)dnssdRegistrationWillRegister:(DNSSDRegistration *)sender;
    // Called before the registration process starts.

- (void)dnssdRegistrationDidRegister:(DNSSDRegistration *)sender;
    // Called when the service is successfully registered.  At this point 
    // registeredName and registeredDomain are valid.

- (void)dnssdRegistration:(DNSSDRegistration *)sender didNotRegister:(NSError *)error;
    // Called when the service can't be registered.  The registration will be stopped 
    // immediately after this delegate method returns.

- (void)dnssdRegistrationDidStop:(DNSSDRegistration *)sender;
    // Called when the registration stops (except if you call -stop on it).

@end
