//
//  SARUnArchiveANY.m
//  SARUnArchiveANY
//
//  Created by Saravanan V on 26/04/13.
//  Copyright (c) 2013 SARAVANAN. All rights reserved.
//

#import "SARUnArchiveANY.h"
#include "Unrar4IOS.h"
#import "SSZipArchive.h"
#import "LZMAExtractor.h"

@implementation SARUnArchiveANY
@synthesize completionBlock;
@synthesize failureBlock;


#pragma mark - Init Methods
- (id)initWithPath:(NSString *)path {
	if ((self = [super init])) {
		_filePath = [path copy];
        _fileType = [[NSString alloc]init];
	}

    if (_filePath != nil) {
        _destinationPath = [self getDestinationPath];
    }
	return self;
}

- (id)initWithPath:(NSString *)path andPassword:(NSString*)password{
    if ((self = [super init])) {
        _filePath = [path copy];
        _password = [password copy];
        _fileType = [[NSString alloc]init];
    }
    
    if (_filePath != nil) {
        _destinationPath = [self getDestinationPath];
    }
    return self;
}

#pragma mark - Helper Methods
- (NSString *)getDestinationPath{
    NSArray *derivedPathArr = [_filePath componentsSeparatedByString:@"/"];
    NSString *lastObject = [derivedPathArr lastObject];
    _fileType = [[lastObject componentsSeparatedByString:@"."] lastObject];
    return [_filePath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"/%@",lastObject] withString:@""];
}


#pragma mark - Decompressing Methods
- (void)decompress{
    //    NSLog(@"_fileType : %@",_fileType);
    if ( [_fileType compare:rar options:NSCaseInsensitiveSearch] == NSOrderedSame ) {
        [self rarDecompress];
    }
    else if ( [_fileType compare:zip options:NSCaseInsensitiveSearch] == NSOrderedSame ) {
        [self zipDecompress];
    }
    else if ( [_fileType compare:@"7z" options:NSCaseInsensitiveSearch] == NSOrderedSame ) {
        [self decompress7z];
    }
}

- (void)rarDecompress {
    NSString *tmpDirname = @"Extract rar";
    _destinationPath = [_destinationPath stringByAppendingPathComponent:tmpDirname];
//    _filePath = [[NSBundle mainBundle] pathForResource:@"example" ofType:@"rar"];
//    NSLog(@"filePath : %@",_filePath);
	Unrar4iOS *unrar = [[Unrar4iOS alloc] init];

    BOOL ok;
    if (self.password != nil && self.password.length > 0) {
        @try {
            ok = [unrar unrarOpenFile:_filePath withPassword:self.password];
        }
        @catch(NSException *exception) {
            NSLog(@"exception: %@", exception);
        }
    }
    else{
        ok = [unrar unrarOpenFile:_filePath];
    }

	if (ok) {
		NSArray *files = [unrar unrarListFiles];
        NSMutableArray *filePathsArray = [NSMutableArray array];
		for (NSString *filePath in files){
            [filePathsArray addObject:[_destinationPath stringByAppendingPathComponent:filePath]];
        }

//        NSLog(@"_destinationPath : %@",_destinationPath);
        BOOL extracted = [unrar unrarFileTo:_destinationPath overWrite:YES];
//        NSLog(@"extracted : %d",extracted);

//        [self moveFilesToDestinationPathFromCompletePaths:filePathsArray withFilePaths:files];
        if ( extracted ) {
            if (completionBlock != nil) {
                completionBlock(filePathsArray);
            }
            else{
                if (failureBlock != nil) {
                    failureBlock();
                }
            }
        }
        [unrar unrarCloseFile];
	}
	else{
        if (failureBlock != nil) {
            failureBlock();
        }
		[unrar unrarCloseFile];
    }
    
}

- (void)zipDecompress{
    NSString *tmpDirname = @"Extract zip";
    _destinationPath = [_destinationPath stringByAppendingPathComponent:tmpDirname];
    BOOL unzipped = [SSZipArchive unzipFileAtPath:_filePath toDestination:_destinationPath delegate:self];
//    NSLog(@"unzipped : %d",unzipped);
    NSError *error;
    if (self.password != nil && self.password.length > 0) {
        unzipped = [SSZipArchive unzipFileAtPath:_filePath toDestination:_destinationPath overwrite:NO password:self.password error:&error delegate:self];
        NSLog(@"error: %@", error);
    }
    
    if ( !unzipped ) {
        failureBlock();
    }
}

- (void)decompress7z{
    NSString *tmpDirname = @"Extract 7z";    
    _destinationPath = [_destinationPath stringByAppendingPathComponent:tmpDirname];
    
    NSArray *contents = [LZMAExtractor extract7zArchive:_filePath dirName:_destinationPath preserveDir:YES];
    
//    UnComment below lines to see the path of each file extracted    
//    for (NSString *entryPath in contents) {
//        NSLog(@"entryPath : %@", entryPath);
//    }
    
    if (![contents count]) {
        failureBlock();
    }
    else{
        completionBlock(contents);
    }
}

#pragma mark - SSZipArchive Delegates
- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath WithFilePaths:(NSMutableArray *)filePaths{
    //    NSLog(@"path : %@",path);
    //    NSLog(@"unzippedPath : %@",unzippedPath);
    completionBlock(filePaths);
}


#pragma mark - Utility Methods
- (NSString *) applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}





#pragma mark - Not using these methods now
//Writing this for Unrar4iOS, since it just unrar's(decompresses) the files into the compressed(rar) file's folder path
- (void)moveFilesToDestinationPathFromCompletePaths:(NSArray *)completeFilePathsArray withFilePaths:(NSArray *)filePathsArray{
    if ( _destinationPath == [self getDestinationPath] ) {
        return;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    for ( NSString *filePath in completeFilePathsArray ){
        int index = [completeFilePathsArray indexOfObject:filePath];
        NSString *fileDestinationPath = [_destinationPath stringByAppendingPathComponent:[filePathsArray objectAtIndex:index]];
        if([fileManager fileExistsAtPath:fileDestinationPath]){
            [fileManager removeItemAtPath:fileDestinationPath error:&error];
        }
        else{
            NSLog(@"filePath : %@",filePath);
            if(![fileManager moveItemAtPath:filePath
                                     toPath:fileDestinationPath
                                      error:&error])
            {
                //TODO: Handle error
                NSLog(@"Error: %@", error);
            }
        }
    }
    
}

@end
