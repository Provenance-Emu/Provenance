//
//  JSDPad.m
//  Controller
//
//  Created by James Addyman on 28/03/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "JSDPad.h"

@interface JSDPad () {
	
	JSDPadDirection _currentDirection;
	
	UIImageView *_dPadImageView;
	
}

@end

@implementation JSDPad

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
	_dPadImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"dPad-None"]];
	[_dPadImageView setFrame:CGRectMake(0, 0, [self bounds].size.width, [self bounds].size.height)];
	[self addSubview:_dPadImageView];
	
	_currentDirection = JSDPadDirectionNone;
}

- (void)dealloc
{
	self.delegate = nil;
}

- (JSDPadDirection)currentDirection
{
	return _currentDirection;
}

- (JSDPadDirection)directionForPoint:(CGPoint)point
{
	CGFloat x = point.x;
	CGFloat y = point.y;
	
	if (((x < 0) || (x > [self bounds].size.width)) ||
		((y < 0) || (y > [self bounds].size.height)))
	{
		return JSDPadDirectionNone;
	}
	
	NSUInteger column = x / ([self bounds].size.width / 3);
	NSUInteger row = y / ([self bounds].size.height / 3);

	JSDPadDirection direction = (row * 3) + column + 1;
	
	return direction;
}

- (UIImage *)imageForDirection:(JSDPadDirection)direction
{
	UIImage *image = nil;
	
	switch (direction) {
		case JSDPadDirectionNone:
			image = [UIImage imageNamed:@"dPad-None"];
			break;
		case JSDPadDirectionUp:
			image = [UIImage imageNamed:@"dPad-Up"];
			break;
		case JSDPadDirectionDown:
			image = [UIImage imageNamed:@"dPad-Down"];
			break;
		case JSDPadDirectionLeft:
			image = [UIImage imageNamed:@"dPad-Left"];
			break;
		case JSDPadDirectionRight:
			image = [UIImage imageNamed:@"dPad-Right"];
			break;
		case JSDPadDirectionUpLeft:
			image = [UIImage imageNamed:@"dPad-UpLeft"];
			break;
		case JSDPadDirectionUpRight:
			image = [UIImage imageNamed:@"dPad-UpRight"];
			break;
		case JSDPadDirectionDownLeft:
			image = [UIImage imageNamed:@"dPad-DownLeft"];
			break;
		case JSDPadDirectionDownRight:
			image = [UIImage imageNamed:@"dPad-DownRight"];
			break;
		default:
			image = [UIImage imageNamed:@"dPad-None"];
			break;
	}
	
	return image;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	
	JSDPadDirection direction = [self directionForPoint:point];
	
	if (direction != _currentDirection)
	{
		_currentDirection = direction;
		
		[_dPadImageView setImage:[self imageForDirection:_currentDirection]];
		
		if ([self.delegate respondsToSelector:@selector(dPad:didPressDirection:)])
		{
			[self.delegate dPad:self didPressDirection:_currentDirection];
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	
	JSDPadDirection direction = [self directionForPoint:point];
	
	if (direction != _currentDirection)
	{
		_currentDirection = direction;
		[_dPadImageView setImage:[self imageForDirection:_currentDirection]];
		
		if ([self.delegate respondsToSelector:@selector(dPad:didPressDirection:)])
		{
			[self.delegate dPad:self didPressDirection:_currentDirection];
		}
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	_currentDirection = JSDPadDirectionNone;
	[_dPadImageView setImage:[self imageForDirection:_currentDirection]];
	
	if ([self.delegate respondsToSelector:@selector(dPadDidReleaseDirection:)])
	{
		[self.delegate dPadDidReleaseDirection:self];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	_currentDirection = JSDPadDirectionNone;
	[_dPadImageView setImage:[self imageForDirection:_currentDirection]];
	
	if ([self.delegate respondsToSelector:@selector(dPadDidReleaseDirection:)])
	{
		[self.delegate dPadDidReleaseDirection:self];
	}
}

@end
