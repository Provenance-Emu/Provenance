#import <Foundation/Foundation.h>
 
#if COCOAPODS
#import <SSZipArchive.h>
#else
#import <ZipArchive.h>
#endif


/**
 * Test delegate by collecting its calls
 */
@interface CollectingDelegate : NSObject <SSZipArchiveDelegate>
@property(nonatomic, retain) NSMutableArray<NSString *> *files;
@end
