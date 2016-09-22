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
@property (nonatomic, readwrite, copy) PVExtractionStartedHandler extractionStartedHandler;
@property (nonatomic, readwrite, copy) PVExtractionUpdatedHandler extractionUpdatedHandler;
@property (nonatomic, readwrite, copy) PVExtractionCompleteHandler extractionCompleteHandler;
@property (nonatomic, strong) dispatch_source_t dispatch_source;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSArray *previousContents;


@end

@implementation PVDirectoryWatcher

- (id)initWithPath:(NSString *)path extractionStartedHandler:(PVExtractionStartedHandler)startedHandler extractionUpdatedHandler:(PVExtractionUpdatedHandler)updatedHandler extractionCompleteHandler:(PVExtractionCompleteHandler)completeHandler
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
        
        self.extractionStartedHandler = startedHandler;
        self.extractionUpdatedHandler = updatedHandler;
		self.extractionCompleteHandler = completeHandler;
        
        self.serialQueue = dispatch_queue_create("com.jamsoftonline.provenance.serialExtractorQueue", DISPATCH_QUEUE_SERIAL);
        
        dispatch_async(self.serialQueue, ^{
            NSError *error = nil;
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error];
            if (contents)
            {
                for (NSString *file in contents)
                {
                    if ([[file pathExtension] isEqualToString:@"zip"])
                    {
                        [self extractArchiveAtPath:file];
                    }
                }
            }
            else
            {
                DLog(@"Unable to get contents");
            }
        });
	}
	
	return self;
}

- (void)dealloc
{
    self.serialQueue = nil;
    self.extractionStartedHandler = nil;
    self.extractionUpdatedHandler = nil;
    self.extractionCompleteHandler = nil;
}

- (void)startMonitoring
{
	if (![self.path length])
	{
        DLog(@"Empty path");
		return;
	}
	
	[self stopMonitoring];
	
	int dirFileDescriptor = open([self.path fileSystemRepresentation], O_EVTONLY);
	if (dirFileDescriptor < 0)
	{
        DLog(@"Unable open file system ref");
		return;
	}
    
    self.dispatch_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                                  dirFileDescriptor,
                                                  DISPATCH_VNODE_WRITE,
                                                  self.serialQueue);
	if (!self.dispatch_source)
	{
        DLog(@"Failed to cerate dispatch source");
		return;
	}
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_registration_handler(self.dispatch_source, ^{
        dispatch_source_set_event_handler(weakSelf.dispatch_source, ^{
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:weakSelf.path error:NULL];
            NSSet *previousContentsSet = [NSSet setWithArray:self.previousContents];
            NSMutableSet *contentsSet = [NSMutableSet setWithArray:contents];
            [contentsSet minusSet:previousContentsSet];
            for (NSString *file in contentsSet)
            {
                NSString *path = [weakSelf.path stringByAppendingPathComponent:file];
                [weakSelf watchFileAtPath:path];
            }
            self.previousContents = contents;
        });
        dispatch_source_set_cancel_handler(self.dispatch_source, ^{
            close(dirFileDescriptor);
        });
    });
	
    dispatch_resume(self.dispatch_source);
    
    // trigger the event watcher above to start an initial import on launch
    NSString *triggerPath = [self.path stringByAppendingPathComponent:@"0"];
    [@"0" writeToFile:triggerPath
           atomically:NO
             encoding:NSUTF8StringEncoding
                error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:triggerPath error:NULL];
}

- (void)stopMonitoring
{
	if (self.dispatch_source)
	{
		self.extractionCompleteHandler = NULL;
		self.path = nil;
		dispatch_source_cancel(self.dispatch_source);
		self.dispatch_source = NULL;
    }
}

- (void)watchFileAtPath:(NSString *)path
{
//    if ([[path pathExtension] isEqualToString:@"zip"])
//    {
        DLog(@"Start watching %@", [path lastPathComponent]);
        NSError *error = nil;
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
        if (!attributes)
        {
            DLog(@"Error getting file attributes for %@", path);
            return;
        }
        unsigned long long filesize = [attributes fileSize];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSTimer scheduledTimerWithTimeInterval:0.5 target:weakSelf selector:@selector(checkFileProgress:) userInfo:@{@"path": path, @"filesize": @(filesize)} repeats:NO];
        });
//    }
}

- (void)checkFileProgress:(NSTimer *)timer
{
    NSString *path = [timer userInfo][@"path"];
    unsigned long long previousFilesize = [[timer userInfo][@"filesize"] unsignedLongLongValue];
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    unsigned long long currentFilesize = [attributes fileSize];
    if (previousFilesize == currentFilesize)
    {
        if ([[path pathExtension] isEqualToString:@"zip"])
        {
            dispatch_async(self.serialQueue, ^{
                [self extractArchiveAtPath:path];
            });
        }
        else
        {
            if (self.extractionCompleteHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.extractionCompleteHandler(@[[path lastPathComponent]]);
                });
            }
        }
        return;
    }

    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkFileProgress:) userInfo:@{@"path": path, @"filesize": @(currentFilesize)} repeats:NO];
}

- (void)extractArchiveAtPath:(NSString *)filePath
{
    if (self.extractionStartedHandler)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.extractionStartedHandler(filePath);
        });
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        return;
    }
    
    NSMutableArray *unzippedFiles = [NSMutableArray array];
    [SSZipArchive unzipFileAtPath:filePath
                    toDestination:self.path
                        overwrite:YES
                         password:nil
                  progressHandler:^(NSString *entry, unz_file_info zipInfo, long entryNumber, long total, unsigned long long fileSize, unsigned long long bytesRead) {
                      if ([entry length])
                      {
                          [unzippedFiles addObject:entry];
                      }
                      if (self.extractionUpdatedHandler)
                      {
                          dispatch_async(dispatch_get_main_queue(), ^{
                              self.extractionUpdatedHandler(filePath, entryNumber, total, fileSize, bytesRead);
                          });
                      }
                  }
                completionHandler:^(NSString *path, BOOL succeeded, NSError *error) {
                    if (succeeded)
                    {
                        if (self.extractionCompleteHandler)
                        {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                self.extractionCompleteHandler([unzippedFiles copy]);
                            });
                        }
                        
                        NSError *deleteError = nil;
                        BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&deleteError];
                        
                        if (!deleted)
                        {
                            DLog(@"Unable to delete file at path %@, because %@", filePath, [error localizedDescription]);
                        }
                    }
                    else
                    {
                        DLog(@"Unable to unzip file: %@ because: %@", filePath, [error localizedDescription]);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:PVArchiveInflationFailedNotification
                                                                                object:self];
                        });
                    }
                }];
}

@end
