/*
 * Author: Moritz Haarmann <post@moritzhaarmann.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
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

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_FEEDBACK

#import "BITImageAnnotationViewController.h"
#import "BITImageAnnotation.h"
#import "BITRectangleImageAnnotation.h"
#import "BITArrowImageAnnotation.h"
#import "BITBlurImageAnnotation.h"
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"

typedef NS_ENUM(NSInteger, BITImageAnnotationViewControllerInteractionMode) {
  BITImageAnnotationViewControllerInteractionModeNone,
  BITImageAnnotationViewControllerInteractionModeDraw,
  BITImageAnnotationViewControllerInteractionModeMove
};

@interface BITImageAnnotationViewController ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UISegmentedControl *editingControls;
@property (nonatomic, strong) NSMutableArray *objects;

@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panRecognizer;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchRecognizer;

@property (nonatomic) CGFloat scaleFactor;

@property (nonatomic) CGPoint panStart;
@property (nonatomic,strong) BITImageAnnotation *currentAnnotation;

@property (nonatomic) BITImageAnnotationViewControllerInteractionMode currentInteraction;

@property (nonatomic) CGRect pinchStartingFrame;

@end

@implementation BITImageAnnotationViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
  
  NSArray *icons = @[@"Arrow.png",@"Rectangle.png", @"Blur.png"];
  
  self.editingControls = [[UISegmentedControl alloc] initWithItems:@[@"Rectangle", @"Arrow", @"Blur"]];
  int i=0;
  for (NSString *imageName in icons){
    [self.editingControls setImage:bit_imageNamed(imageName, BITHOCKEYSDK_BUNDLE) forSegmentAtIndex:i++];
  }
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [self.editingControls setSegmentedControlStyle:UISegmentedControlStyleBar];
#pragma clang diagnostic pop
  
  self.navigationItem.titleView = self.editingControls;
  
  self.objects = [NSMutableArray new];
  
  [self.editingControls addTarget:self action:@selector(editingAction:) forControlEvents:UIControlEventTouchUpInside];
  [self.editingControls setSelectedSegmentIndex:0];
  
  self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
  
  self.imageView.clipsToBounds = YES;
  
  self.imageView.image = self.image;
  self.imageView.contentMode = UIViewContentModeScaleToFill;
  
  self.view.frame = UIScreen.mainScreen.bounds;
  
  [self.view addSubview:self.imageView];
  // Erm.
  self.imageView.frame = [UIScreen mainScreen].bounds;
  
  self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
  self.pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinched:)];
  self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
  
  [self.imageView addGestureRecognizer:self.pinchRecognizer];
  [self.imageView addGestureRecognizer:self.panRecognizer];
  [self.view addGestureRecognizer:self.tapRecognizer];
  
  self.imageView.userInteractionEnabled = YES;
  
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc ] initWithImage:bit_imageNamed(@"Cancel.png", BITHOCKEYSDK_BUNDLE) landscapeImagePhone:bit_imageNamed(@"Cancel.png", BITHOCKEYSDK_BUNDLE) style:UIBarButtonItemStylePlain target:self action:@selector(discard:)];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc ] initWithImage:bit_imageNamed(@"Ok.png", BITHOCKEYSDK_BUNDLE) landscapeImagePhone:bit_imageNamed(@"Ok.png", BITHOCKEYSDK_BUNDLE) style:UIBarButtonItemStylePlain target:self action:@selector(save:)];
  
  self.view.autoresizesSubviews = NO;
}


- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
  
  [self fitImageViewFrame];
  
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (BOOL)prefersStatusBarHidden {
  return self.navigationController.navigationBarHidden || self.navigationController.navigationBar.alpha == 0;
}

- (void)orientationDidChange:(NSNotification *) __unused notification {
  [self fitImageViewFrame];
}


- (void)fitImageViewFrame {
  
  CGSize size = [UIScreen mainScreen].bounds.size;
  if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) && size.height > size.width){
    size = CGSizeMake(size.height, size.width);
  }
  
  CGFloat heightScaleFactor = size.height / self.image.size.height;
  CGFloat widthScaleFactor =  size.width / self.image.size.width;
  
  CGFloat factor = MIN(heightScaleFactor, widthScaleFactor);
  self.scaleFactor = factor;
  CGSize scaledImageSize = CGSizeMake(self.image.size.width * factor, self.image.size.height * factor);
  
  CGRect baseFrame = CGRectMake(self.view.frame.size.width/2 - scaledImageSize.width/2, self.view.frame.size.height/2 -  scaledImageSize.height/2, scaledImageSize.width, scaledImageSize.height);
  
  self.imageView.frame = baseFrame;
}

- (void)editingAction:(id) __unused sender {
  
}

- (BITImageAnnotation *)annotationForCurrentMode {
  if (self.editingControls.selectedSegmentIndex == 0){
    return [[BITArrowImageAnnotation alloc] initWithFrame:CGRectZero];
  } else if(self.editingControls.selectedSegmentIndex==1){
    return [[BITRectangleImageAnnotation alloc] initWithFrame:CGRectZero];
  } else {
    return [[BITBlurImageAnnotation alloc] initWithFrame:CGRectZero];
  }
}

#pragma mark - Actions

- (void)discard:(id) __unused sender {
  [self.delegate annotationControllerDidCancel:self];
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)save:(id) __unused sender {
  UIImage *image = [self extractImage];
  [self.delegate annotationController:self didFinishWithImage:image];
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIImage *)extractImage {
  UIGraphicsBeginImageContextWithOptions(self.image.size, YES, 0.0);
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  [self.image drawInRect:CGRectMake(0, 0, self.image.size.width, self.image.size.height)];
  CGContextScaleCTM(ctx,((CGFloat)1.0)/self.scaleFactor,((CGFloat)1.0)/self.scaleFactor);
  
  // Drawing all the annotations onto the final image.
  for (BITImageAnnotation *annotation in self.objects){
    CGContextTranslateCTM(ctx, annotation.frame.origin.x, annotation.frame.origin.y);
    [annotation.layer renderInContext:ctx];
    CGContextTranslateCTM(ctx,-1 * annotation.frame.origin.x,-1 *  annotation.frame.origin.y);
  }
  
  UIImage *renderedImageOfMyself = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return renderedImageOfMyself;
}

#pragma mark - UIGestureRecognizers

- (void)panned:(UIPanGestureRecognizer *)gestureRecognizer {
  BITImageAnnotation *annotationAtLocation = (BITImageAnnotation *)[self.view hitTest:[gestureRecognizer locationInView:self.view] withEvent:nil];
  
  if (![annotationAtLocation isKindOfClass:[BITImageAnnotation class]]){
    annotationAtLocation = nil;
  }
  
  // determine the interaction mode if none is set so far.
  
  if (self.currentInteraction == BITImageAnnotationViewControllerInteractionModeNone){
    if (annotationAtLocation){
      self.currentInteraction = BITImageAnnotationViewControllerInteractionModeMove;
    } else if ([self canDrawNewAnnotation]){
      self.currentInteraction = BITImageAnnotationViewControllerInteractionModeDraw;
    }
  }
  
  if (self.currentInteraction == BITImageAnnotationViewControllerInteractionModeNone){
    return;
  }
  
  
  if (self.currentInteraction == BITImageAnnotationViewControllerInteractionModeDraw){
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
      self.currentAnnotation = [self annotationForCurrentMode];
      [self.objects addObject:self.currentAnnotation];
      self.currentAnnotation.sourceImage = self.image;
      
      if (self.imageView.subviews.count > 0 && [self.currentAnnotation isKindOfClass:[BITBlurImageAnnotation class]]){
        [self.imageView insertSubview:self.currentAnnotation belowSubview:[self firstAnnotationThatIsNotBlur]];
      } else {
        [self.imageView addSubview:self.currentAnnotation];
      }
      
      self.panStart = [gestureRecognizer locationInView:self.imageView];
      
    } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged){
      CGPoint bla = [gestureRecognizer locationInView:self.imageView];
      self.currentAnnotation.frame = CGRectMake(self.panStart.x, self.panStart.y, bla.x - self.panStart.x, bla.y - self.panStart.y);
      self.currentAnnotation.movedDelta = CGSizeMake(bla.x - self.panStart.x, bla.y - self.panStart.y);
      self.currentAnnotation.imageFrame = [self.view convertRect:self.imageView.frame toView:self.currentAnnotation];
      [self.currentAnnotation setNeedsLayout];
      [self.currentAnnotation layoutIfNeeded];
    } else {
      [self.currentAnnotation setSelected:NO];
      self.currentAnnotation = nil;
      self.currentInteraction = BITImageAnnotationViewControllerInteractionModeNone;
    }
  } else if (self.currentInteraction == BITImageAnnotationViewControllerInteractionModeMove){
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
      // find and possibly move an existing annotation.
      
      
      if ([self.objects indexOfObject:annotationAtLocation] != NSNotFound){
        self.currentAnnotation = annotationAtLocation;
        [annotationAtLocation setSelected:YES];
      }
      
      
    } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged && self.currentAnnotation){
      CGPoint delta = [gestureRecognizer translationInView:self.view];
      
      CGRect annotationFrame = self.currentAnnotation.frame;
      annotationFrame.origin.x += delta.x;
      annotationFrame.origin.y += delta.y;
      self.currentAnnotation.frame = annotationFrame;
      self.currentAnnotation.imageFrame = [self.view convertRect:self.imageView.frame toView:self.currentAnnotation];
      
      [self.currentAnnotation setNeedsLayout];
      [self.currentAnnotation layoutIfNeeded];
      
      [gestureRecognizer setTranslation:CGPointZero inView:self.view];
      
    } else {
      [self.currentAnnotation setSelected:NO];
      self.currentAnnotation = nil;
      self.currentInteraction = BITImageAnnotationViewControllerInteractionModeNone;
    }
  }
}

- (void)pinched:(UIPinchGestureRecognizer *)gestureRecognizer {
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
    // try to figure out which view we are talking about.
    BITImageAnnotation *candidate = nil;
    BOOL validView = YES;
    
    for (uint i = 0; i < gestureRecognizer.numberOfTouches; i++){
      BITImageAnnotation *newCandidate = (BITImageAnnotation *)[self.view hitTest:[gestureRecognizer locationOfTouch:i inView:self.view] withEvent:nil];
      
      if (![newCandidate isKindOfClass:[BITImageAnnotation class]]){
        newCandidate = nil;
      }
      
      if (candidate == nil){
        candidate = newCandidate;
      } else if (candidate != newCandidate){
        validView = NO;
        break;
      }
    }
    
    if (validView && [candidate resizable]){
      self.currentAnnotation = candidate;
      self.pinchStartingFrame = self.currentAnnotation.frame;
      [self.currentAnnotation setSelected:YES];
    }
    
  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged && self.currentAnnotation && gestureRecognizer.numberOfTouches>1){
    CGRect newFrame= (self.pinchStartingFrame);
    
    // upper point?
    CGPoint point1 = [gestureRecognizer locationOfTouch:0 inView:self.view];
    CGPoint point2 = [gestureRecognizer locationOfTouch:1 inView:self.view];
    
    
    newFrame.origin.x = point1.x;
    newFrame.origin.y = point1.y;
    
    newFrame.origin.x = (point1.x > point2.x) ? point2.x : point1.x;
    newFrame.origin.y = (point1.y > point2.y) ? point2.y : point1.y;
    
    newFrame.size.width = (point1.x > point2.x) ? point1.x - point2.x : point2.x - point1.x;
    newFrame.size.height = (point1.y > point2.y) ? point1.y - point2.y : point2.y - point1.y;
    
    
    self.currentAnnotation.frame = newFrame;
    self.currentAnnotation.imageFrame = [self.view convertRect:self.imageView.frame toView:self.currentAnnotation];
  } else {
    [self.currentAnnotation setSelected:NO];
    self.currentAnnotation = nil;
  }
}

- (void)tapped:(UIGestureRecognizer *) __unused tapRecognizer {
  
  // TODO: remove pre-iOS 8 code.
  
  // This toggles the nav and status bar. Since iOS7 and pre-iOS7 behave weirdly different,
  // this might look rather hacky, but hiding the navbar under iOS6 leads to some ugly
  // animation effect which is avoided by simply hiding the navbar setting it's alpha to 0. // moritzh
  
  if (self.navigationController.navigationBar.alpha == 0 || self.navigationController.navigationBarHidden ){
    
    [UIView animateWithDuration:0.35 animations:^{
      [self.navigationController setNavigationBarHidden:NO animated:NO];
      
      if ([self respondsToSelector:@selector(prefersStatusBarHidden)]) {
        [self setNeedsStatusBarAppearanceUpdate];
      } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
#pragma clang diagnostic pop
      }
      
    } completion:^(BOOL __unused finished) {
      [self fitImageViewFrame];
      
    }];
  } else {
    [UIView animateWithDuration:0.35 animations:^{
      [self.navigationController setNavigationBarHidden:YES animated:NO];
      
      if ([self respondsToSelector:@selector(prefersStatusBarHidden)]) {
        [self setNeedsStatusBarAppearanceUpdate];
      } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
#pragma clang diagnostic pop
      }
      
    } completion:^(BOOL __unused finished) {
      [self fitImageViewFrame];
      
    }];
  }
  
}

#pragma mark - Helpers

- (UIView *)firstAnnotationThatIsNotBlur {
  for (BITImageAnnotation *annotation in self.imageView.subviews){
    if (![annotation isKindOfClass:[BITBlurImageAnnotation class]]){
      return annotation;
    }
  }
  
  return self.imageView;
}

- (BOOL)canDrawNewAnnotation {
  return [self.editingControls selectedSegmentIndex] != UISegmentedControlNoSegment;
}
@end

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
