//
//  PVWebServer.m
//  Provenance
//
//  Created by Daniel Gillespie on 7/25/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVWebServer.h"

@interface PVWebServer ()

@property (nonatomic, strong) GCDWebUploader *webServer;
@property (nonatomic, strong) NSUserActivity *handoffActivity;

@end

@implementation PVWebServer

+ (PVWebServer *)sharedInstance
{
    static PVWebServer *_sharedInstance;
    
    if (!_sharedInstance)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _sharedInstance = [[super allocWithZone:nil] init];
        });
    }
    
    return _sharedInstance;
}

- (id)init
{
    if ((self = [super init]))
    {
        self.webServer = [[GCDWebUploader alloc] initWithUploadDirectory: [self getDocumentDirectory]];
        self.webServer.delegate = self;
        self.webServer.allowHiddenItems = NO;
    }
    
    return self;
}

- (NSString*)getDocumentDirectory
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentPath = [paths objectAtIndex: 0];
    
    return documentPath;
}

- (NSUserActivity *)handoffActivity
{
    if (!_handoffActivity) {
        _handoffActivity = [[NSUserActivity alloc] initWithActivityType:@"com.app.browser"];
        _handoffActivity.webpageURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", [self getIPAddress]]];
    }
    
    return _handoffActivity;
}

- (void)startServer
{
    [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
    [self.webServer start];
    [self.handoffActivity becomeCurrent];
}

- (void)stopServer
{
    [[UIApplication sharedApplication] setIdleTimerDisabled: NO];
    [self.webServer stop];
    [self.handoffActivity resignCurrent];
}

- (NSString *)getIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL)
        {
            if (temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                NSString *interfaceName = [NSString stringWithUTF8String:temp_addr->ifa_name];
                NSLog(@"Interface name: %@", interfaceName);
                if ([interfaceName isEqualToString:@"en0"] || [interfaceName isEqualToString:@"en1"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    return address;
}

- (NSURL *)bonjourServerURL
{
    return self.webServer.bonjourServerURL;
}

#pragma mark - Web Server Delegate

- (void)webUploader:(GCDWebUploader*)uploader didUploadFileAtPath:(NSString*)path
{
    NSLog(@"[UPLOAD] %@", path);
}

- (void)webUploader:(GCDWebUploader*)uploader didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath
{
    NSLog(@"[MOVE] %@ -> %@", fromPath, toPath);
}

- (void)webUploader:(GCDWebUploader*)uploader didDeleteItemAtPath:(NSString*)path
{
    NSLog(@"[DELETE] %@", path);
}

- (void)webUploader:(GCDWebUploader*)uploader didCreateDirectoryAtPath:(NSString*)path
{
    NSLog(@"[CREATE] %@", path);
}

@end
