//
//  PVWebServer.m
//  Provenance
//
//  Created by Daniel Gillespie on 7/25/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVWebServer.h"

// Web Server
#import "GCDWebUploader.h"
#import "GCDWebDAVServer.h"


@interface PVWebServer ()

@property (nonatomic, strong) GCDWebUploader *webServer;
@property (nonatomic, strong) GCDWebDAVServer *webDavServer;
@property (nonatomic, strong) NSUserActivity *handoffActivity;
@property (nonatomic, strong, readwrite) NSURL *bonjourSeverURL;
@end

@interface PVWebServer () <GCDWebUploaderDelegate>
@end

@interface PVWebServer () <GCDWebDAVServerDelegate>
@end

@implementation PVWebServer
@dynamic documentsDirectory, IPAddress, URLString, WebDavURLString, URL;
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
        self.webServer = [[GCDWebUploader alloc] initWithUploadDirectory: self.documentsDirectory];
        self.webServer.delegate = self;
        self.webServer.allowHiddenItems = NO;
        
        self.webDavServer = [[GCDWebDAVServer alloc] initWithUploadDirectory:self.documentsDirectory];
        self.webDavServer.delegate = self;
        self.webDavServer.allowHiddenItems = NO;
    }
    
    return self;
}

- (NSString*)documentsDirectory
{
    static NSString* documentPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if TARGET_OS_TV
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
        documentPath = [paths objectAtIndex: 0];
    });
    
    return documentPath;
}

- (NSUserActivity *)handoffActivity
{
    if (!_handoffActivity) {
        _handoffActivity = [[NSUserActivity alloc] initWithActivityType:@"com.provenance-emu.webserver"];
        _handoffActivity.title = @"Provenance file manager";
        NSURL *url = [NSURL URLWithString:self.URLString];
        _handoffActivity.webpageURL = url;
    }
    
    return _handoffActivity;
}

- (BOOL)startServers
{
    BOOL success;
    
    success = [self startWWWUploadServer];
    if (!success) {
        return NO;
    }
    
    success = [self startWebDavServer];
    if (!success) {
        [self stopWWWUploadServer];
        return NO;
    }

    [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
    [self.handoffActivity becomeCurrent];
    
    return YES;
}

- (BOOL)isWWWUploadServerRunning {
    return _webServer.isRunning;
}

- (BOOL)isIsWebDavServerRunning {
    return _webDavServer.isRunning;
}

-(BOOL)startWWWUploadServer {
    if (_webServer.isRunning) {
        NSLog(@"Web Server alreading running");
        return YES;
    }
    
    // Set start port based on target type
    // Simulator can't open ports below 1024
#if TARGET_IPHONE_SIMULATOR
    NSUInteger webUploadPort = 8080;
#else
    NSUInteger webUploadPort = 80;
#endif

    // Settings dictionary
    NSDictionary *webSeverOptions = @{
                                      GCDWebServerOption_AutomaticallySuspendInBackground : @(NO),
                                      GCDWebServerOption_ServerName : @"Provenance",
                                      GCDWebServerOption_BonjourName : @"ProvenanceWWW",
                                      GCDWebServerOption_Port : @(webUploadPort)
                                      };
    NSError *error;
    BOOL success = [self.webServer startWithOptions:webSeverOptions
                                              error:&error];
    if (!success) {
        NSLog(@"Failed to start Web Sever with error: %@", error.localizedDescription);
    }
    
    return success;
}

-(BOOL)startWebDavServer {
    if (_webDavServer.isRunning) {
        NSLog(@"WebDav Server alreading running");
        return YES;
    }
    
#if TARGET_IPHONE_SIMULATOR
    NSUInteger webDavPort = 8081;
#else
    NSUInteger webDavPort = 81;
#endif
    
    NSDictionary *webDavSeverOptions = @{
                                         GCDWebServerOption_AutomaticallySuspendInBackground : @(NO),
                                         GCDWebServerOption_ServerName : @"Provenance",
                                         GCDWebServerOption_BonjourName : @"Provenance",
                                         GCDWebServerOption_BonjourType : @"_webdav._tcp",
                                         GCDWebServerOption_Port : @(webDavPort)
                                         };
    NSError *error;
    BOOL success = [self.webDavServer startWithOptions:webDavSeverOptions
                                            error:&error];
    if (!success) {
        NSLog(@"Failed to start WebDav Sever with error: %@", error.localizedDescription);
    }

    return success;
}

- (void)stopServers
{
    [[UIApplication sharedApplication] setIdleTimerDisabled: NO];
    
    [self stopWWWUploadServer];
    [self stopWebDavServer];
    
    if (@available(iOS 9.0, *)) {
        [self.handoffActivity resignCurrent];
    }
}

-(void)stopWWWUploadServer {
    [self.webServer stop];
}

-(void)stopWebDavServer {
    [self.webDavServer stop];
}

- (NSString *)IPAddress
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

-(NSString *)URLString
{
	NSString *ipAddress = self.bonjourSeverURL.host ?: self.IPAddress;
    
#if TARGET_IPHONE_SIMULATOR
    ipAddress = [ipAddress stringByAppendingString:@":8080"];
#endif

    NSString *ipURLString = [NSString stringWithFormat: @"http://%@/", ipAddress];
    return ipURLString;
}

-(NSString *)WebDavURLString
{
	NSString *ipAddress = self.bonjourSeverURL.host ?: self.IPAddress;

#if TARGET_IPHONE_SIMULATOR
    ipAddress = [ipAddress stringByAppendingString:@":8081"];
#else
    ipAddress = [ipAddress stringByAppendingString:@":81"];
#endif
    
    NSString *ipURLString = [NSString stringWithFormat: @"http://%@/", ipAddress];
    return ipURLString;
}

-(NSURL *)URL
{
    NSString *ipURLString = self.URLString;
    NSURL *url = [NSURL URLWithString:ipURLString];
    return url;
}
 
#pragma mark - GCDWebServerDelegate

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

- (void)webServerDidCompleteBonjourRegistration:(GCDWebServer*)server {
    ILOG(@"Bonjor register completed for URL: %@", server.bonjourServerURL.absoluteString);
	self.bonjourSeverURL = server.bonjourServerURL;
}


#pragma mark - GCDWebDAVServerDelegate
/**
 *  This method is called whenever a file has been downloaded.
 */
- (void)davServer:(GCDWebDAVServer*)server didDownloadFileAtPath:(NSString*)path {
    
}

/**
 *  This method is called whenever a file has been uploaded.
 */
- (void)davServer:(GCDWebDAVServer*)server didUploadFileAtPath:(NSString*)path {
    NSLog(@"[DAV UPLOAD] %@", path);
}

/**
 *  This method is called whenever a file or directory has been moved.
 */
- (void)davServer:(GCDWebDAVServer*)server didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
    NSLog(@"[DAV MOVE] %@ -> %@", fromPath, toPath);
}

/**
 *  This method is called whenever a file or directory has been copied.
 */
- (void)davServer:(GCDWebDAVServer*)server didCopyItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
    NSLog(@"[DAV COPY] %@ -> %@", fromPath, toPath);
}

/**
 *  This method is called whenever a file or directory has been deleted.
 */
- (void)davServer:(GCDWebDAVServer*)server didDeleteItemAtPath:(NSString*)path {
    NSLog(@"[DAV DELETE] %@", path);
}

/**
 *  This method is called whenever a directory has been created.
 */
- (void)davServer:(GCDWebDAVServer*)server didCreateDirectoryAtPath:(NSString*)path {
    NSLog(@"[DAV CREATE] %@", path);
}

@end
