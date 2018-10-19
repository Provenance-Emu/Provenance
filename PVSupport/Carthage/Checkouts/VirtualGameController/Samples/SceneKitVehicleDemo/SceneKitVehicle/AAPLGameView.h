/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A SceneKit view that handles touch events.
  
 */

#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>

@interface AAPLGameView : SCNView

@property NSUInteger touchCount;
@property BOOL inCarView;

@end
