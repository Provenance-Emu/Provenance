/*
    File:       DNSSDBrowser.h

    Contains:   Uses the low-level DNS-SD API to browse for Bonjour services.

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

#import "DNSSDService.h"

// forward declarations

@protocol DNSSDBrowserDelegate;

#pragma mark * DNSSDBrowser

// DNSSDBrowser allows you to browse for services on the network, and be informed 
// of their coming and going.

@interface DNSSDBrowser : NSObject

- (id)initWithDomain:(NSString *)domain type:(NSString *)type;
    // domain may be nil or the empty string, to specify browsing in all default 
    // browsing domains.
    //
    // type must be of the form "_foo._tcp." or "_foo._udp." (possibly without the 
    // trailing dot, see below).
    // 
    // domain and type should include the trailing dot; if they don't, one is added 
    // and that change is reflected in the domain and type properties.
    // 
    // domain and type must not include a leading dot.

// properties that are set up by the init method

@property (copy,   readonly ) NSString * domain;
@property (copy,   readonly ) NSString * type;

// properties that you can change any time

@property (assign, readwrite) id <DNSSDBrowserDelegate> delegate;

- (void)startBrowse;
    // Starts a browse.  Starting a browse on a browser that is currently browsing 
    // is a no-op.

- (void)stop;
    // Stops a browse.  Stopping a browse on a browser that is not browsing is a no-op.

@end

@protocol DNSSDBrowserDelegate <NSObject>

// All delegate methods are called on the main thread.

@optional

- (void)dnssdBrowserWillBrowse:(DNSSDBrowser *)browser;
    // Called before the browser starts browsing.

- (void)dnssdBrowserDidStopBrowse:(DNSSDBrowser *)browser;
    // Called when a browser stops browsing (except if you call -stop on it).

- (void)dnssdBrowser:(DNSSDBrowser *)browser didNotBrowse:(NSError *)error;
    // Called when the browser fails to start browsing.  The browser will be stopped 
    // immediately after this delegate method returns.

- (void)dnssdBrowser:(DNSSDBrowser *)browser didAddService:(DNSSDService *)service moreComing:(BOOL)moreComing;
    // Called when the browser finds a new service.

- (void)dnssdBrowser:(DNSSDBrowser *)browser didRemoveService:(DNSSDService *)service moreComing:(BOOL)moreComing;
    // Called when the browser sees an existing service go away.

@end
