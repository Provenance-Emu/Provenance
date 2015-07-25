//
//  ServerConnection.m
//  Provenance
//
//  Created by Daniel Gillespie on 7/23/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "ServerConnection.h"

#import "HTTPMessage.h"
#import "HTTPDataResponse.h"
#import "DDNumber.h"
#import "HTTPLogging.h"

#import "MultipartFormDataParser.h"
#import "MultipartMessageHeaderField.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPFileResponse.h"

// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE; // | HTTP_LOG_FLAG_TRACE;


/**
 * All we have to do is override appropriate methods in HTTPConnection.
 **/

@implementation ServerConnection

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    HTTPLogTrace();
    
    // Add support for POST
    
    if ([method isEqualToString: @"POST"])
    {
        if ([path isEqualToString: @"/upload"])
        {
            return YES;
        }
    }
    
    return [super supportsMethod: method atPath: path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
    HTTPLogTrace();
    
    
    return [super expectsRequestBodyFromMethod:method atPath: path];
}

-(NSString*) getDocumentsDirectory {
    // get documents directory
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [searchPaths objectAtIndex:0];
    
    return documentPath;
}

-(NSArray*) listAllFilesInPath:(NSString*)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL: url
                                          includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        errorHandler: nil];
    
    NSMutableArray *mutableFileURLs = [NSMutableArray array];
    for (NSURL *fileURL in enumerator) {
        NSString *filename;
        [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];
        
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        
        // Skip directories with '_' prefix, for example
        if ([filename hasPrefix:@"_"] && [isDirectory boolValue]) {
            [enumerator skipDescendants];
            continue;
        }
        
        if (![isDirectory boolValue]) {
            //[mutableFileURLs addObject:fileURL];
            [mutableFileURLs addObject: [fileURL absoluteString]];
        }
    }
    
    
    return [NSArray arrayWithArray: mutableFileURLs];
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    HTTPLogTrace();
    
    if( [method isEqualToString: @"GET"] && [path hasPrefix: @"/GetSaveList"]) {
        // get all the game saves and return it to the requesting JS AJAX call
        
        NSString *savePath = [[self getDocumentsDirectory] stringByAppendingString: @"/Battery States"];
        NSLog(@"Save Path: %@", savePath);
    
        NSArray *fileList = [self listAllFilesInPath: savePath];
        
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject: fileList options: NSJSONWritingPrettyPrinted error: nil];
        NSString *json = [[NSString alloc] initWithData: jsonData encoding:NSUTF8StringEncoding];
        
        return [[HTTPDataResponse alloc] initWithData: [json dataUsingEncoding: NSUTF8StringEncoding]];
    
    } else if([method isEqualToString: @"GET"] && [path hasPrefix: @"/download/save/"]) {
        
        NSString *itemPath = [[path substringFromIndex: 15] stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
        NSString *newPath = [itemPath substringFromIndex: 7];
        NSData *data = nil;
        
        if([[NSFileManager defaultManager] fileExistsAtPath: newPath])
        {
            data = [[NSFileManager defaultManager] contentsAtPath: newPath];
        } else {
            NSLog(@"File not exits");
        }
        
        return [[HTTPDataResponse alloc] initWithData: data];
    }

              
    return [super httpResponseForMethod:method URI:path];
}

- (void)prepareForBodyWithSize:(UInt64)contentLength
{
    HTTPLogTrace();
    
    // set up mime parser
    NSString* boundary = [request headerField:@"boundary"];
    parser = [[MultipartFormDataParser alloc] initWithBoundary:boundary formEncoding:NSUTF8StringEncoding];
    parser.delegate = self;
    
    uploadedFiles = [[NSMutableArray alloc] init];
}

- (void)processBodyData:(NSData *)postDataChunk
{
    HTTPLogTrace();
    // append data to the parser. It will invoke callbacks to let us handle
    // parsed data.
    [parser appendData: postDataChunk];
}


//-----------------------------------------------------------------
#pragma mark multipart form data parser delegate


- (void) processStartOfPartWithHeader:(MultipartMessageHeader*) header {
    // in this sample, we are not interested in parts, other then file parts.
    // check content disposition to find out filename
    
    MultipartMessageHeaderField* disposition = [header.fields objectForKey:@"Content-Disposition"];
    NSString* filename = [[disposition.params objectForKey:@"filename"] lastPathComponent];
    
    if ( (nil == filename) || [filename isEqualToString: @""] ) {
        // it's either not a file part, or
        // an empty form sent. we won't handle it.
        return;
    }
    NSString* uploadDirPath = [[config documentRoot] stringByAppendingPathComponent:@"upload"];
    
    BOOL isDir = YES;
    if (![[NSFileManager defaultManager]fileExistsAtPath:uploadDirPath isDirectory:&isDir ]) {
        [[NSFileManager defaultManager]createDirectoryAtPath:uploadDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString* filePath = [uploadDirPath stringByAppendingPathComponent: filename];
    if( [[NSFileManager defaultManager] fileExistsAtPath:filePath] ) {
        storeFile = nil;
    }
    else {
        HTTPLogVerbose(@"Saving file to %@", filePath);
        if(![[NSFileManager defaultManager] createDirectoryAtPath:uploadDirPath withIntermediateDirectories:true attributes:nil error:nil]) {
            HTTPLogError(@"Could not create directory at path: %@", filePath);
        }
        if(![[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil]) {
            HTTPLogError(@"Could not create file at path: %@", filePath);
        }
        storeFile = [NSFileHandle fileHandleForWritingAtPath:filePath];
        [uploadedFiles addObject: [NSString stringWithFormat:@"/upload/%@", filename]];
    }
}


- (void) processContent:(NSData*) data WithHeader:(MultipartMessageHeader*) header
{
    // here we just write the output from parser to the file.
    if( storeFile ) {
        [storeFile writeData:data];
    }
}

- (void) processEndOfPartWithHeader:(MultipartMessageHeader*) header
{
    // as the file part is over, we close the file.
    [storeFile closeFile];
    storeFile = nil;
}

- (void) processPreambleData:(NSData*) data 
{
    // if we are interested in preamble data, we could process it here.
    
}

- (void) processEpilogueData:(NSData*) data 
{
    // if we are interested in epilogue data, we could process it here.
    
}

@end
