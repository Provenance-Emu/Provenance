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

// Define notification constants
NSString* const PVWebServerFileUploadStartedNotification = @"PVWebServerFileUploadStartedNotification";
NSString* const PVWebServerFileUploadProgressNotification = @"PVWebServerFileUploadProgressNotification";
NSString* const PVWebServerFileUploadCompletedNotification = @"PVWebServerFileUploadCompletedNotification";
NSString* const PVWebServerFileUploadFailedNotification = @"PVWebServerFileUploadFailedNotification";

// Status message notification names
NSString* const PVWebServerUploadProgressNotification = @"WebServerUploadProgress";
NSString* const PVWebServerUploadCompletedNotification = @"WebServerUploadCompleted";
NSString* const PVWebServerStatusChangedNotification = @"WebServerStatusChanged";

// Web Server
#import "GCDWebUploader.h"
#import "GCDWebDAVServer.h"
#import "GCDWebServerMultiPartFormRequest.h"

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

@property (nonatomic, strong) NSMutableArray *uploadQueue;
@property (nonatomic, strong) NSString *currentUploadingFilePath;
@property (nonatomic, assign) float currentUploadProgress;
@property (nonatomic, assign) uint64_t currentUploadFileSize;
@property (nonatomic, assign) uint64_t currentUploadBytesTransferred;
@property (nonatomic, strong) NSTimer *uploadProgressTimer;

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

- (instancetype)init
{
    if ((self = [super init]))
    {
        // Initialize upload tracking properties
        _uploadQueue = [NSMutableArray array];
        _currentUploadProgress = 0.0f;
        _currentUploadFileSize = 0;
        _currentUploadBytesTransferred = 0;
#if TARGET_OS_TV
        NSString* importsFolder = self.documentsDirectory;
#else
        NSString* importsFolder = /*self.appGroupDocumentsDirectory ?:*/ self.documentsDirectory;
#endif
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

- (GCDWebUploader *)webServer
{
    if (!_webServer)
    {
        NSString *documentsPath = self.documentsDirectory;
        _webServer = [[GCDWebUploader alloc] initWithUploadDirectory:documentsPath];
        _webServer.delegate = self;
        _webServer.allowedFileExtensions = nil;
        _webServer.title = @"Provenance";
        _webServer.prologue = @"<p>Upload ROM files for your games here.</p><p>Supported systems: NES, SNES, Genesis, GameBoy, GameBoy Color, GameBoy Advance, Atari 2600, Atari 5200, Atari 7800, Atari Lynx, Atari Jaguar, Famicom Disk System, Sega Master System, Sega CD, Sega 32X, Sega Game Gear, PlayStation, Neo Geo Pocket, Neo Geo Pocket Color, PC Engine/TurboGrafx-16, PC Engine-CD/TurboGrafx-CD, SuperGrafx, PCESG-16, WonderSwan, WonderSwan Color, Virtual Boy, Pokémon mini, Sega SG-1000, ColecoVision, Intellivision, Odyssey²/Videopac, PC-FX, Supervision</p>";
        _webServer.epilogue = @"<p>Check out <a href=\"https://github.com/Provenance-Emu/Provenance\">Provenance on GitHub</a></p>";
        _webServer.footer = @"<p>Provenance WebUploader</p>";
        
        // Add custom handlers to track upload progress
        [self setupUploadProgressTracking];
        
        // Create user activity for handoff
        self.handoffActivity = [[NSUserActivity alloc] initWithActivityType:@"org.provenance-emu.webserver"];
        self.handoffActivity.title = @"Provenance Web Server";
        self.handoffActivity.webpageURL = self.URL;
        self.handoffActivity.eligibleForHandoff = YES;
    }
    
    return _webServer;
}

- (void)setupUploadProgressTracking
{
    // Add custom handlers to track upload progress
    __weak typeof(self) weakSelf = self;
    
    // Add a handler to track when uploads begin using the proper GCDWebServer API
    [_webServer addHandlerForMethod:@"POST" 
                              path:@"/upload" 
                      requestClass:[GCDWebServerMultiPartFormRequest class] 
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        // Cast to multipart form request
        GCDWebServerMultiPartFormRequest *multipartRequest = (GCDWebServerMultiPartFormRequest *)request;
        
        // Extract the file information
        GCDWebServerMultiPartFile *file = [multipartRequest firstFileForControlName:@"files[]"];
        if (file) {
            NSString *filename = file.fileName;
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && filename) {
                [strongSelf addFileToUploadQueue:filename];
                
                // Post notification that upload has started
                NSDictionary *userInfo = @{
                    @"path": filename
                };
                
                [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerFileUploadStartedNotification 
                                                                    object:strongSelf 
                                                                  userInfo:userInfo];
            }
        }
        
        // Let the normal upload handler process the request
        // We're just intercepting it to track progress
        return nil;
    }];
    
    // Track upload progress by implementing the GCDWebUploaderDelegate methods
    // This is done in the webUploader:didUploadFileAtPath: method
    
    // We'll also periodically check the progress of active uploads
    // Create a timer to track upload progress
    NSTimer *progressTimer = [NSTimer timerWithTimeInterval:0.5 
                                                   target:self 
                                                 selector:@selector(updateUploadProgress:) 
                                                 userInfo:nil 
                                                  repeats:YES];
    
    // Add the timer to the main run loop
    [[NSRunLoop mainRunLoop] addTimer:progressTimer forMode:NSRunLoopCommonModes];
}

- (void)updateUploadProgress:(uint64_t)bytesTransferred totalBytes:(uint64_t)totalBytes {
    if (totalBytes > 0) {
        self.currentUploadProgress = (float)bytesTransferred / (float)totalBytes;
    } else {
        self.currentUploadProgress = 0.0;
    }
    
    self.currentUploadBytesTransferred = bytesTransferred;
    
    // Post notification about progress
    NSDictionary *userInfo = @{
        @"filePath": self.currentUploadingFilePath ?: @"",
        @"bytesTransferred": @(bytesTransferred),
        @"totalBytes": @(totalBytes),
        @"progress": @(self.currentUploadProgress)
    };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerFileUploadProgressNotification
                                                        object:self
                                                      userInfo:userInfo];
    
    // Also post a notification for the status message view
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerUploadProgressNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"currentFile": self.currentUploadingFilePath ?: @"",
                                                          @"bytesTransferred": @(bytesTransferred),
                                                          @"totalBytes": @(totalBytes),
                                                          @"progress": @(self.currentUploadProgress),
                                                          @"queueLength": @(self.uploadQueue.count)
                                                      }];
}

- (void)addFileToUploadQueue:(NSString *)filePath {
    if (!self.uploadQueue) {
        self.uploadQueue = [NSMutableArray array];
    }
    
    [self.uploadQueue addObject:filePath];
    
    // Post notification that a file has been added to the queue
    NSDictionary *userInfo = @{
        @"currentFile": filePath,
        @"queueLength": @(self.uploadQueue.count)
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerFileUploadStartedNotification
                                                        object:self
                                                      userInfo:userInfo];
    
    // Also post a notification for the status message view
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerUploadProgressNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"currentFile": filePath,
                                                          @"bytesTransferred": @(0),
                                                          @"totalBytes": @(0),
                                                          @"progress": @(0.0),
                                                          @"queueLength": @(self.uploadQueue.count)
                                                      }];
    
    // If this is the only file in the queue, start processing it
    if (self.uploadQueue.count == 1) {
        [self processNextFileInUploadQueue];
    }
}

- (void)processNextFileInUploadQueue {
    if (self.uploadQueue.count == 0) {
        self.currentUploadingFilePath = nil;
        self.currentUploadProgress = 0.0;
        self.currentUploadFileSize = 0;
        self.currentUploadBytesTransferred = 0;
        
        // Stop the progress timer if it's running
        if (self.uploadProgressTimer) {
            [self.uploadProgressTimer invalidate];
            self.uploadProgressTimer = nil;
        }
        return;
    }
    
    // Get the next file path from the queue
    NSString *filePath = [self.uploadQueue firstObject];
    self.currentUploadingFilePath = filePath;
    
    // Reset progress tracking
    self.currentUploadProgress = 0.0;
    self.currentUploadFileSize = 0;
    self.currentUploadBytesTransferred = 0;
    
    // Get file attributes to determine size
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
    if (!error) {
        self.currentUploadFileSize = [attributes fileSize];
    }
    
    // Post notification that processing has started for this file
    NSDictionary *userInfo = @{
        @"filePath": filePath,
        @"fileSize": @(self.currentUploadFileSize)
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerFileUploadStartedNotification
                                                        object:self
                                                      userInfo:userInfo];
    
    // Also post a notification for the status message view
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerUploadProgressNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"currentFile": filePath,
                                                          @"bytesTransferred": @(0),
                                                          @"totalBytes": @(self.currentUploadFileSize),
                                                          @"progress": @(0.0),
                                                          @"queueLength": @(self.uploadQueue.count)
                                                      }];
    
    // Start a timer to update progress regularly
    if (!self.uploadProgressTimer) {
        self.uploadProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                   target:self
                                                                 selector:@selector(updateUploadProgressNotification)
                                                                 userInfo:nil
                                                                  repeats:YES];
    }
}

- (void)updateUploadProgressNotification {
    // Only post updates if there's an active upload
    if (self.currentUploadingFilePath) {
        [self updateUploadProgress:self.currentUploadBytesTransferred totalBytes:self.currentUploadFileSize];
        
        // If we've completed the upload but haven't processed it yet, trigger completion
        if (self.currentUploadBytesTransferred >= self.currentUploadFileSize && self.currentUploadFileSize > 0) {
            [self fileUploadCompleted:self.currentUploadingFilePath];
        }
    }
}

- (BOOL)startServers {
    BOOL success;
    
    success = [self startWWWUploadServer];
    if (!success) {
        ELOG(@"Failed to start WWW server on %@", self.IPAddress);
        return NO;
    }
    
    success = [self startWebDavServer];
    if (!success) {
        ELOG(@"Failed to start webdav server on %@", self.IPAddress);
        [self stopWWWUploadServer];
        return NO;
    }

#if !TARGET_OS_OSX
    [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
#endif
    [self.handoffActivity becomeCurrent];
    
    ILOG(@"Started servers on %@", self.IPAddress);
    
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
        ELOG(@"Failed to start Web Server on %@, with error: %@", self.IPAddress, error.localizedDescription);
    }
    
    // Post notification for status message view
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerStatusChangedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"isRunning": @(YES),
                                                          @"type": @"WebUploader",
                                                          @"port": @(webUploadPort),
                                                          @"url": self.URL.absoluteString
                                                      }];
    
    ILOG(@"Started web server at %@", self.URL);
    return success;
}

-(BOOL)startWebDavServer {
    if (_webDavServer.isRunning) {
        NSLog(@"WebDAV Server is already running on %@", self.IPAddress);
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

    // Post notification for status message view
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerStatusChangedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"isRunning": @(YES),
                                                          @"type": @"WebDAV",
                                                          @"port": @(webDavPort),
                                                          @"url": self.WebDavURLString
                                                      }];

    return success;
}

- (void)stopServers
{
#if !TARGET_OS_OSX
    [[UIApplication sharedApplication] setIdleTimerDisabled: NO];
#endif
    [self stopWWWUploadServer];
    [self stopWebDavServer];
    
    // Stop the upload progress timer if it's running
    if (self.uploadProgressTimer) {
        [self.uploadProgressTimer invalidate];
        self.uploadProgressTimer = nil;
    }
    
    [self.handoffActivity resignCurrent];
}

-(void)stopWWWUploadServer {
    if (_webServer.isRunning) {
        [_webServer stop];
        
        // Post notification for status message view
        [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerStatusChangedNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"isRunning": @(NO),
                                                              @"type": @"WebUploader",
                                                              @"port": @(webUploadPort)
                                                          }];
    }
}

-(void)stopWebDavServer {
    if (_webDavServer.isRunning) {
        [_webDavServer stop];
        
        // Post notification for status message view
        [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerStatusChangedNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"isRunning": @(NO),
                                                              @"type": @"WebDAV",
                                                              @"port": @(webDavPort)
                                                          }];
    }
}

- (void)dealloc {
    [self stopServers];
    
    if (self.uploadProgressTimer) {
        [self.uploadProgressTimer invalidate];
        self.uploadProgressTimer = nil;
    }
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
    ILOG(@"[UPLOAD] %@", path);
    
    // Get file size for the completed file
    uint64_t fileSize = 0;
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (!error) {
        fileSize = [attributes fileSize];
    }
    
    // Post notification that file upload completed
    NSDictionary *userInfo = @{
        @"filePath": path,
        @"fileSize": @(fileSize)
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerFileUploadCompletedNotification
                                                        object:self
                                                      userInfo:userInfo];
    
    // Also post a notification for the status message view
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerUploadCompletedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"fileName": path,
                                                          @"fileSize": @(fileSize)
                                                      }];
    
    // Remove the file from the queue
    if ([path isEqualToString:self.currentUploadingFilePath]) {
        // If this is the current file being processed, move to the next one
        if (self.uploadQueue.count > 0) {
            [self.uploadQueue removeObjectAtIndex:0];
        }
        
        // Process the next file in the queue
        [self processNextFileInUploadQueue];
    } else {
        // If it's not the current file, just remove it from the queue
        [self.uploadQueue removeObject:path];
    }
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
    ILOG(@"[DAV UPLOAD] %@", path);
    
    // Get file size for the completed file
    uint64_t fileSize = 0;
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (!error) {
        fileSize = [attributes fileSize];
    }
    
    // Post notification that file upload completed
    NSDictionary *userInfo = @{
        @"filePath": path,
        @"fileSize": @(fileSize)
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerFileUploadCompletedNotification
                                                        object:self
                                                      userInfo:userInfo];
    
    // Also post a notification for the status message view
    [[NSNotificationCenter defaultCenter] postNotificationName:PVWebServerUploadCompletedNotification
                                                        object:self
                                                      userInfo:@{
                                                          @"fileName": path,
                                                          @"fileSize": @(fileSize)
                                                      }];
    
    // Remove the file from the queue
    if ([path isEqualToString:self.currentUploadingFilePath]) {
        // If this is the current file being processed, move to the next one
        if (self.uploadQueue.count > 0) {
            [self.uploadQueue removeObjectAtIndex:0];
        }
        
        // Process the next file in the queue
        [self processNextFileInUploadQueue];
    } else {
        // If it's not the current file, just remove it from the queue
        [self.uploadQueue removeObject:path];
    }
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
