/*
 * Author: Moritz Haarmann <post@moritzhaarmann.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_FEEDBACK

#import "BITFeedbackMessageAttachment.h"
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define kCacheFolderName @"attachments"

@interface BITFeedbackMessageAttachment()

@property (nonatomic, strong) NSMutableDictionary *thumbnailRepresentations;
@property (nonatomic, strong) NSData *internalData;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *tempFilename;
@property (nonatomic, copy) NSString *cachePath;
@property (nonatomic, strong) NSFileManager *fm;

@end

@implementation BITFeedbackMessageAttachment

+ (BITFeedbackMessageAttachment *)attachmentWithData:(NSData *)data contentType:(NSString *)contentType {
  
  static NSDateFormatter *formatter;
  
  if(!formatter) {
    formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
  }
  
  BITFeedbackMessageAttachment *newAttachment = [BITFeedbackMessageAttachment new];
  newAttachment.contentType = contentType;
  newAttachment.data = data;
  newAttachment.originalFilename = [NSString stringWithFormat:@"Attachment: %@", [formatter stringFromDate:[NSDate date]]];

  return newAttachment;
}

- (instancetype)init {
  if ((self = [super init])) {
    _isLoading = NO;
    _thumbnailRepresentations = [NSMutableDictionary new];
    
    _fm = [[NSFileManager alloc] init];
    _cachePath = [bit_settingsDir() stringByAppendingPathComponent:kCacheFolderName];
    
    BOOL isDirectory;
    
    if (![_fm fileExistsAtPath:_cachePath isDirectory:&isDirectory]){
      [_fm createDirectoryAtPath:_cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
  }
  return self;
}

- (void)setData:(NSData *)data {
  self.internalData = data;
  self.filename = [self possibleFilename];
  [self.internalData writeToFile:self.filename atomically:YES];
}

- (NSData *)data {
  if (!self.internalData && self.filename) {
    self.internalData = [NSData dataWithContentsOfFile:self.filename];
  }
  
  if (self.internalData) {
    return self.internalData;
  }
  
  return [NSData data];
}

- (void)replaceData:(NSData *)data {
  self.data = data;
  self.thumbnailRepresentations = [NSMutableDictionary new];
}

- (BOOL)needsLoadingFromURL {
  return (self.sourceURL && ![self.fm fileExistsAtPath:(NSString *)[self.localURL path]]);
}

- (BOOL)isImage {
  return ([self.contentType rangeOfString:@"image"].location != NSNotFound);
}

- (NSURL *)localURL {
  if (self.filename && [self.fm fileExistsAtPath:self.filename]) {
    return [NSURL fileURLWithPath:self.filename];
  }
  
  return [NSURL URLWithString:@""];
}


#pragma mark NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.contentType forKey:@"contentType"];
  [aCoder encodeObject:self.filename forKey:@"filename"];
  [aCoder encodeObject:self.originalFilename forKey:@"originalFilename"];
  [aCoder encodeObject:self.sourceURL forKey:@"url"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  if ((self = [self init])) {
    self.contentType = [aDecoder decodeObjectForKey:@"contentType"];
    self.filename = [aDecoder decodeObjectForKey:@"filename"];
    self.thumbnailRepresentations = [NSMutableDictionary new];
    self.originalFilename = [aDecoder decodeObjectForKey:@"originalFilename"];
    self.sourceURL = [aDecoder decodeObjectForKey:@"url"];
  }
  
  return self;
}


#pragma mark - Thumbnails / Image Representation

- (UIImage *)imageRepresentation {
  if ([self.contentType rangeOfString:@"image"].location != NSNotFound && self.filename ) {
    return [UIImage imageWithData:self.data];
  } else {
    // Create a Icon ..
    UIDocumentInteractionController* docController = [[UIDocumentInteractionController alloc] init];
    docController.name = self.originalFilename;
    NSArray* icons = docController.icons;
    if (icons.count){
      return icons[0];
    } else {
      return nil;
    }
  }
}

- (UIImage *)thumbnailWithSize:(CGSize)size {
  id<NSCopying> cacheKey = [NSValue valueWithCGSize:size];
  
  if (!self.thumbnailRepresentations[cacheKey]) {
    UIImage *image = self.imageRepresentation;
    // consider the scale.
    if (!image) {
      return nil;
    }
    
    CGFloat scale = [UIScreen mainScreen].scale;
    
    if (scale != image.scale) {
      
      CGSize scaledSize = CGSizeApplyAffineTransform(size, CGAffineTransformMakeScale(scale, scale));
      UIImage *thumbnail = bit_imageToFitSize(image, scaledSize, YES) ;
      
      UIImage *scaledThumbnail = [UIImage imageWithCGImage:(CGImageRef)thumbnail.CGImage scale:scale orientation:thumbnail.imageOrientation];
      if (thumbnail) {
        [self.thumbnailRepresentations setObject:scaledThumbnail forKey:cacheKey];
      }
      
    } else {
      UIImage *thumbnail = bit_imageToFitSize(image, size, YES) ;
      
      [self.thumbnailRepresentations setObject:thumbnail forKey:cacheKey];
      
    }
    
  }
  
  return self.thumbnailRepresentations[cacheKey];
}


#pragma mark - Persistence Helpers

- (void)setFilename:(NSString *)filename {
  if (filename) {
    filename = [self.cachePath stringByAppendingPathComponent:[filename lastPathComponent]];
  }
  _filename = filename;
}

- (NSString *)possibleFilename {
  if (self.tempFilename) {
    return self.tempFilename;
  }
  
  NSString *uniqueString = bit_UUID();
  self.tempFilename = [self.cachePath stringByAppendingPathComponent:uniqueString];
  
  // File extension that suits the Content type.
  
  CFStringRef mimeType = (__bridge CFStringRef)self.contentType;
  if (mimeType) {
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, NULL);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
    if (extension) {
      self.tempFilename = [self.tempFilename stringByAppendingPathExtension:(__bridge NSString *)(extension)];
      CFRelease(extension);
    }
    if (uti) {
      CFRelease(uti);
    }
  }
  
  return self.tempFilename;
}

- (void)deleteContents {
  if (self.filename) {
    [self.fm removeItemAtPath:self.filename error:nil];
    self.filename = nil;
  }
}


#pragma mark - QLPreviewItem

- (NSString *)previewItemTitle {
  return self.originalFilename;
}

- (NSURL *)previewItemURL {
  if (self.localURL){
    return self.localURL;
  } else if (self.sourceURL) {
    NSString *filename = self.possibleFilename;
    if (filename) {
      return [NSURL fileURLWithPath:filename];
    }
  }
  
  return [NSURL URLWithString:(NSString *)[[NSBundle mainBundle] pathForResource:@"FeedbackPlaceholder" ofType:@"png"]];
}

@end

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
