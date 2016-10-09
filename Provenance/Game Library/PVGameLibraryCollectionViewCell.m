//
//  PVGameLibraryCollectionViewCell.m
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import "PVGameLibraryCollectionViewCell.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+FrameAdditions.h"
#import "PVGame.h"
#import "PVMediaCache.h"
#import "PVSettingsModel.h"
#import "PVAppConstants.h"
#import "PVEmulatorConfiguration.h"

static const CGFloat LabelHeight = 80.0;

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

@property (nonatomic, strong) UIView *missingArtworkView;

@end

@implementation PVGameLibraryCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		_imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, CGRectGetHeight(frame) - LabelHeight)];
		[_imageView setContentMode:UIViewContentModeScaleAspectFit];
        [_imageView setAdjustsImageWhenAncestorFocused:YES];
		[_imageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, [_imageView frame].size.height + 44, frame.size.width, 44)];
        
#if TARGET_OS_TV
        _titleLabel.alpha = 0.0;
        [_titleLabel setLineBreakMode:NSLineBreakByWordWrapping];
#else
        [_titleLabel setLineBreakMode:NSLineBreakByTruncatingTail];
#endif
		[_titleLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
		[_titleLabel setBackgroundColor:[UIColor clearColor]];
		[_titleLabel setTextColor:[UIColor blackColor]];
		[_titleLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]];
		[_titleLabel setTextAlignment:NSTextAlignmentCenter];
		[_titleLabel setNumberOfLines:2];
		[_titleLabel setAdjustsFontSizeToFitWidth:YES];
		[_titleLabel setMinimumScaleFactor:0.75];

		[[self contentView] addSubview:_titleLabel];
        [[self contentView] addSubview:_imageView];
		
		UIColor *backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.6];
		
		self.missingArtworkView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height - 44)];
		[self.missingArtworkView setBackgroundColor:backgroundColor];
		[[self.missingArtworkView layer] setBorderColor:[[UIColor colorWithWhite:0.7 alpha:0.6] CGColor]];
		[[self.missingArtworkView layer] setBorderWidth:0.5];
		_missingLabel = [[UILabel alloc] initWithFrame:[_missingArtworkView bounds]];
		[self.missingArtworkView addSubview:_missingLabel];
		[_missingLabel setText:@"Missing Artwork"];
		[_missingLabel setNumberOfLines:0];
		[_missingLabel setTextAlignment:NSTextAlignmentCenter];
		[_missingLabel setTextColor:[UIColor grayColor]];
		[_missingLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];

	}
	
	return self;
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

- (void)sizeImageViews:(CGSize)size
{
    self.missingArtworkView.frame = CGRectMake(0, 0, CGRectGetWidth(self.frame), size.height);
    self.missingLabel.frame = self.missingArtworkView.bounds;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	if (![_imageView image])
	{
		[self addSubview:self.missingArtworkView];
        self.titleLabel.alpha = 0.0;
	}
	else
	{
		[self.missingArtworkView removeFromSuperview];
        self.titleLabel.alpha = (self.focused) ? 1.0 : 0.0;
	}

#if TARGET_OS_TV
    [_titleLabel sizeToFit];
    [_titleLabel setWidth:[[self contentView] bounds].size.width];
#endif
}

+ (CGSize)cellSizeForImageSize:(CGSize)imageSize
{
    return CGSizeMake(imageSize.width, imageSize.height + LabelHeight);
}

#if TARGET_OS_TV
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
    [coordinator addCoordinatedAnimations:^{
        self.titleLabel.alpha = (self.focused) ? 1.0 : 0.0;
        CGAffineTransform transform = (self.focused) ? CGAffineTransformMakeScale(1.33, 1.33) : CGAffineTransformIdentity;
        [self.missingArtworkView setTransform:transform];
    } completion:nil];
}

- (void)setHighlighted:(BOOL)highlighted
{
	[super setHighlighted:highlighted];
	
	if (highlighted)
	{
		[UIView animateWithDuration:0.3
							  delay:0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
                             [self.imageView setTransform:CGAffineTransformMakeScale(1.33, 1.33)];
                             [self.missingArtworkView setTransform:CGAffineTransformMakeScale(1.33, 1.33)];
						 }
						 completion:NULL];
	}
	else
	{
		[UIView animateWithDuration:0.3
							  delay:0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
                             [self.imageView setTransform:CGAffineTransformIdentity];
                             [self.missingArtworkView setTransform:CGAffineTransformIdentity];
						 }
						 completion:NULL];
	}
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
