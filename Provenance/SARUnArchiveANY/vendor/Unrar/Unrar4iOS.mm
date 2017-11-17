//
//  Unrar4iOS.mm
//  Unrar4iOS
//
//  Created by Rogerio Pereira Araujo on 10/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Unrar4iOS.h"
#import "RARExtractException.h"

@interface Unrar4iOS(PrivateMethods)
-(BOOL)_unrarOpenFile:(NSString*)rarFile inMode:(NSInteger)mode;
-(BOOL)_unrarOpenFile:(NSString*)rarFile inMode:(NSInteger)mode withPassword:(NSString*)password;
-(BOOL)_unrarCloseFile;
@end

@implementation Unrar4iOS

@synthesize filename, password;

int CALLBACK CallbackProc(UINT msg, long UserData, long P1, long P2) {
	UInt8 **buffer;
	
	switch(msg) {
			
		case UCM_CHANGEVOLUME:
			break;
		case UCM_PROCESSDATA:
			buffer = (UInt8 **) UserData;
			memcpy(*buffer, (UInt8 *)P1, P2);
			// advance the buffer ptr, original m_buffer ptr is untouched
			*buffer += P2;
			break;
		case UCM_NEEDPASSWORD:
			break;
	}
	return(0);
}

-(BOOL) unrarOpenFile:(NSString*)rarFile {
    
	return [self unrarOpenFile:rarFile withPassword:nil];
}

-(BOOL) unrarOpenFile:(NSString*)rarFile withPassword:(NSString *)aPassword {
    
	self.filename = rarFile;
    self.password = aPassword;
	return YES;
}

-(BOOL) _unrarOpenFile:(NSString*)rarFile inMode:(NSInteger)mode{
	
    return [self _unrarOpenFile:rarFile inMode:mode withPassword:nil];
}

- (BOOL)_unrarOpenFile:(NSString *)rarFile inMode:(NSInteger)mode withPassword:(NSString *)aPassword {
    
	header = new RARHeaderDataEx;
    bzero(header, sizeof(RARHeaderDataEx));
	flags = new RAROpenArchiveDataEx;
    bzero(flags, sizeof(RAROpenArchiveDataEx));
	
	const char *filenameData = (const char *) [rarFile UTF8String];
	flags->ArcName = new char[strlen(filenameData) + 1];
	strcpy(flags->ArcName, filenameData);
	flags->OpenMode = mode;
	
	_rarFile = RAROpenArchiveEx(flags);
	if (_rarFile == 0 || flags->OpenResult != 0) {
        [self _unrarCloseFile];
		return NO;
    }
	
    if(aPassword != nil) {
        char *_password = (char *) [aPassword UTF8String];
        RARSetPassword(_rarFile, _password);
    }
    
	return YES;
}

-(NSArray *) unrarListFiles {
	int RHCode = 0, PFCode = 0;

	if ([self _unrarOpenFile:filename inMode:RAR_OM_LIST_INCSPLIT withPassword:password] == NO)
        return nil;
	
	NSMutableArray *files = [NSMutableArray array];
	while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
		NSString *_filename = [NSString stringWithCString:header->FileName encoding:NSASCIIStringEncoding];
		[files addObject:_filename];
		
		if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
			[self _unrarCloseFile];
			return nil;
		}
	}

	[self _unrarCloseFile];
	return files;
}

-(BOOL) unrarFileTo:(NSString*)path overWrite:(BOOL)overwrite {
    int RHCode = 0, PFCode = 0;
    
    if ([self _unrarOpenFile:filename inMode:RAR_OM_EXTRACT] == NO)
        return NO;
    
	while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
        
        if ((PFCode = RARProcessFile(_rarFile, RAR_EXTRACT, (char *)[path UTF8String], NULL)) != 0) {
            [self _unrarCloseFile];
            return NO;
        }
        
    }
    
    [self _unrarCloseFile];
    return YES;
}

-(NSData *) extractStream:(NSString *)aFile {
	int RHCode = 0, PFCode = 0;
	
	if ([self _unrarOpenFile:filename inMode:RAR_OM_EXTRACT withPassword:password] == NO)
        return nil;
	
	size_t length = 0;
	while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0) {
		NSString *_filename = [NSString stringWithCString:header->FileName encoding:NSASCIIStringEncoding];
				
		if ([_filename isEqualToString:aFile]) {
			length = header->UnpSize;
			break;
		} 
		else {
			if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
				[self _unrarCloseFile];
				return nil;
			}
		}
	}
	
	if (length == 0) { // archived file not found
		[self _unrarCloseFile];
		return nil;
	}
	
	UInt8 *buffer = (UInt8 *)malloc(length * sizeof(UInt8));
	UInt8 *callBackBuffer = buffer;
	
	RARSetCallback(_rarFile, CallbackProc, (long) &callBackBuffer);
	
	PFCode = RARProcessFile(_rarFile, RAR_TEST, NULL, NULL);

    [self _unrarCloseFile];
    if(PFCode == ERAR_MISSING_PASSWORD) {
        RARExtractException *exception = [RARExtractException exceptionWithStatus:RARArchiveProtected];
        @throw exception;           
        return nil;
    }
    if(PFCode == ERAR_BAD_ARCHIVE) {
        RARExtractException *exception = [RARExtractException exceptionWithStatus:RARArchiveInvalid];
        @throw exception;           
        return nil;
    }
    if(PFCode == ERAR_UNKNOWN_FORMAT) {
        RARExtractException *exception = [RARExtractException exceptionWithStatus:RARArchiveBadFormat];
        @throw exception;           
        return nil;
    }
    
    return [NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES];
}

-(BOOL) _unrarCloseFile {
	if (_rarFile)
		RARCloseArchive(_rarFile);
    _rarFile = 0;
    
    if (flags)
        delete flags->ArcName;
	delete flags, flags = 0;
    delete header, header = 0;
	return YES;
}

-(BOOL) unrarCloseFile {
	return YES;
}

@end
