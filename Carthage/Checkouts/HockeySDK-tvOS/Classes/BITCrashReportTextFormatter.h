#import <Foundation/Foundation.h>

@class PLCrashReport;

// Dictionary keys for array elements returned by arrayOfAppUUIDsForCrashReport:
#ifndef kBITBinaryImageKeyUUID
#define kBITBinaryImageKeyUUID @"uuid"
#define kBITBinaryImageKeyArch @"arch"
#define kBITBinaryImageKeyType @"type"
#endif

/**
 *  HockeySDK Crash Reporter error domain
 */
typedef NS_ENUM (NSInteger, BITBinaryImageType) {
  /**
   *  App binary
   */
  BITBinaryImageTypeAppBinary,
  /**
   *  App provided framework
   */
  BITBinaryImageTypeAppFramework,
  /**
   *  Image not related to the app
   */
  BITBinaryImageTypeOther
};

@interface BITCrashReportTextFormatter : NSObject

+ (NSString *)stringValueForCrashReport:(PLCrashReport *)report crashReporterKey:(NSString *)crashReporterKey;
+ (NSArray *)arrayOfAppUUIDsForCrashReport:(PLCrashReport *)report;
+ (NSString *)bit_archNameFromCPUType:(uint64_t)cpuType subType:(uint64_t)subType;
+ (BITBinaryImageType)bit_imageTypeForImagePath:(NSString *)imagePath processPath:(NSString *)processPath;

@end
