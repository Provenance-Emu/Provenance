#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_CRASH_REPORTER

#import "BITCrashAttachment.h"

@implementation BITCrashAttachment

- (instancetype)initWithFilename:(NSString *)filename
             crashAttachmentData:(NSData *)crashAttachmentData
                     contentType:(NSString *)contentType
{
  self = [super initWithFilename:filename hockeyAttachmentData:crashAttachmentData contentType:contentType];
  
  return self;
}

@end

#endif
