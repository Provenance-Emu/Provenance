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

@interface PVGameLibraryCollectionViewCell () {

//	CALayer *_selectionLayer;
	UIImageView *_selectionImage;
}

@end

@implementation PVGameLibraryCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		_imageView = [[UIImageView alloc] initWithFrame:CGRectMake(([self bounds].size.width - 72) / 2, 3, 72, frame.size.height - 50)];
		[_imageView setContentMode:UIViewContentModeScaleAspectFit];
		[_imageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
				
		_titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, [_imageView frame].size.height + 3, frame.size.width, 44)];
		[_titleLabel setLineBreakMode:NSLineBreakByTruncatingTail];
		[_titleLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
		[_titleLabel setBackgroundColor:[UIColor clearColor]];
		[_titleLabel setTextColor:[UIColor whiteColor]];
		[_titleLabel setShadowColor:[UIColor blackColor]];
		[_titleLabel setShadowOffset:CGSizeMake(0, 1)];
		[_titleLabel setFont:[UIFont boldSystemFontOfSize:14]];
		[_titleLabel setTextAlignment:NSTextAlignmentCenter];
		[_titleLabel setNumberOfLines:0];
		
		[[self contentView] addSubview:_imageView];
		[[self contentView] addSubview:_titleLabel];
	}
	
	return self;
}

- (void)prepareForReuse
{
	[super prepareForReuse];
	
	[self.imageView setImage:nil];
	[self.titleLabel setText:nil];
}

- (void)setHighlighted:(BOOL)highlighted
{
	if (!_selectionImage)
	{
		_selectionImage = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"selection"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 16, 0, 16)]];
		[_selectionImage setFrame:CGRectMake(([self bounds].size.width - 76) / 2, 0, 76, 104)];
		[_selectionImage setAlpha:0];
		[[self contentView] addSubview:_selectionImage];
	}
	
	if (highlighted)
	{
		[UIView animateWithDuration:0.3
							  delay:0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
							 [_selectionImage setAlpha:1];
						 }
						 completion:NULL];
	}
	else
	{
		[UIView animateWithDuration:0.3
							  delay:0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
							 [_selectionImage setAlpha:0];
						 }
						 completion:NULL];
	}
}

- (void)setSelected:(BOOL)selected
{
	if (!_selectionImage)
	{
		_selectionImage = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"selection"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 16, 0, 16)]];
		[_selectionImage setFrame:CGRectMake(([self bounds].size.width - 76) / 2, 0, 76, 104)];
		[_selectionImage setAlpha:0];
		[[self contentView] addSubview:_selectionImage];
	}
	
	if (selected)
	{
		[UIView animateWithDuration:0.3
							  delay:0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
							 [_selectionImage setAlpha:1];
						 }
						 completion:NULL];
	}
	else
	{
		[UIView animateWithDuration:0.3
							  delay:0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
							 [_selectionImage setAlpha:0];
						 }
						 completion:NULL];
	}
}

@end
