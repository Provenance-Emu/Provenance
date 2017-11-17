//
//  PVDirectoryWatcher.m
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

#import "PVDirectoryWatcher.h"
#import "SARUnArchiveANY.h"
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
                    if ([[file pathExtension] isEqualToString:@"zip"]
                        || [[file pathExtension] isEqualToString:@"rar"]
                        || [[file pathExtension] isEqualToString:@"7z"])
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
        if ([[path pathExtension] isEqualToString:@"zip"]
            || [[path pathExtension] isEqualToString:@"rar"]
            || [[path pathExtension] isEqualToString:@"7z"])
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
        NSLog(@"File not found at path for Archive : %@",filePath);
        return;
    }
    
    SARUnArchiveANY *unarchive = [[SARUnArchiveANY alloc]initWithPath:filePath];
    unarchive.destinationPath = self.path;
    unarchive.completionBlock = ^(NSArray *filePaths){
        
        if (self.extractionCompleteHandler)
        {
            NSMutableArray *movedFiles = [NSMutableArray array];
            NSLog(@"For Archive : %@",filePath);
            for (NSString *filename in filePaths) {
                NSLog(@"File: %@", filename);
            }
            
            NSError *differentError;
            for (NSString *file in filePaths) {\
                NSString *newPath = [self.path stringByAppendingPathComponent:[file lastPathComponent]];
                [[NSFileManager defaultManager] moveItemAtPath:file
                            toPath:newPath
                             error:&differentError];
                if (!differentError) {
                    DLog(@"Unable to move file at path %@, because %@", filePath, [differentError localizedDescription]);
                } else {
                    [movedFiles addObject:newPath];
                }
            }
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.extractionCompleteHandler([movedFiles copy]);
            });
        }
        NSError *deleteError = nil;
        BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&deleteError];
        
        if (!deleted)
        {
            DLog(@"Unable to delete file at path %@, because %@", filePath, [deleteError localizedDescription]);
        }
        
    };
    unarchive.failureBlock = ^(){
        DLog(@"Unable to unzip file: %@", filePath);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:PVArchiveInflationFailedNotification
                                                                object:self];
        });
    };
    [unarchive decompress];
    
}

@end
