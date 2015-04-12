//
//  PVDirectoryWatcher.m
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

#import "PVDirectoryWatcher.h"
#import "SSZipArchive.h"
#import "PVEmulatorConfiguration.h"
#import "NSDate+NSDate_SignificantDates.h"

NSString *PVArchiveInflationFailedNotification = @"PVArchiveInflationFailedNotification";

@interface PVDirectoryWatcher ()

@property (nonatomic, readwrite, copy) NSString *path;
@property (nonatomic, readwrite, copy) PVDirectoryChangedHandler directoryChangedHandler;
@property (nonatomic, strong) dispatch_source_t dispatch_source;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, assign) BOOL requiresAnotherPass;

@end

@implementation PVDirectoryWatcher

- (id)initWithPath:(NSString *)path directoryChangedHandler:(PVDirectoryChangedHandler)handler
{
	if ((self = [super init]))
	{
        self.path = path;
		
		BOOL isDirectory = NO;
		BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.path
											 isDirectory:&isDirectory];
		if ((fileExists == NO) || (isDirectory == NO))
		{
			NSError *error = nil;
			BOOL succeeded = [[NSFileManager defaultManager] createDirectoryAtPath:self.path
													   withIntermediateDirectories:YES
																		attributes:nil
																			 error:&error];
			if (!succeeded)
			{
				DLog(@"Unable to create directory at: %@, because: %@", self.path, [error localizedDescription]);
			}
		}
		
		self.directoryChangedHandler = handler;
        self.serialQueue = dispatch_queue_create("com.jamsoftonline.provenance.serialExtractorQueue", DISPATCH_QUEUE_SERIAL);
	}
	
	return self;
}

- (void)dealloc
{
    self.serialQueue = nil;
    self.directoryChangedHandler = nil;
}

- (void)startMonitoring
{
	if (![self.path length])
	{
		return;
	}
	
	[self stopMonitoring];
	
	int dirFileDescriptor = open([self.path fileSystemRepresentation], O_EVTONLY);
	if (dirFileDescriptor < 0)
	{
		return;
	}
    
    self.dispatch_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                                  dirFileDescriptor,
                                                  DISPATCH_VNODE_WRITE |
                                                  DISPATCH_VNODE_DELETE |
                                                  DISPATCH_VNODE_RENAME,
                                                  self.serialQueue);
	if (!self.dispatch_source)
	{
		return;
	}
    
    __weak typeof(self) weakSelf = self;
    
	dispatch_source_set_event_handler(self.dispatch_source, ^{
        do
        {
            @autoreleasepool {
                [weakSelf findAndExtractArchives];
            }
        } while (weakSelf.requiresAnotherPass);
	});
	
	dispatch_resume(self.dispatch_source);
}

- (void)stopMonitoring
{
	if (self.dispatch_source)
	{
		self.directoryChangedHandler = NULL;
		self.path = nil;
		dispatch_source_cancel(self.dispatch_source);
		self.dispatch_source = NULL;
    }
}

- (void)findAndExtractArchives
{
    self.requiresAnotherPass = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:self.path error:NULL];
    
    for (NSString *path in contents)
    {
        @autoreleasepool {
            NSString *filePath = [self.path stringByAppendingPathComponent:path];
            BOOL isDir = NO;
            BOOL fileExists = [fileManager fileExistsAtPath:filePath isDirectory:&isDir];
            NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:NULL];
            NSDate *creationDate = [fileAttributes objectForKey:NSFileCreationDate];
            
            if (!fileExists || isDir)
            {
                continue;
            }
            
            if ([creationDate compare:[NSDate macAnnouncementDate]] != NSOrderedDescending)
            {
                self.requiresAnotherPass = YES;
                continue;
            }
            
            if ([SSZipArchive validArchiveAtPath:filePath] == NO)
            {
                continue;
            }
            
            NSError *zipError = nil;
            if ([SSZipArchive unzipFileAtPath:filePath
                            toDestination:self.path
                                overwrite:YES
                                 password:nil
                                    error:&zipError])
            {
                NSError *error = nil;
                BOOL deleted = [fileManager removeItemAtPath:filePath error:&error];
                
                if (!deleted)
                {
                    DLog(@"Unable to delete file at path %@, because %@", filePath, [error localizedDescription]);
                }
            }
            else
            {
                DLog(@"Unable to unzip file: %@ because: %@", filePath, [zipError localizedDescription]);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:PVArchiveInflationFailedNotification
                                                                        object:self];
                });
            }
            
//            ZKDataArchive *archive = [ZKDataArchive archiveWithArchivePath:filePath];
//            NSUInteger status = [archive inflateAll];
//            if (status == zkSucceeded)
//            {
//                for (NSDictionary *inflatedFile in [archive inflatedFiles])
//                {
//                    @autoreleasepool {
//                        NSString *fileName = [inflatedFile objectForKey:ZKPathKey];
//                        NSArray *supportedFileExtensions = [[PVEmulatorConfiguration sharedInstance] supportedFileExtensions];
//                        NSString *fileExtension = [fileName pathExtension];
//                        if ([supportedFileExtensions containsObject:[fileExtension lowercaseString]])
//                        {
//                            NSData *fileData = [inflatedFile objectForKey:ZKFileDataKey];
//                            [fileData writeToFile:[self.path stringByAppendingPathComponent:fileName] atomically:YES];
//                        }
//                    }
//                }
//            
//                NSError *error = nil;
//                BOOL deleted = [fileManager removeItemAtPath:filePath error:&error];
//                
//                if (!deleted)
//                {
//                    DLog(@"Unable to delete file at path %@, because %@", filePath, [error localizedDescription]);
//                }
//            }
//            else
//            {
//                DLog(@"Unable to inflate zip at %@, status: %tu", filePath, status);
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    [[NSNotificationCenter defaultCenter] postNotificationName:PVArchiveInflationFailedNotification
//                                                                        object:self];
//                });
//            }
        }
    }
    
    if (self.directoryChangedHandler)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.directoryChangedHandler();
        });
    }
}

@end
