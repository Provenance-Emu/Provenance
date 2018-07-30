/**
 * Copyright (c) 2014 Charles Powell
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

//
//  MarqueeLabelDemoViewController.h
//  MarqueeLabelDemo
//

#import <UIKit/UIKit.h>
#import "MarqueeLabel.h"

@interface MarqueeLabelDemoViewController : UIViewController

@property (nonatomic, weak) IBOutlet MarqueeLabel *demoLabel1;
@property (nonatomic, weak) IBOutlet MarqueeLabel *demoLabel2;
@property (nonatomic, weak) IBOutlet MarqueeLabel *demoLabel3;
@property (nonatomic, weak) IBOutlet MarqueeLabel *demoLabel4;
@property (nonatomic, weak) IBOutlet MarqueeLabel *demoLabel5;
@property (nonatomic, weak) IBOutlet MarqueeLabel *demoLabel6;

@property (nonatomic, weak) IBOutlet UISwitch *labelizeSwitch;
@property (nonatomic, weak) IBOutlet UISwitch *holdLabelsSwitch;

- (IBAction)changeLabelTexts:(id)sender;
- (IBAction)labelizeSwitched:(id)sender;
- (IBAction)holdLabelsSwitched:(id)sender;
- (IBAction)togglePause:(id)sender;
- (IBAction)unwindModalPopoverSegue:(UIStoryboardSegue *)segue;

@end

