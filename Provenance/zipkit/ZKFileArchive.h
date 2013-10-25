//
//  ZKFileArchive.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>
#import "ZKArchive.h"

@class ZKCDHeader;

@interface ZKFileArchive : ZKArchive 

+ (ZKFileArchive *) process:(id)item usingResourceFork:(BOOL)flag withInvoker:(id)invoker andDelegate:(id)delegate;
+ (ZKFileArchive *) archiveWithArchivePath:(NSString *)archivePath;

- (NSInteger) inflateToDiskUsingResourceFork:(BOOL)flag;
- (NSInteger) inflateToDirectory:(NSString *)expansionDirectory usingResourceFork:(BOOL)rfFlag;
- (NSInteger) inflateFile:(ZKCDHeader *)cdHeader toDirectory:(NSString *)expansionDirectory;

- (NSInteger) deflateFiles:(NSArray *)paths relativeToPath:(NSString *)basePath usingResourceFork:(BOOL)flag;
- (NSInteger) deflateDirectory:(NSString *)dirPath relativeToPath:(NSString *)basePath usingResourceFork:(BOOL)flag;
- (NSInteger) deflateFile:(NSString *)path relativeToPath:(NSString *)basePath usingResourceFork:(BOOL)flag;

@property (assign) BOOL useZip64Extensions;

@end