//
//  JSButton.m
//  Controller
//
//  Created by James Addyman on 29/03/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "JSButton.h"

@interface JSButton () {
	
	UIImageView *_backgroundImageView;
	
}

@end

@implementation JSButton

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		[self commonInit];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]))
	{
		[self commonInit];
	}
	
	return self;
}

- (void)commonInit
{	
	_backgroundImageView = [[UIImageView alloc] initWithImage:self.backgroundImage];
	[_backgroundImageView setFrame:[self bounds]];
	[_backgroundImageView setContentMode:UIViewContentModeCenter];
	[_backgroundImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[self addSubview:_backgroundImageView];
	
	_titleLabel = [[UILabel alloc] init];
	[_titleLabel setBackgroundColor:[UIColor clearColor]];
	[_titleLabel setTextColor:[UIColor whiteColor]];
	[_titleLabel setShadowColor:[UIColor darkGrayColor]];
	[_titleLabel setShadowOffset:CGSizeMake(0, 1)];
	[_titleLabel setFont:[UIFont boldSystemFontOfSize:15]];
	[_titleLabel setFrame:[self bounds]];
	[_titleLabel setTextAlignment:NSTextAlignmentCenter];
	[_titleLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[self addSubview: _titleLabel];
	
	[self addObserver:self
		   forKeyPath:@"pressed"
			  options:NSKeyValueObservingOptionNew
			  context:NULL];
	
	[self addObserver:self
		   forKeyPath:@"backgroundImage"
			  options:NSKeyValueObservingOptionNew
			  context:NULL];
	
	[self addObserver:self
		   forKeyPath:@"backgroundImagePressed"
			  options:NSKeyValueObservingOptionNew
			  context:NULL];
	
	self.pressed = NO;
}

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"pressed"];
	[self removeObserver:self forKeyPath:@"backgroundImage"];
	[self removeObserver:self forKeyPath:@"backgroundImagePressed"];
	self.delegate = nil;
}

- (void)setEnabled:(BOOL)enabled
{
	[self setUserInteractionEnabled:enabled];
}

- (void)setTitleEdgeInsets:(UIEdgeInsets)titleEdgeInsets
{
	_titleEdgeInsets = titleEdgeInsets;
	[self setNeedsLayout];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	[_backgroundImageView setFrame:[self bounds]];
	[_titleLabel setFrame:[self bounds]];
	
	CGRect frame = [_titleLabel frame];
	frame.origin.x += _titleEdgeInsets.left;
	frame.origin.y += _titleEdgeInsets.top;
	frame.size.width -= _titleEdgeInsets.right;
	frame.size.height -= _titleEdgeInsets.bottom;
	[_titleLabel setFrame:frame];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"pressed"] ||
		[keyPath isEqualToString:@"backgroundImage"] ||
		[keyPath isEqualToString:@"backgroundImagePressed"])
	{
		if (_pressed)
		{
			[_backgroundImageView setImage:self.backgroundImagePressed];
		}
		else
		{
			[_backgroundImageView setImage:self.backgroundImage];
		}
	}
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self.delegate respondsToSelector:@selector(buttonPressed:)])
	{
		[self.delegate buttonPressed:self];
	}
    
    self.pressed = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:[self superview]];
    CGRect touchArea = CGRectMake(point.x - 10, point.y - 10, 20, 20);

    BOOL pressed = _pressed;
    
	if (!pressed)
	{
		pressed = YES;
		if ([self.delegate respondsToSelector:@selector(buttonPressed:)])
		{
			[self.delegate buttonPressed:self];
		}
	}

    if (!CGRectIntersectsRect(touchArea, [self frame]))
	{
		if (pressed)
		{
			pressed = NO;
			if ([self.delegate respondsToSelector:@selector(buttonReleased:)])
			{
				[self.delegate buttonReleased:self];
			}
		}
	}
    
    self.pressed = pressed;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self.delegate respondsToSelector:@selector(buttonReleased:)])
	{
		[self.delegate buttonReleased:self];
	}
    
    self.pressed = NO;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self.delegate respondsToSelector:@selector(buttonReleased:)])
	{
		[self.delegate buttonReleased:self];
	}
    
    self.pressed = NO;
}

@end
