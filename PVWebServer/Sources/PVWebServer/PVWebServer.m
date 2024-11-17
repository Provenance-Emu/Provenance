//
//  PVWebServer.m
//  Provenance
//
//  Created by Daniel Gillespie on 7/25/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVWebServer.h"
@import PVSupport;
@import PVLoggingObjC;

// Web Server
#import "GCDWebUploader.h"
#import "GCDWebDAVServer.h"

// Set start port based on target type
// Simulator can't open ports below 1024
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_MACCATALYST || TARGET_OS_OSX
NSUInteger webUploadPort = kDefaultPort;
#else
NSUInteger webUploadPort = 80;
#endif

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_MACCATALYST || TARGET_OS_OSX
NSUInteger webDavPort = 8081;
#else
NSUInteger webDavPort = 81;
#endif

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
@dynamic documentsDirectory, IPAddress, URLString, WebDavURLString, URL, appGroupDocumentsDirectory;
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

- (instancetype)init {
    if ((self = [super init])) {
        NSString* importsFolder = self.appGroupDocumentsDirectory ?: self.documentsDirectory;
        self.webServer = [[GCDWebUploader alloc] initWithUploadDirectory:importsFolder ];
        self.webServer.delegate = self;
        self.webServer.allowHiddenItems = NO;
        
        self.webDavServer = [[GCDWebDAVServer alloc] initWithUploadDirectory:importsFolder];
        self.webDavServer.delegate = self;
        self.webDavServer.allowHiddenItems = NO;
    }
    
    return self;
}

- (NSString*) PVAppGroupId {
    return [[NSBundle mainBundle] infoDictionary][@"APP_GROUP_IDENTIFIER"] ?: @"group.org.provenance-emu.provenance";
}

- (NSString*)appGroupDocumentsDirectory {
    static NSString* documentPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        documentPath = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:self.PVAppGroupId] URLByAppendingPathComponent:@"Documents"].path;
    });
    
    return documentPath;
}

- (NSString*)documentsDirectory {
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

- (NSUserActivity *)handoffActivity {
    if (!_handoffActivity) {
//        _handoffActivity = [[NSUserActivity alloc] initWithActivityType:@"org.provenance-emu.webserver"];
        _handoffActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
        _handoffActivity.title = @"Provenance file manager";
        NSURL *url = [NSURL URLWithString:self.URLString];
        _handoffActivity.webpageURL = url;
        _handoffActivity.eligibleForHandoff = YES;
    }
    
    return _handoffActivity;
}

- (BOOL)startServers {
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

#if !TARGET_OS_OSX
    [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
#endif
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
        WLOG(@"Web Server is already running");
        return YES;
    }

    // Settings dictionary
    NSDictionary *webSeverOptions = @{
#if TARGET_OS_IPHONE
                                      GCDWebServerOption_AutomaticallySuspendInBackground : @(NO),
#endif
                                      GCDWebServerOption_ServerName : @"Provenance",
                                      GCDWebServerOption_BonjourName : @"ProvenanceWWW",
                                      GCDWebServerOption_Port : @(webUploadPort)
                                      };
    NSError *error;
    BOOL success = [self.webServer startWithOptions:webSeverOptions
                                              error:&error];
    if (!success) {
        ELOG(@"Failed to start Web Server with error: %@", error.localizedDescription);
    }
    
    return success;
}

-(BOOL)startWebDavServer {
    if (_webDavServer.isRunning) {
        NSLog(@"WebDAV Server is already running");
        return YES;
    }

    NSDictionary *webDavSeverOptions = @{
#if TARGET_OS_IPHONE || TARGET_OS_VISION
                                         GCDWebServerOption_AutomaticallySuspendInBackground : @(NO),
#endif
                                         GCDWebServerOption_ServerName : @"Provenance",
                                         GCDWebServerOption_BonjourName : @"Provenance",
                                         GCDWebServerOption_BonjourType : @"_webdav._tcp",
                                         GCDWebServerOption_Port : @(webDavPort)
                                         };
    NSError *error;
    BOOL success = [self.webDavServer startWithOptions:webDavSeverOptions
                                            error:&error];
    if (!success) {
        NSLog(@"Failed to start WebDAV Server with error: %@", error.localizedDescription);
    }

    return success;
}

- (void)stopServers
{
#if !TARGET_OS_OSX
    [[UIApplication sharedApplication] setIdleTimerDisabled: NO];
#endif
    [self stopWWWUploadServer];
    [self stopWebDavServer];
    
    [self.handoffActivity resignCurrent];
}

-(void)stopWWWUploadServer {
    [self.webServer stop];
}

-(void)stopWebDavServer {
    [self.webDavServer stop];
}

- (NSString *)IPAddress {
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

-(NSString *)URLString {
	NSString *ipAddress = self.bonjourSeverURL.host ?: self.IPAddress;
    
    if(webUploadPort != 80) {
        ipAddress = [ipAddress stringByAppendingFormat:@":%i", webUploadPort];
    }
    
    NSString *ipURLString = [NSString stringWithFormat: @"http://%@/", ipAddress];
    return ipURLString;
}

-(NSString *)WebDavURLString
{
	NSString *ipAddress = self.bonjourSeverURL.host ?: self.IPAddress;

    ipAddress = [ipAddress stringByAppendingFormat:@":%i", webDavPort];

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
    ILOG(@"Bonjour registration completed for URL: %@", server.bonjourServerURL.absoluteString);
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
