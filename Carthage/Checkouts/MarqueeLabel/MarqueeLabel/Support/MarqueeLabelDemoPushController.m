//
//  MarqueeLabelDemoPushController.m
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 3/24/16.
//
//

#import "MarqueeLabelDemoPushController.h"

@implementation MarqueeLabelDemoPushController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Continuous Type
    self.demoLabel.marqueeType = MLContinuous;
    self.demoLabel.scrollDuration = 15.0;
    self.demoLabel.animationCurve = UIViewAnimationOptionCurveEaseInOut;
    self.demoLabel.fadeLength = 10.0f;
    self.demoLabel.leadingBuffer = 30.0f;
    self.demoLabel.trailingBuffer = 20.0f;
    
    NSArray *strings = @[@"When shall we three meet again in thunder, lightning, or in rain? When the hurlyburly's done, When the battle 's lost and won.",
                         @"I have no spur to prick the sides of my intent, but only vaulting ambition, which o'erleaps itself, and falls on the other.",
                         @"Double, double toil and trouble; Fire burn, and cauldron bubble.",
                         @"By the pricking of my thumbs, Something wicked this way comes.",
                         @"My favorite things in life don't cost any money. It's really clear that the most precious resource we all have is time.",
                         @"Be a yardstick of quality. Some people aren't used to an environment where excellence is expected."];
    
    self.demoLabel.text = strings[arc4random_uniform((int)strings.count)];
}
@end
