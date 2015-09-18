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

//static UIColor * rgb(CGFloat r, CGFloat g, CGFloat b)
//{
//	return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
//}

@interface PVGameLibraryCollectionViewCell ()

@property (nonatomic, strong) UIView *missingArtworkView;

@end

@implementation PVGameLibraryCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		_imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height - 44)];
		[_imageView setContentMode:UIViewContentModeScaleAspectFit];
//        [_imageView setAdjustsImageWhenAncestorFocused:YES];
		[_imageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, [_imageView frame].size.height, frame.size.width, 44)];

#if TARGET_OS_TV
        [_titleLabel setLineBreakMode:NSLineBreakByWordWrapping];
#else
        [_titleLabel setLineBreakMode:NSLineBreakByTruncatingTail];
#endif
		[_titleLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
		[_titleLabel setBackgroundColor:[UIColor clearColor]];
		[_titleLabel setTextColor:[UIColor blackColor]];
		[_titleLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]];
		[_titleLabel setTextAlignment:NSTextAlignmentCenter];
		[_titleLabel setNumberOfLines:0];
		[_titleLabel setAdjustsFontSizeToFitWidth:YES];
		[_titleLabel setMinimumScaleFactor:0.75];

		[[self contentView] addSubview:_titleLabel];
        [[self contentView] addSubview:_imageView];
		
//		NSArray *backgroundColors = @[rgb(26, 188, 156),
//									  rgb(46, 204, 113),
//									  rgb(52, 152, 219),
//									  rgb(155, 89, 182),
//									  rgb(52, 73, 94),
//									  rgb(22, 160, 133),
//									  rgb(39, 174, 96),
//									  rgb(41, 128, 185),
//									  rgb(142, 68, 173),
//									  rgb(44, 62, 80),
//									  rgb(241, 196, 15),
//									  rgb(230, 126, 34),
//									  rgb(231, 76, 60),
//									  rgb(243, 156, 18),
//									  rgb(211, 84, 0),
//									  rgb(192, 57, 43)];
//		
//		UIColor *backgroundColor = backgroundColors[(arc4random() % [backgroundColors count])];
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
//		[_missingLabel setAdjustsFontSizeToFitWidth:YES];
//		[_missingLabel setMinimumScaleFactor:0.75];
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

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	if (![_imageView image])
	{
		[self addSubview:self.missingArtworkView];
	}
	else
	{
		[self.missingArtworkView removeFromSuperview];
	}

#if TARGET_OS_TV
    [_titleLabel sizeToFit];
    [_titleLabel setWidth:[[self contentView] bounds].size.width];
#endif
}

#if TARGET_OS_TV
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
    if (self.focused)
    {
        [self setHighlighted:YES];
    }
    else
    {
        [self setHighlighted:NO];
    }
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context
{
    if ([context nextFocusedView] == self)
    {
        [self setHighlighted:YES];
    }
    else if ([context previouslyFocusedView] == self)
    {
        [self setHighlighted:NO];
    }

    return YES;
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
