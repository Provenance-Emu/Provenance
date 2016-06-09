//
//  PVGameLibraryCollectionViewCell.m
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import "PVGameLibraryCollectionViewCell.h"
#import <QuartzCore/QuartzCore.h>
#import "UIImage+Color.h"
#import "UIView+FrameAdditions.h"

CGSize pv_CGSizeAspectFittingSize(CGSize originalSize, CGSize maximumSize) {
    CGFloat width = originalSize.width;
    CGFloat height = originalSize.height;
    
    CGFloat multiplier = 0.f;
    
    if (height > maximumSize.height) {
        multiplier = maximumSize.height / height;
    }
    
    if (width > maximumSize.width) {
        CGFloat provisionalMultiplier = maximumSize.width / width;
        BOOL validMultiplier = provisionalMultiplier > 0;
        if (validMultiplier && (provisionalMultiplier < multiplier || multiplier == 0)) {
            multiplier = provisionalMultiplier;
        }
    }
    
    if (multiplier > 0) {
        // CGRectIntegral does floorf() on origin and ceilf() on size
        height = ceilf(height * multiplier);
        width = ceilf(width * multiplier);
    }
    
    return CGSizeMake(width, height);
}

@interface PVGameLibraryCollectionViewCell ()

@property (nonatomic, strong) UIImageView *missingArtworkView;

@end

@implementation PVGameLibraryCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		_imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height - 44)];
		[_imageView setContentMode:UIViewContentModeScaleAspectFit];
		[_imageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, [_imageView frame].size.height, frame.size.width, 44)];
        [_titleLabel setLineBreakMode:NSLineBreakByTruncatingTail];
        UIColor *backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
        UIImage *missingArtworkImage = [UIImage imageWithSize:CGSizeMake(CGRectGetWidth(frame), CGRectGetHeight(frame) - 44)
                                                        color:backgroundColor
                                                         text:nil];
        self.missingArtworkView = [[UIImageView alloc] initWithImage:missingArtworkImage];
#if TARGET_OS_TV
        // The label's alpha will get set to 1 on focus
        _titleLabel.alpha = 0;
        [_imageView setAdjustsImageWhenAncestorFocused:YES];
        [self.missingArtworkView setAdjustsImageWhenAncestorFocused:YES];
        [_titleLabel setTextColor:[UIColor whiteColor]];
        [[_titleLabel layer] setMasksToBounds:NO];
        [_titleLabel setShadowColor:[[UIColor blackColor] colorWithAlphaComponent:0.8]];
        [_titleLabel setShadowOffset:CGSizeMake(-1, 1)];
#else
        [_titleLabel setTextColor:[UIColor blackColor]];
        [_titleLabel setNumberOfLines:0];
#endif
        [_titleLabel setLineBreakMode:NSLineBreakByTruncatingTail];
		[_titleLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
		[_titleLabel setBackgroundColor:[UIColor clearColor]];
		[_titleLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]];
		[_titleLabel setTextAlignment:NSTextAlignmentCenter];
		[_titleLabel setAdjustsFontSizeToFitWidth:YES];
		[_titleLabel setMinimumScaleFactor:0.75];

		[[self contentView] addSubview:_titleLabel];
        [[self contentView] addSubview:_imageView];
    }
	return self;
}

- (void)setText:(NSString *)text {
    [_titleLabel setText:text];
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text
                                                                         attributes:@{
                                                                                      NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline],
                                                                                      NSParagraphStyleAttributeName: paragraphStyle,
                                                                                      NSForegroundColorAttributeName: [UIColor grayColor]
                                                                                      }];
    UIColor *backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.9];
    UIImage *missingArtworkImage = [UIImage imageWithSize:self.missingArtworkView.bounds.size
                                                    color:backgroundColor
                                                     text:attributedText];
    self.missingArtworkView.image = missingArtworkImage;
    [self setNeedsLayout];
    [self setNeedsFocusUpdate];
}

- (void)dealloc
{
    _imageView = nil;
	_titleLabel = nil;
	self.missingArtworkView = nil;
}

- (void)prepareForReuse
{
	[super prepareForReuse];
	
	[self.imageView setImage:nil];
	[self.titleLabel setText:nil];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	if (![_imageView image])
	{
		[self.contentView addSubview:self.missingArtworkView];
        [_imageView removeFromSuperview];
    }
    else
    {
        [self.missingArtworkView removeFromSuperview];
        [self.contentView addSubview:_imageView];
    }

#if TARGET_OS_TV
    CGAffineTransform titleTransform = _titleLabel.transform;
    if (self.focused) {
        _titleLabel.transform = CGAffineTransformIdentity;
    }
    [self.contentView bringSubviewToFront:_titleLabel];
    [_titleLabel sizeToFit];
    [_titleLabel setWidth:[[self contentView] bounds].size.width];
    [_titleLabel setOriginX:0];
    CGSize imageSize = pv_CGSizeAspectFittingSize(_imageView.image.size, self.contentView.bounds.size);
    [_imageView setSize:imageSize];
    _imageView.center = CGPointMake(CGRectGetMidX(self.contentView.bounds),
                                    CGRectGetMidY(self.contentView.bounds));
    if (_imageView.image) {
        [_titleLabel setOriginY:CGRectGetMaxY(_imageView.frame)];
    } else {
        [_titleLabel setOriginY:CGRectGetMaxY(self.missingArtworkView.frame)];
    }
    _titleLabel.transform = titleTransform;
#endif
}

#if TARGET_OS_TV
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context
       withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
    [coordinator addCoordinatedAnimations:^{
        if (self.focused) {
            CGAffineTransform transform = CGAffineTransformMakeScale(1.25, 1.25);
            transform = CGAffineTransformTranslate(transform, 0, 40);
            self.titleLabel.alpha = 1;
            self.titleLabel.transform = transform;
        } else {
            self.titleLabel.alpha = 0;
            self.titleLabel.transform = CGAffineTransformIdentity;
        }
    } completion:nil];
}
#endif

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];

    if (selected)
    {
        [UIView animateWithDuration:0.1
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             [_imageView setAlpha:0.6];
                             [self.missingArtworkView setAlpha:0.6];
                         }
                         completion:NULL];
    }
    else
    {
        [UIView animateWithDuration:0.3
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             [_imageView setAlpha:1];
                             [self.missingArtworkView setAlpha:1];
                         }
                         completion:NULL];
    }
}


@end
