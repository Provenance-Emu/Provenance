/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 */

#import <SpriteKit/SpriteKit.h>
#import "AAPLGameView.h"

@implementation AAPLGameView

- (void)changePointOfView
{
    // retrieve the list of point of views
    NSArray *pointOfViews = [self.scene.rootNode childNodesPassingTest:^BOOL(SCNNode *child, BOOL *stop) {
        return child.camera != nil;
    }];
    
    SCNNode *currentPointOfView = self.pointOfView;
    
    // select the next one
    NSUInteger index = [pointOfViews indexOfObject:currentPointOfView];
    index++;
    if (index >= [pointOfViews count]) index = 0;
    
    self.inCarView = (index==0);
    
    // set it with an implicit transaction
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.75];
    self.pointOfView = [pointOfViews objectAtIndex:index];
    [SCNTransaction commit];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    //test if we hit the camera button
    SKScene *scene = self.overlaySKScene;
    CGPoint p = [touch locationInView:self];
    p = [scene convertPointFromView:p];
    SKNode *node = [scene nodeAtPoint:p];
    
    if ([node.name isEqualToString:@"camera"]) {
        //play a sound
        [node runAction:[SKAction playSoundFileNamed:@"click.caf" waitForCompletion:NO]];
        
        //change the point of view
        [self changePointOfView];
        return;
    }
    
    //update the total number of touches on screen
    NSSet *allTouches = [event allTouches];
    _touchCount = [allTouches count];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    _touchCount = 0;
}

@end
