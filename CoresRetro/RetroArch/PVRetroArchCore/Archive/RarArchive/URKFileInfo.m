//
//  URKFileInfo.m
//  UnrarKit
//

#import "URKFileInfo.h"
#import "UnrarKitMacros.h"

#include <wchar.h>

@implementation URKFileInfo

#pragma mark - Initialization

-(NSString *) stringWithUnichars:(wchar_t *)unichars {
    return [[NSString alloc] initWithBytes:unichars
                             length:wcslen(unichars) * sizeof(*unichars)
                                  encoding:NSUTF32LittleEndianStringEncoding];
}

+ (instancetype) fileInfo:(struct RARHeaderDataEx *)fileHeader {
    return [[URKFileInfo alloc] initWithFileHeader:fileHeader];
}

- (instancetype)initWithFileHeader:(struct RARHeaderDataEx *)fileHeader
{
    URKCreateActivity("Init URKFileInfo");

    if ((self = [super init])) {
        URKLogDebug("Setting file info fields");
        
        _filename = [self stringWithUnichars:fileHeader->FileNameW];
        _archiveName = [self stringWithUnichars:fileHeader->ArcNameW];
        _uncompressedSize = (long long) fileHeader->UnpSizeHigh << 32 | fileHeader->UnpSize;
        _compressedSize = (long long) fileHeader->PackSizeHigh << 32 | fileHeader->PackSize;
        _compressionMethod = fileHeader->Method;
        _hostOS = fileHeader->HostOS;
        _timestamp = [self parseDOSDate:fileHeader->FileTime];
        _CRC = fileHeader->FileCRC;

        //_fileContinuedFromPreviousVolume = fileHeader->Flags  & (1 << 0)
        //_fileContinuedOnNextVolume = fileHeader->Flags & (1 << 1)
        _isEncryptedWithPassword = fileHeader->Flags & (1 << 2);
        //_fileHasComment = fileHeader->Flags  & (1 << 3)
        
        _isDirectory = (fileHeader->Flags & RHDF_DIRECTORY) ? YES : NO;
    }

    return self;
}



#pragma mark - Private Methods


- (NSDate *)parseDOSDate:(NSUInteger)dosTime
{
    URKCreateActivity("-parseDOSDate:");

    if (dosTime == 0) {
        URKLogDebug("DOS Time == 0");
        return nil;
    }
    
    // MSDOS Date Format Parsing specified at this URL:
    // http://www.cocoanetics.com/2012/02/decompressing-files-into-memory/
    
    int year = ((dosTime>>25) & 127) + 1980; // 7 bits
    int month = (dosTime>>21) & 15;          // 4 bits
    int day = (dosTime>>16) & 31;            // 5 bits
    int hour = (dosTime>>11) & 31;           // 5 bits
    int minute = (dosTime>>5) & 63;          // 6 bits
    int second = (dosTime & 31) * 2;         // 5 bits
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = year;
    components.month = month;
    components.day = day;
    components.hour = hour;
    components.minute = minute;
    components.second = second;
    
    return [[NSCalendar currentCalendar] dateFromComponents:components];
}

@end
