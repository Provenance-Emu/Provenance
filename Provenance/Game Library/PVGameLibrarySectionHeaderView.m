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
		_titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, [self bounds].size.width - 40, [self bounds].size.height)];
		[_titleLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
		[_titleLabel setNumberOfLines:0];
		[_titleLabel setTextColor:[UIColor colorWithRed:0.00 green:0.48 blue:1.00 alpha:1.0]];
		[self addSubview:_titleLabel];
	}
	
	return self;
}

- (void)prepareForReuse
{
	[super prepareForReuse];
	[_titleLabel setText:nil];
}

@end
