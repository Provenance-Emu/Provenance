//
//  ServerConnection.h
//  Provenance
//
//  Created by Daniel Gillespie on 7/23/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "HTTPConnection.h"

@class MultipartFormDataParser;

@interface ServerConnection : HTTPConnection  {
    MultipartFormDataParser*        parser;
    NSFileHandle*					storeFile;
    
    NSMutableArray*					uploadedFiles;
}

@end

