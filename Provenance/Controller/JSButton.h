//
//  JSButton.h
//  Controller
//
//  Created by James Addyman on 29/03/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

@class JSButton;

@protocol JSButtonDelegate <NSObject>

- (void)buttonPressed:(JSButton *)button;
- (void)buttonReleased:(JSButton *)button;

@end

@interface JSButton : UIView

@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) UIImage *backgroundImagePressed;
@property (nonatomic, assign) UIEdgeInsets titleEdgeInsets;
@property (nonatomic, assign) BOOL pressed;

@property (nonatomic, weak) IBOutlet id <JSButtonDelegate> delegate;

@end
