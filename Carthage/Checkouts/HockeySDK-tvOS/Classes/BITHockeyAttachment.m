#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_CRASH_REPORTER

#import "BITHockeyAttachment.h"

@implementation BITHockeyAttachment

- (instancetype)initWithFilename:(NSString *)filename
            hockeyAttachmentData:(NSData *)hockeyAttachmentData
                     contentType:(NSString *)contentType
{
  if ((self = [super init])) {
    _filename = filename;

    _hockeyAttachmentData = hockeyAttachmentData;
    
    if (contentType) {
      _contentType = contentType;
    } else {
      _contentType = @"application/octet-stream";
    }

  }
  
  return self;
}


#pragma mark - NSCoder

- (void)encodeWithCoder:(NSCoder *)encoder {
  if (self.filename) {
    [encoder encodeObject:self.filename forKey:@"filename"];
  }
  if (self.hockeyAttachmentData) {
    [encoder encodeObject:self.hockeyAttachmentData forKey:@"data"];
  }
  [encoder encodeObject:self.contentType forKey:@"contentType"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
  if ((self = [super init])) {
    _filename = [decoder decodeObjectForKey:@"filename"];
    _hockeyAttachmentData = [decoder decodeObjectForKey:@"data"];
    _contentType = [decoder decodeObjectForKey:@"contentType"];
  }
  return self;
}

@end

#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */
