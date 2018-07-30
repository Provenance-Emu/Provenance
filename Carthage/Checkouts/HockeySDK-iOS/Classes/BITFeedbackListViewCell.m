/*
 * Author: Andreas Linde <mail@andreaslinde.de>
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

#import "HockeySDKPrivate.h"

#import "BITFeedbackListViewCell.h"
#import "BITFeedbackMessageAttachment.h"
#import "BITActivityIndicatorButton.h"
#import "BITFeedbackManagerPrivate.h"

#import <tgmath.h>

#define BACKGROUNDCOLOR_DEFAULT_OS7 BIT_RGBCOLOR(255, 255, 255)
#define BACKGROUNDCOLOR_ALTERNATE_OS7 BIT_RGBCOLOR(255, 255, 255)

#define TEXTCOLOR_TITLE BIT_RGBCOLOR(75, 75, 75)

#define TEXTCOLOR_DEFAULT BIT_RGBCOLOR(25, 25, 25)
#define TEXTCOLOR_PENDING BIT_RGBCOLOR(75, 75, 75)

#define TITLE_FONTSIZE 12
#define TEXT_FONTSIZE 15

#define FRAME_SIDE_BORDER 10
#define FRAME_TOP_BORDER 8
#define FRAME_BOTTOM_BORDER 5

#define LABEL_TITLE_Y 3
#define LABEL_TITLE_HEIGHT 15

#define LABEL_TEXT_Y 25

#define ATTACHMENT_SIZE 45


@interface BITFeedbackListViewCell ()

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;

@property (nonatomic, strong) UILabel *labelTitle;

@property (nonatomic, strong) NSMutableArray *attachmentViews;

@property (nonatomic, strong) UIView *accessoryBackgroundView;

@property (nonatomic, strong) id updateAttachmentNotification;

@end


@implementation BITFeedbackListViewCell


- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    // Initialization code
    _backgroundStyle = BITFeedbackListViewCellBackgroundStyleNormal;
    
    _message = nil;
    
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [_dateFormatter setLocale:[NSLocale currentLocale]];
    [_dateFormatter setDoesRelativeDateFormatting:YES];
    
    _timeFormatter = [[NSDateFormatter alloc] init];
    [_timeFormatter setTimeStyle:NSDateFormatterShortStyle];
    [_timeFormatter setDateStyle:NSDateFormatterNoStyle];
    [_timeFormatter setLocale:[NSLocale currentLocale]];
    [_timeFormatter setDoesRelativeDateFormatting:YES];
    
    _labelTitle = [[UILabel alloc] init];
    _labelTitle.font = [UIFont systemFontOfSize:TITLE_FONTSIZE];
    
    _labelText = [[BITAttributedLabel alloc] initWithFrame:CGRectZero];
    _labelText.font = [UIFont systemFontOfSize:TEXT_FONTSIZE];
    _labelText.numberOfLines = 0;
    _labelText.textAlignment = NSTextAlignmentLeft;
    _labelText.enabledTextCheckingTypes = UIDataDetectorTypeAll;
    
    _attachmentViews = [NSMutableArray new];
    [self registerObservers];
  }
  return self;
}

- (void)dealloc {
  [self unregisterObservers];
}


#pragma mark - Private

- (void) registerObservers {
  __weak typeof(self) weakSelf = self;
  if (nil == self.updateAttachmentNotification) {
    self.updateAttachmentNotification = [[NSNotificationCenter defaultCenter] addObserverForName:kBITFeedbackUpdateAttachmentThumbnail
                                                                                    object:nil
                                                                                     queue:NSOperationQueue.mainQueue
                                                                                usingBlock:^(NSNotification *note) {
                                                                                  typeof(self) strongSelf = weakSelf;
                                                                                  [strongSelf updateAttachmentFromNotification:note];
                                                                                }];
  }
}

- (void) unregisterObservers {
  if (self.updateAttachmentNotification) {
    [[NSNotificationCenter defaultCenter] removeObserver:self.updateAttachmentNotification];
    self.updateAttachmentNotification = nil;
  }
}

- (void) updateAttachmentFromNotification:(NSNotification *)note {
  if (!self.message) return;
  if (!self.message.attachments) return;
  if (self.message.attachments.count == 0) return;
  if (!note.object) return;
  if (![note.object isKindOfClass:[BITFeedbackMessageAttachment class]]) return;
  
  BITFeedbackMessageAttachment *attachment = (BITFeedbackMessageAttachment *)note.object;
  if (![self.message.attachments containsObject:attachment]) return;
  
  // The attachment is part of the message used for this cell, so lets update it.
  [self setAttachments:self.message.previewableAttachments];
  [self setNeedsLayout];
}

- (UIColor *)backgroundColor {
  
  if (self.backgroundStyle == BITFeedbackListViewCellBackgroundStyleNormal) {
    return BACKGROUNDCOLOR_DEFAULT_OS7;
  } else {
    return BACKGROUNDCOLOR_ALTERNATE_OS7;
  }
}

- (BOOL)isSameDayWithDate1:(NSDate*)date1 date2:(NSDate*)date2 {
  NSCalendar* calendar = [NSCalendar currentCalendar];
  
  unsigned unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay;
  
  NSDateComponents *dateComponent1 = [calendar components:unitFlags fromDate:date1];
  NSDateComponents *dateComponent2 = [calendar components:unitFlags fromDate:date2];
  
  return ([dateComponent1 day] == [dateComponent2 day] &&
          [dateComponent1 month] == [dateComponent2 month] &&
          [dateComponent1 year]  == [dateComponent2 year]);
}


#pragma mark - Layout

+ (CGFloat) heightForRowWithMessage:(BITFeedbackMessage *)message tableViewWidth:(CGFloat)width {
  
  CGFloat baseHeight = [self heightForTextInRowWithMessage:message tableViewWidth:width];
  
  CGFloat attachmentsPerRow = floor(width / (FRAME_SIDE_BORDER + ATTACHMENT_SIZE));
  
  CGFloat calculatedHeight = baseHeight + (FRAME_TOP_BORDER + ATTACHMENT_SIZE) * ceil([message previewableAttachments].count / attachmentsPerRow);
  
  return ceil(calculatedHeight);
}



+ (CGFloat) heightForTextInRowWithMessage:(BITFeedbackMessage *)message tableViewWidth:(CGFloat)width {
  CGFloat calculatedHeight;
  
  if ([message.text respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
    CGRect calculatedRect = [message.text boundingRectWithSize:CGSizeMake(width - (2 * FRAME_SIDE_BORDER), CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                    attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:TEXT_FONTSIZE]}
                                                       context:nil];
    calculatedHeight = calculatedRect.size.height + FRAME_TOP_BORDER + LABEL_TEXT_Y + FRAME_BOTTOM_BORDER;
    
    // added to make space for the images.
    
    
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    calculatedHeight = [message.text sizeWithFont:[UIFont systemFontOfSize:TEXT_FONTSIZE]
                                constrainedToSize:CGSizeMake(width - (2 * FRAME_SIDE_BORDER), CGFLOAT_MAX)
                        ].height + FRAME_TOP_BORDER + LABEL_TEXT_Y + FRAME_BOTTOM_BORDER;
    
#pragma clang diagnostic pop
  }
  
  return ceil(calculatedHeight);
}

- (void)setAttachments:(NSArray *)attachments {
  for (UIView *view in self.attachmentViews){
    [view removeFromSuperview];
  }
  
  [self.attachmentViews removeAllObjects];
  
  for (BITFeedbackMessageAttachment *attachment in attachments){
    if (attachment.localURL || attachment.sourceURL) {
      BITActivityIndicatorButton *imageView = [BITActivityIndicatorButton buttonWithType:UIButtonTypeCustom];
    
      if (attachment.localURL){
        [imageView setImage:[attachment thumbnailWithSize:CGSizeMake(ATTACHMENT_SIZE, ATTACHMENT_SIZE)] forState:UIControlStateNormal];
        [imageView setShowsActivityIndicator:NO];
      } else {
        [imageView setImage:nil forState:UIControlStateNormal];
        [imageView setShowsActivityIndicator:YES];
      }
      [imageView setContentMode:UIViewContentModeScaleAspectFit];
      [imageView addTarget:self action:@selector(imageButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
      
      [self.attachmentViews addObject:imageView];
    }
  }
}


- (void)layoutSubviews {
  if (!self.accessoryBackgroundView){
    self.accessoryBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 2, self.frame.size.width * 2, self.frame.size.height - 2)];
    self.accessoryBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    self.accessoryBackgroundView.clipsToBounds = YES;
    
    // colors
    self.accessoryBackgroundView.backgroundColor = [self backgroundColor];
  }
  
  if (self.accessoryBackgroundView.superview){
    [self.accessoryBackgroundView removeFromSuperview];
  }
  self.contentView.backgroundColor = [self backgroundColor];
  self.labelTitle.backgroundColor = [self backgroundColor];
  self.labelText.backgroundColor = [self backgroundColor];
  
  self.labelTitle.textColor = TEXTCOLOR_TITLE;
  if (self.message.status == BITFeedbackMessageStatusSendPending || self.message.status == BITFeedbackMessageStatusSendInProgress) {
    [self.labelText setTextColor:TEXTCOLOR_PENDING];
  } else {
    [self.labelText setTextColor:TEXTCOLOR_DEFAULT];
  }
  
  // background for deletion accessory view
  
  
  // header
  NSString *dateString = @"";
  if (self.message.status == BITFeedbackMessageStatusSendPending || self.message.status == BITFeedbackMessageStatusSendInProgress) {
    dateString = BITHockeyLocalizedString(@"Pending");
  } else if (self.message.date) {
    if ([self isSameDayWithDate1:[NSDate date] date2:self.message.date]) {
      dateString = [self.timeFormatter stringFromDate:self.message.date];
    } else {
      dateString = [self.dateFormatter stringFromDate:self.message.date];
    }
  }
  [self.labelTitle setText:dateString];
  [self.labelTitle setFrame:CGRectMake(FRAME_SIDE_BORDER, FRAME_TOP_BORDER + LABEL_TITLE_Y, self.frame.size.width - (2 * FRAME_SIDE_BORDER), LABEL_TITLE_HEIGHT)];
  
  if (self.message.userMessage) {
    self.labelTitle.textAlignment = NSTextAlignmentRight;
    self.labelText.textAlignment = NSTextAlignmentRight;
  } else {
    self.labelTitle.textAlignment = NSTextAlignmentLeft;
    self.labelText.textAlignment = NSTextAlignmentLeft;
  }
  
  [self addSubview:self.labelTitle];
  
  // text
  [self.labelText setText:self.message.text];
  CGSize sizeForTextLabel = CGSizeMake(self.frame.size.width - (2 * FRAME_SIDE_BORDER),
                                       [[self class] heightForTextInRowWithMessage:self.message tableViewWidth:self.frame.size.width] - LABEL_TEXT_Y - FRAME_BOTTOM_BORDER);
  
  [self.labelText setFrame:CGRectMake(FRAME_SIDE_BORDER, LABEL_TEXT_Y, sizeForTextLabel.width, sizeForTextLabel.height)];
  
  [self addSubview:self.labelText];
  
  CGFloat baseOffsetOfText = CGRectGetMaxY(self.labelText.frame);
  
  
  int i = 0;
  
  CGFloat attachmentsPerRow = floor(self.frame.size.width / (FRAME_SIDE_BORDER + ATTACHMENT_SIZE));
  
  for (BITActivityIndicatorButton *imageButton in self.attachmentViews) {
    imageButton.contentMode = UIViewContentModeScaleAspectFit;
    imageButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
    
    if (!self.message.userMessage) {
      imageButton.frame = CGRectMake(FRAME_SIDE_BORDER + (FRAME_SIDE_BORDER + ATTACHMENT_SIZE) * (i%(int)attachmentsPerRow) , floor(i/attachmentsPerRow)*(FRAME_SIDE_BORDER + ATTACHMENT_SIZE) + baseOffsetOfText , ATTACHMENT_SIZE, ATTACHMENT_SIZE);
    } else {
      imageButton.frame = CGRectMake(self.frame.size.width - FRAME_SIDE_BORDER - ATTACHMENT_SIZE -  ((FRAME_SIDE_BORDER + ATTACHMENT_SIZE) *  (i%(int)attachmentsPerRow) ), floor(i/attachmentsPerRow)*(FRAME_SIDE_BORDER + ATTACHMENT_SIZE) + baseOffsetOfText , ATTACHMENT_SIZE, ATTACHMENT_SIZE);
    }
    
    if (!imageButton.superview) {
      if (self.accessoryBackgroundView.superview) {
        [self insertSubview:imageButton aboveSubview:self.accessoryBackgroundView];
      } else {
        [self addSubview:imageButton];
      }
    }
    
    i++;
  }
  
  [super layoutSubviews];
}

- (void)imageButtonPressed:(id)sender {
  id strongDelegate = self.delegate;
  if ([strongDelegate respondsToSelector:@selector(listCell:didSelectAttachment:)]) {
    NSUInteger index = [self.attachmentViews indexOfObject:sender];
    if (index != NSNotFound && [self.message previewableAttachments].count > index) {
      BITFeedbackMessageAttachment *attachment = [self.message previewableAttachments][index];
      [strongDelegate listCell:self didSelectAttachment:attachment];
    }
  }
}

- (NSString *)accessibilityLabel {
  NSString *messageTime = [self.labelTitle accessibilityLabel];
  NSString *messageText = [self.labelText accessibilityLabel];
  return [NSString stringWithFormat:@"%@, %@", messageTime, messageText];
}

@end

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
