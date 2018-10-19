/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A view controller that conforms to SCNSceneRendererDelegate and implements the game logic.
  
 */

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <SpriteKit/SpriteKit.h>
#import <SceneKit/SceneKit.h>

@interface AAPLGameViewController : UIViewController <SCNSceneRendererDelegate, SCNPhysicsContactDelegate>

@end
