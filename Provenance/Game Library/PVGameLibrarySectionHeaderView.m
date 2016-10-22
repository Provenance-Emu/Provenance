//
//  PVGameLibrarySectionHeaderView.m
//  Provenance
//
//  Created by James Addyman on 16/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGameLibrarySectionHeaderView.h"

@implementation PVGameLibrarySectionHeaderView

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
#if TARGET_OS_TV
		_titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, 0, [self bounds].size.width - 30, [self bounds].size.height)];
        [_titleLabel setTextAlignment:NSTextAlignmentLeft];
        [_titleLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleTitle1]];
#else
        [_titleLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
        UIView *topSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [self bounds].size.width, 0.5)];
        [topSeparator setBackgroundColor:[UIColor colorWithWhite:0.7 alpha:0.6]];
        [topSeparator setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [self addSubview:topSeparator];

        [self setBackgroundColor:[UIColor colorWithWhite:0.9 alpha:0.6]];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, [self bounds].size.width - 40, [self bounds].size.height)];
        [_titleLabel setTextAlignment:NSTextAlignmentCenter];

        UIView *bottomSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, [self bounds].size.height, [self bounds].size.width, 0.5)];
        [bottomSeparator setBackgroundColor:[UIColor colorWithWhite:0.7 alpha:0.6]];
        [bottomSeparator setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [self addSubview:bottomSeparator];
#endif
		[_titleLabel setNumberOfLines:0];
        [_titleLabel setTextColor:[self colorForText]];
		[_titleLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
		[self addSubview:_titleLabel];
	}
	
	return self;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [_titleLabel setTextColor:[self colorForText]];
}

- (UIColor *)colorForText
{
#if TARGET_OS_TV
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor lightGrayColor];
    }
#endif
    
    return [UIColor darkGrayColor];
}

- (void)prepareForReuse
{
	[super prepareForReuse];
	[_titleLabel setText:nil];
}

@end
