//
//  ZKDataArchive.h
//  ZipKit
//
//  Created by Karl Moskowski on 07/05/09.
//

#import <Foundation/Foundation.h>
#import "ZKArchive.h"

@class ZKCDHeader;

@interface ZKDataArchive : ZKArchive {
	NSMutableData *_data;
	NSMutableArray *_inflatedFiles;
}

+ (ZKDataArchive *) archiveWithArchivePath:(NSString *)path;
+ (ZKDataArchive *) archiveWithArchiveData:(NSMutableData *)archiveData;
- (NSUInteger)          inflateAll;
- (NSData *) inflateFile:(ZKCDHeader *)cdHeader attributes:(NSDictionary **)fileAttributes;
- (NSUInteger) inflateInFolder:(NSString *)enclosingFolder withFolderName:(NSString *)folderName usingResourceFork:(BOOL)rfFlag;

- (NSInteger) deflateFiles:(NSArray *)paths relativeToPath:(NSString *)basePath usingResourceFork:(BOOL)flag;
- (NSInteger) deflateDirectory:(NSString *)dirPath relativeToPath:(NSString *)basePath usingResourceFork:(BOOL)flag;
- (NSInteger) deflateFile:(NSString *)path relativeToPath:(NSString *)basePath usingResourceFork:(BOOL)rfFlag;
- (NSInteger) deflateData:(NSData *)data withFilename:(NSString *)filename andAttributes:(NSDictionary *)fileAttributes;

@property (strong) NSMutableData *data;
@property (strong) NSMutableArray *inflatedFiles;

@end