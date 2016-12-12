//
//  PVGameLibraryCollectionViewCell.m
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import "PVGameLibraryCollectionViewCell.h"
#import "UIImage+Color.h"
#import "UIView+FrameAdditions.h"
#import "PVGame+Sizing.h"
#import "PVMediaCache.h"
#import "PVSettingsModel.h"
#import "PVAppConstants.h"
#import "PVEmulatorConfiguration.h"

static const CGFloat LabelHeight = 44.0;

@interface PVGameLibraryCollectionViewCell ()

@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic, readonly) UILabel *titleLabel;
@property (strong, nonatomic) NSBlockOperation *operation;

@end

@implementation PVGameLibraryCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
        CGFloat imageHeight = frame.size.height;
        if ([[PVSettingsModel sharedInstance] showGameTitles]) {
            imageHeight -= 44;
        }
        
		_imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, imageHeight)];
		[_imageView setContentMode:UIViewContentModeScaleAspectFit];
		[_imageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, [_imageView frame].size.height, frame.size.width, LabelHeight)];
        [_titleLabel setLineBreakMode:NSLineBreakByTruncatingTail];
#if TARGET_OS_TV
        // The label's alpha will get set to 1 on focus
        _titleLabel.alpha = 0;
        [_imageView setAdjustsImageWhenAncestorFocused:YES];
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

        if ([[PVSettingsModel sharedInstance] showGameTitles]) {
            [[self contentView] addSubview:_titleLabel];
        }
        [[self contentView] addSubview:_imageView];
    }
	return self;
}

- (UIImage *)imageWithText:(NSString *)text
{
    if (!text) {
        UIColor *backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.9];
        return [UIImage imageWithSize:CGSizeMake(PVThumbnailMaxResolution, PVThumbnailMaxResolution)
                                color:backgroundColor
                                 text:[[NSAttributedString alloc] initWithString: @""]];
    }
    
    // TODO: To be replaced with the correct system placeholder
    
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text
                                                                         attributes:@{
                                                                                      NSFontAttributeName: [UIFont systemFontOfSize:30.0],
                                                                                      NSParagraphStyleAttributeName: paragraphStyle,
                                                                                      NSForegroundColorAttributeName: [UIColor grayColor]
                                                                                      }];
    
    UIColor *backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.9];
    UIImage *missingArtworkImage = [UIImage imageWithSize:CGSizeMake(PVThumbnailMaxResolution, PVThumbnailMaxResolution)
                                                    color:backgroundColor
                                                     text:attributedText];
    
    return missingArtworkImage;
}

- (void)setupWithGame:(PVGame *)game
{
    
    NSString *artworkURL = [game customArtworkURL];
    NSString *originalArtworkURL = [game originalArtworkURL];
    
    if ([[PVSettingsModel sharedInstance] showGameTitles]) {
        [_titleLabel setText:[game title]];
    }
    
    // TODO: May be renabled later
    NSString *placeholderImageText = [[PVEmulatorConfiguration sharedInstance] shortNameForSystemIdentifier:game.systemIdentifier];

    if ([artworkURL isEqualToString:@""] &&
        [originalArtworkURL isEqualToString:@""]) {
        NSString *artworkText;
        if ([[PVSettingsModel sharedInstance] showGameTitles]) {
            artworkText = placeholderImageText;
        } else {
            artworkText = game.title;
        }
        self.imageView.image = [self imageWithText:artworkText];
    } else {
        NSString *key = [artworkURL length] ? artworkURL : nil;
        
        if (!key) {
            key = [originalArtworkURL length] ? originalArtworkURL : nil;
        }
        
        if (key) {
            self.operation = [[PVMediaCache shareInstance] imageForKey:key completion:^(UIImage *image) {
                
                NSString *artworkText;
                if ([[PVSettingsModel sharedInstance] showGameTitles]) {
                    artworkText = placeholderImageText;
                } else {
                    artworkText = game.title;
                }
                UIImage *artwork = image ?: [self imageWithText:artworkText];
                
                self.imageView.image = artwork;
                
            #if TARGET_OS_TV
                CGFloat width = CGRectGetWidth(self.frame);
                CGSize boxartSize = CGSizeMake(width, width / game.boxartAspectRatio);
                self.imageView.frame = CGRectMake(0, 0, width, boxartSize.height);
            #else
                CGFloat imageHeight = self.frame.size.height;
                if ([[PVSettingsModel sharedInstance] showGameTitles]) {
                    imageHeight -= 44;
                }
                self.imageView.frame = CGRectMake(0, 0, self.frame.size.width, imageHeight);
            #endif
                
                [self setNeedsLayout];
            }];
        }
    }
    
    [self setNeedsLayout];
    if ([self respondsToSelector:@selector(setNeedsFocusUpdate)]) {
        [self setNeedsFocusUpdate];
    }
    
    [self setNeedsLayout];
}

- (void)dealloc
{
    [self.operation cancel];
    
    _imageView = nil;
	_titleLabel = nil;
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

#if TARGET_OS_TV
    CGAffineTransform titleTransform = _titleLabel.transform;
    if (self.focused) {
        _titleLabel.transform = CGAffineTransformIdentity;
    }
    [self.contentView bringSubviewToFront:_titleLabel];
    [_titleLabel sizeToFit];
    [_titleLabel setWidth:[[self contentView] bounds].size.width];
    [_titleLabel setOriginX:0];
    [_titleLabel setOriginY:CGRectGetMaxY(_imageView.frame)];
    _titleLabel.transform = titleTransform;
#else
    CGFloat imageHeight = self.frame.size.height;
    if ([[PVSettingsModel sharedInstance] showGameTitles]) {
        imageHeight -= 44;
    }
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

+ (CGSize)cellSizeForImageSize:(CGSize)imageSize
{
    return CGSizeMake(imageSize.width, imageSize.height + LabelHeight);
}

@end
