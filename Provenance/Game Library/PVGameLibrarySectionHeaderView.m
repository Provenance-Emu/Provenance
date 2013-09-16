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
		UIView *topSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [self bounds].size.width, 0.5)];
		[topSeparator setBackgroundColor:[UIColor colorWithWhite:0.7 alpha:0.6]];
		[self addSubview:topSeparator];
		
		[self setBackgroundColor:[UIColor colorWithWhite:0.9 alpha:0.6]];
		
		_titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, [self bounds].size.width - 40, [self bounds].size.height)];
		[_titleLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
		[_titleLabel setNumberOfLines:0];
		[_titleLabel setTextColor:[UIColor darkGrayColor]];
		[_titleLabel setTextAlignment:NSTextAlignmentCenter];
		[self addSubview:_titleLabel];
		
		UIView *bottomSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, [self bounds].size.height, [self bounds].size.width, 0.5)];
		[bottomSeparator setBackgroundColor:[UIColor colorWithWhite:0.7 alpha:0.6]];
		[self addSubview:bottomSeparator];
	}
	
	return self;
}

- (void)prepareForReuse
{
	[super prepareForReuse];
	[_titleLabel setText:nil];
}

@end
