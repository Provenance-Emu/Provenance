/*

 Copyright (c) 2013 Joan Lluch <joan.lluch@sweetwilliamsl.com>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is furnished
 to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.

 Early code inspired on a similar class by Philip Kluz (Philip.Kluz@zuui.org)
 
*/

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#import "SWRevealViewController.h"

#pragma mark - SWDirectionPanGestureRecognizer

typedef enum
{
    SWDirectionPanGestureRecognizerVertical,
    SWDirectionPanGestureRecognizerHorizontal

} SWDirectionPanGestureRecognizerDirection;

@interface SWDirectionPanGestureRecognizer : UIPanGestureRecognizer

@property (nonatomic, assign) SWDirectionPanGestureRecognizerDirection direction;

@end


@implementation SWDirectionPanGestureRecognizer
{
    BOOL _dragging;
    CGPoint _init;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
   
    UITouch *touch = [touches anyObject];
    _init = [touch locationInView:self.view];
    _dragging = NO;
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    
    if (self.state == UIGestureRecognizerStateFailed)
        return;
    
    if ( _dragging )
        return;
    
    const int kDirectionPanThreshold = 5;
    
    UITouch *touch = [touches anyObject];
    CGPoint nowPoint = [touch locationInView:self.view];
    
    CGFloat moveX = nowPoint.x - _init.x;
    CGFloat moveY = nowPoint.y - _init.y;
    
    if (abs(moveX) > kDirectionPanThreshold)
    {
        if (_direction == SWDirectionPanGestureRecognizerHorizontal)
            _dragging = YES;
        else
            self.state = UIGestureRecognizerStateFailed;
    }
    else if (abs(moveY) > kDirectionPanThreshold)
    {
        if (_direction == SWDirectionPanGestureRecognizerVertical)
            _dragging = YES ;
        else
            self.state = UIGestureRecognizerStateFailed;
    }
}

@end


#pragma mark - StatusBar Helper Function

// computes the required offset adjustment due to the status bar for the passed in view,
// it will return the statusBar height if view fully overlaps the statusBar, otherwise returns 0.0f
static CGFloat statusBarAdjustment( UIView* view )
{
    CGFloat adjustment = 0.0f;
    CGRect viewFrame = [view convertRect:view.bounds toView:nil];

#if !TARGET_OS_TV
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    
    if ( CGRectContainsRect(viewFrame, statusBarFrame) )
        adjustment = fminf(statusBarFrame.size.width, statusBarFrame.size.height);

#endif
	return adjustment;
}


#pragma mark - SWRevealView Class

@interface SWRevealView: UIView
{
    __weak SWRevealViewController *_c;
}

@property (nonatomic, readonly) UIView *rearView;
@property (nonatomic, readonly) UIView *rightView;
@property (nonatomic, readonly) UIView *frontView;
@property (nonatomic, assign) BOOL disableLayout;

@end


@interface SWRevealViewController()
- (void)_getRevealWidth:(CGFloat*)pRevealWidth revealOverDraw:(CGFloat*)pRevealOverdraw forSymetry:(int)symetry;
- (void)_getBounceBack:(BOOL*)pBounceBack pStableDrag:(BOOL*)pStableDrag forSymetry:(int)symetry;
- (void)_getAdjustedFrontViewPosition:(FrontViewPosition*)frontViewPosition forSymetry:(int)symetry;
@end


@implementation SWRevealView


static CGFloat scaledValue( CGFloat v1, CGFloat min2, CGFloat max2, CGFloat min1, CGFloat max1)
{
    CGFloat result = min2 + (v1-min1)*((max2-min2)/(max1-min1));
    if ( result != result ) return min2;  // nan
    if ( result < min2 ) return min2;
    if ( result > max2 ) return max2;
    return result;
}

- (id)initWithFrame:(CGRect)frame controller:(SWRevealViewController*)controller
{
    self = [super initWithFrame:frame];
    if ( self )
    {
        _c = controller;
        CGRect bounds = self.bounds;
    
        _frontView = [[UIView alloc] initWithFrame:bounds];
        _frontView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

        [self addSubview:_frontView];

        CALayer *frontViewLayer = _frontView.layer;
        frontViewLayer.masksToBounds = NO;
        frontViewLayer.shadowColor = [UIColor blackColor].CGColor;
        //frontViewLayer.shadowOpacity = 1.0f;
        frontViewLayer.shadowOpacity = _c.frontViewShadowOpacity;
        frontViewLayer.shadowOffset = _c.frontViewShadowOffset;
        frontViewLayer.shadowRadius = _c.frontViewShadowRadius;
    }
    
    return self;
}


- (CGRect)hierarchycalFrameAdjustment:(CGRect)frame
{
    if ( _c.presentFrontViewHierarchically )
    {
        CGFloat offset = 44 + statusBarAdjustment(self);
        frame.origin.y += offset;
        frame.size.height -= offset;
    }
    return frame;
}

- (void)layoutSubviews
{
    if ( _disableLayout ) return;

    CGRect bounds = self.bounds;
    
    CGFloat xLocation = [self frontLocationForPosition:_c.frontViewPosition];
    
    [self _layoutRearViewsForLocation:xLocation];
    
    CGRect frame = CGRectMake(xLocation, 0.0f, bounds.size.width, bounds.size.height);
    _frontView.frame = [self hierarchycalFrameAdjustment:frame];
    
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:_frontView.bounds];
    _frontView.layer.shadowPath = shadowPath.CGPath;
}


- (void)prepareRearViewForPosition:(FrontViewPosition)newPosition
{
    if ( _rearView == nil )
    {
        _rearView = [[UIView alloc] initWithFrame:self.bounds];
        _rearView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self insertSubview:_rearView belowSubview:_frontView];
    }
    
    CGFloat xLocation = [self frontLocationForPosition:_c.frontViewPosition];
    [self _layoutRearViewsForLocation:xLocation];
    [self _prepareForNewPosition:newPosition];
}


- (void)prepareRightViewForPosition:(FrontViewPosition)newPosition
{
    if ( _rightView == nil )
    {
        _rightView = [[UIView alloc] initWithFrame:self.bounds];
        _rightView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self insertSubview:_rightView belowSubview:_frontView];
    }
    
    CGFloat xLocation = [self frontLocationForPosition:_c.frontViewPosition];
    [self _layoutRearViewsForLocation:xLocation];
    [self _prepareForNewPosition:newPosition];
}


- (CGFloat)frontLocationForPosition:(FrontViewPosition)frontViewPosition
{
    CGFloat revealWidth;
    CGFloat revealOverdraw;
    
    CGFloat location = 0.0f;
    
    int symetry = frontViewPosition<FrontViewPositionLeft? -1 : 1;
    [_c _getRevealWidth:&revealWidth revealOverDraw:&revealOverdraw forSymetry:symetry];
    [_c _getAdjustedFrontViewPosition:&frontViewPosition forSymetry:symetry];
    
    if ( frontViewPosition == FrontViewPositionRight )
        location = revealWidth;
    
    else if ( frontViewPosition > FrontViewPositionRight )
        location = revealWidth + revealOverdraw;

    return location*symetry;
}


- (void)dragFrontViewToXLocation:(CGFloat)xLocation
{
    CGRect bounds = self.bounds;
    
    xLocation = [self _adjustedDragLocationForLocation:xLocation];
    [self _layoutRearViewsForLocation:xLocation];
    
    CGRect frame = CGRectMake(xLocation, 0.0f, bounds.size.width, bounds.size.height);
    _frontView.frame = [self hierarchycalFrameAdjustment:frame];
}


# pragma mark private


- (void)_layoutRearViewsForLocation:(CGFloat)xLocation
{
    CGRect bounds = self.bounds;
    
    CGFloat rearRevealWidth = _c.rearViewRevealWidth;
    if ( rearRevealWidth < 0) rearRevealWidth = bounds.size.width + _c.rearViewRevealWidth;
    
    CGFloat rearXLocation = scaledValue(xLocation, -_c.rearViewRevealDisplacement, 0, 0, rearRevealWidth);
    
    CGFloat rearWidth = rearRevealWidth + _c.rearViewRevealOverdraw;
    _rearView.frame = CGRectMake(rearXLocation, 0.0, rearWidth, bounds.size.height);
    
    CGFloat rightRevealWidth = _c.rightViewRevealWidth;
    if ( rightRevealWidth < 0) rightRevealWidth = bounds.size.width + _c.rightViewRevealWidth;
    
    CGFloat rightXLocation = scaledValue(xLocation, 0, _c.rightViewRevealDisplacement, -rightRevealWidth, 0);
    
    CGFloat rightWidth = rightRevealWidth + _c.rightViewRevealOverdraw;
    _rightView.frame = CGRectMake(bounds.size.width-rightWidth+rightXLocation, 0.0f, rightWidth, bounds.size.height);
}


- (void)_prepareForNewPosition:(FrontViewPosition)newPosition;
{
    if ( _rearView == nil || _rightView == nil )
        return;
    
    int symetry = newPosition<FrontViewPositionLeft? -1 : 1;

    NSArray *subViews = self.subviews;
    NSInteger rearIndex = [subViews indexOfObjectIdenticalTo:_rearView];
    NSInteger rightIndex = [subViews indexOfObjectIdenticalTo:_rightView];
    
    if ( (symetry < 0 && rightIndex < rearIndex) || (symetry > 0 && rearIndex < rightIndex) )
        [self exchangeSubviewAtIndex:rightIndex withSubviewAtIndex:rearIndex];
}


- (CGFloat)_adjustedDragLocationForLocation:(CGFloat)x
{
    CGFloat result;
    
    CGFloat revealWidth;
    CGFloat revealOverdraw;
    BOOL bounceBack;
    BOOL stableDrag;
    FrontViewPosition position = _c.frontViewPosition;
    
    int symetry = x<0 ? -1 : 1;
    
    [_c _getRevealWidth:&revealWidth revealOverDraw:&revealOverdraw forSymetry:symetry];
    [_c _getBounceBack:&bounceBack pStableDrag:&stableDrag forSymetry:symetry];
    
    BOOL stableTrack = !bounceBack || stableDrag || position==FrontViewPositionRightMost || position==FrontViewPositionLeftSideMost;
    if ( stableTrack )
    {
        revealWidth += revealOverdraw;
        revealOverdraw = 0.0f;
    }
    
    x = x * symetry;
    
    if (x <= revealWidth)
        result = x;         // Translate linearly.

    else if (x <= revealWidth+2*revealOverdraw)
        result = revealWidth + (x-revealWidth)/2;   // slow down translation by halph the movement.

    else
        result = revealWidth+revealOverdraw;        // keep at the rightMost location.
    
    return result * symetry;
}

@end


#pragma mark - SWRevealViewController Class

@interface SWRevealViewController()<UIGestureRecognizerDelegate>
{
    SWRevealView *_contentView;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UITapGestureRecognizer *_tapGestureRecognizer;
    FrontViewPosition _frontViewPosition;
    FrontViewPosition _rearViewPosition;
    FrontViewPosition _rightViewPosition;
}
@end


@implementation SWRevealViewController
{
    FrontViewPosition _panInitialFrontPosition;
    NSMutableArray *_animationQueue;
    BOOL _userInteractionStore;
}

const int FrontViewPositionNone = 0xff;


#pragma mark - Init

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if ( self )
    {
        [self _initDefaultProperties];
    }    
    return self;
}


- (id)init
{
    return [self initWithRearViewController:nil frontViewController:nil];
}


- (id)initWithRearViewController:(UIViewController *)rearViewController frontViewController:(UIViewController *)frontViewController;
{
    self = [super init];
    if ( self )
    {
        [self _initDefaultProperties];
        [self _setRearViewController:rearViewController];
        [self _setFrontViewController:frontViewController];
    }
    return self;
}


- (void)_initDefaultProperties
{
    _frontViewPosition = FrontViewPositionLeft;
    _rearViewPosition = FrontViewPositionLeft;
    _rightViewPosition = FrontViewPositionLeft;
    _rearViewRevealWidth = 260.0f;
    _rearViewRevealOverdraw = 60.0f;
    _rearViewRevealDisplacement = 40.0f;
    _rightViewRevealWidth = 260.0f;
    _rightViewRevealOverdraw = 60.0f;
    _rightViewRevealDisplacement = 40.0f;
    _bounceBackOnOverdraw = YES;
    _bounceBackOnLeftOverdraw = YES;
    _stableDragOnOverdraw = NO;
    _stableDragOnLeftOverdraw = NO;
    _presentFrontViewHierarchically = NO;
    _quickFlickVelocity = 250.0f;
    _toggleAnimationDuration = 0.25;
    _frontViewShadowRadius = 2.5f;
    _frontViewShadowOffset = CGSizeMake(0.0f, 2.5f);
    _frontViewShadowOpacity = 1.0f;
    _userInteractionStore = YES;
    _animationQueue = [NSMutableArray array];
    _draggableBorderWidth = 0.0f;
}


#pragma mark Storyboard support

static NSString * const SWSegueRearIdentifier = @"sw_rear";
static NSString * const SWSegueFrontIdentifier = @"sw_front";
static NSString * const SWSegueRightIdentifier = @"sw_right";

- (void)prepareForSegue:(SWRevealViewControllerSegue *)segue sender:(id)sender
{
    // $ using a custom segue we can get access to the storyboard-loaded rear/front view controllers
    // the trick is to define segues of type SWRevealViewControllerSegue on the storyboard
    // connecting the SWRevealViewController to the desired front/rear controllers,
    // and setting the identifiers to "sw_rear" and "sw_front"
    
    // $ these segues are invoked manually in the loadView method if a storyboard
    // was used to instantiate the SWRevealViewController
    
    // $ none of this would be necessary if Apple exposed "relationship" segues for container view controllers.

    NSString *identifier = segue.identifier;
    if ( [segue isKindOfClass:[SWRevealViewControllerSegue class]] && sender == nil )
    {
        if ( [identifier isEqualToString:SWSegueRearIdentifier] )
        {
            segue.performBlock = ^(SWRevealViewControllerSegue* rvc_segue, UIViewController* svc, UIViewController* dvc)
            {
                [self _setRearViewController:dvc];
            };
        }
        else if ( [identifier isEqualToString:SWSegueFrontIdentifier] )
        {
            segue.performBlock = ^(SWRevealViewControllerSegue* rvc_segue, UIViewController* svc, UIViewController* dvc)
            {
                [self _setFrontViewController:dvc];
            };
        }
        else if ( [identifier isEqualToString:SWSegueRightIdentifier] )
        {
            segue.performBlock = ^(SWRevealViewControllerSegue* rvc_segue, UIViewController* svc, UIViewController* dvc)
            {
                [self _setRightViewController:dvc];
            };
        }
    }
}

// Load any defined front/rear controllers from the storyboard
// This method is intended to be overrided in case the default behavior will not meet your needs
- (void)loadStoryboardControllers
{
    if ( self.storyboard && _rearViewController == nil )
    {
        //Try each segue separately so it doesn't break prematurely if either Rear or Right views are not used.
        @try
        {
            [self performSegueWithIdentifier:SWSegueRearIdentifier sender:nil];
        }
        @catch(NSException *exception) {}
        
        @try
        {
            [self performSegueWithIdentifier:SWSegueFrontIdentifier sender:nil];
        }
        @catch(NSException *exception) {}
        
        @try
        {
            [self performSegueWithIdentifier:SWSegueRightIdentifier sender:nil];
        }
        @catch(NSException *exception) {}
    }
}


#pragma mark - StatusBar

- (UIViewController *)childViewControllerForStatusBarStyle
{
    int positionDif =  _frontViewPosition - FrontViewPositionLeft;
    
    UIViewController *controller = _frontViewController;
    if ( positionDif > 0 ) controller = _rearViewController;
    else if ( positionDif < 0 ) controller = _rightViewController;
    
    return controller;
}

- (UIViewController *)childViewControllerForStatusBarHidden
{
    UIViewController *controller = [self childViewControllerForStatusBarStyle];
    return controller;
}

#pragma mark - View lifecycle

- (void)loadView
{
    // Do not call super, to prevent the apis from unfruitful looking for inexistent xibs!
    
    // This is what Apple tells us to set as the initial frame, which is of course totally irrelevant
    // with the modern view controller containment patterns, let's leave it for the sake of it!
    //CGRect frame = [[UIScreen mainScreen] applicationFrame];
    
    // On iOS7 the applicationFrame does not return the whole screen. This is possibly a bug.
    // As a workaround we use the screen bounds, this still works on iOS6
    CGRect frame = [[UIScreen mainScreen] bounds];

    // create a custom content view for the controller
    _contentView = [[SWRevealView alloc] initWithFrame:frame controller:self];
    
    // set the content view to resize along with its superview
     [_contentView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];

    // set our contentView to the controllers view
    self.view = _contentView;
    
    // load any defined front/rear controllers from the storyboard
    [self loadStoryboardControllers];
    
    // Apple also tells us to do this:
    _contentView.backgroundColor = [UIColor blackColor];
    
    // we set the current frontViewPosition to none before seting the
    // desired initial position, this will force proper controller reload
    FrontViewPosition initialPosition = _frontViewPosition;
    _frontViewPosition = FrontViewPositionNone;
    _rearViewPosition = FrontViewPositionNone;
    _rightViewPosition = FrontViewPositionNone;
    
    // now set the desired initial position
    [self _setFrontViewPosition:initialPosition withDuration:0.0];
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // Uncomment the following code if you want the child controllers
    // to be loaded at this point.
    //
    // We leave this commented out because we think loading childs here is conceptually wrong.
    // Instead, we refrain view loads until necesary, for example we may never load
    // the rear controller view -or the front controller view- if it is never displayed.
    //
    // If you need to manipulate views of any of your child controllers in an override
    // of this method, you can load yourself the views explicitly on your overriden method.
    // However we discourage it as an app following the MVC principles should never need to do so
        
//  [_frontViewController view];
//  [_rearViewController view];

    // we store at this point the view's user interaction state as we may temporarily disable it
    // and resume it back to the previous state, it is possible to override this behaviour by
    // intercepting it on the panGestureBegan and panGestureEnded delegates
    _userInteractionStore = _contentView.userInteractionEnabled;
}


- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

// Support for earlier than iOS 6.0
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}
#endif


#pragma mark - Public methods and property accessors

- (void)setFrontViewController:(UIViewController *)frontViewController
{
    [self setFrontViewController:frontViewController animated:NO];
}


- (void)setFrontViewController:(UIViewController *)frontViewController animated:(BOOL)animated
{
    if ( ![self isViewLoaded])
    {
        [self _setFrontViewController:frontViewController];
        return;
    }
    
    [self _dispatchSetFrontViewController:frontViewController animated:animated];
}


- (void)setRearViewController:(UIViewController *)rightViewController
{
    if ( ![self isViewLoaded])
    {
        [self _setRearViewController:rightViewController];
        return;
    }

    [self _dispatchSetRearViewController:rightViewController];
}


- (void)setRightViewController:(UIViewController *)rightViewController
{
    if ( ![self isViewLoaded])
    {
        [self _setRightViewController:rightViewController];
        return;
    }

    [self _dispatchSetRightViewController:rightViewController];
}


- (void)revealToggleAnimated:(BOOL)animated
{
    FrontViewPosition toogledFrontViewPosition = FrontViewPositionLeft;
    if (_frontViewPosition <= FrontViewPositionLeft)
        toogledFrontViewPosition = FrontViewPositionRight;
    
    [self setFrontViewPosition:toogledFrontViewPosition animated:animated];
}

- (void)rightRevealToggleAnimated:(BOOL)animated
{
    FrontViewPosition toogledFrontViewPosition = FrontViewPositionLeft;
    if (_frontViewPosition >= FrontViewPositionLeft)
        toogledFrontViewPosition = FrontViewPositionLeftSide;
    
    [self setFrontViewPosition:toogledFrontViewPosition animated:animated];
}


- (void)setFrontViewPosition:(FrontViewPosition)frontViewPosition
{
    [self setFrontViewPosition:frontViewPosition animated:NO];
}


- (void)setFrontViewPosition:(FrontViewPosition)frontViewPosition animated:(BOOL)animated
{
    if ( ![self isViewLoaded] )
    {
        _frontViewPosition = frontViewPosition;
        _rearViewPosition = frontViewPosition;
        _rightViewPosition = frontViewPosition;
        return;
    }
    
    [self _dispatchSetFrontViewPosition:frontViewPosition animated:animated];
}


- (UIPanGestureRecognizer*)panGestureRecognizer
{
    if ( _panGestureRecognizer == nil )
    {
        SWDirectionPanGestureRecognizer *panRecognizer =
            [[SWDirectionPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleRevealGesture:)];
        
        panRecognizer.direction = SWDirectionPanGestureRecognizerHorizontal;
        panRecognizer.delegate = self;
        [_contentView.frontView addGestureRecognizer:panRecognizer];
        _panGestureRecognizer = panRecognizer ;
    }
    return _panGestureRecognizer;
}


- (UITapGestureRecognizer*)tapGestureRecognizer
{
    if ( _tapGestureRecognizer == nil )
    {
        UITapGestureRecognizer *tapRecognizer =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTapGesture:)];
        
        tapRecognizer.delegate = self;
        [_contentView.frontView addGestureRecognizer:tapRecognizer];
        _tapGestureRecognizer = tapRecognizer ;
    }
    return _tapGestureRecognizer;
}


#pragma mark - Provided acction methods

- (void)revealToggle:(id)sender
{    
    [self revealToggleAnimated:YES];
}

- (void)rightRevealToggle:(id)sender
{    
    [self rightRevealToggleAnimated:YES];
}


#pragma mark - UserInteractionEnabling

// disable userInteraction on the entire control
- (void)_disableUserInteraction
{
    [_contentView setUserInteractionEnabled:NO];
    [_contentView setDisableLayout:YES];
}

// restore userInteraction on the control
- (void)_restoreUserInteraction
{
    // we use the stored userInteraction state just in case a developer decided
    // to have our view interaction disabled beforehand
    [_contentView setUserInteractionEnabled:_userInteractionStore];
    [_contentView setDisableLayout:NO];
}

#pragma mark - PanGesture progress notification

- (void)_notifyPanGestureBegan
{
    if ( [_delegate respondsToSelector:@selector(revealControllerPanGestureBegan:)] )
        [_delegate revealControllerPanGestureBegan:self];
    
    CGFloat xLocation, dragProgress;
    [self _getDragLocation:&xLocation progress:&dragProgress];
    if ( [_delegate respondsToSelector:@selector(revealController:panGestureBeganFromLocation:progress:)] )
        [_delegate revealController:self panGestureBeganFromLocation:xLocation progress:dragProgress];
}

- (void)_notifyPanGestureMoved
{
    CGFloat xLocation, dragProgress;
    [self _getDragLocation:&xLocation progress:&dragProgress];
    if ( [_delegate respondsToSelector:@selector(revealController:panGestureMovedToLocation:progress:)] )
        [_delegate revealController:self panGestureMovedToLocation:xLocation progress:dragProgress];
}

- (void)_notifyPanGestureEnded
{
    CGFloat xLocation, dragProgress;
    [self _getDragLocation:&xLocation progress:&dragProgress];
    if ( [_delegate respondsToSelector:@selector(revealController:panGestureEndedToLocation:progress:)] )
        [_delegate revealController:self panGestureEndedToLocation:xLocation progress:dragProgress];
    
    if ( [_delegate respondsToSelector:@selector(revealControllerPanGestureEnded:)] )
        [_delegate revealControllerPanGestureEnded:self];
}


#pragma mark - Symetry

- (void)_getRevealWidth:(CGFloat*)pRevealWidth revealOverDraw:(CGFloat*)pRevealOverdraw forSymetry:(int)symetry
{
    if ( symetry < 0 ) *pRevealWidth = _rightViewRevealWidth, *pRevealOverdraw = _rightViewRevealOverdraw;
    else *pRevealWidth = _rearViewRevealWidth, *pRevealOverdraw = _rearViewRevealOverdraw;
    
    if (*pRevealWidth < 0) *pRevealWidth = _contentView.bounds.size.width + *pRevealWidth;
}

- (void)_getBounceBack:(BOOL*)pBounceBack pStableDrag:(BOOL*)pStableDrag forSymetry:(int)symetry
{
    if ( symetry < 0 ) *pBounceBack = _bounceBackOnLeftOverdraw, *pStableDrag = _stableDragOnLeftOverdraw;
    else *pBounceBack = _bounceBackOnOverdraw, *pStableDrag = _stableDragOnOverdraw;
}

- (void)_getAdjustedFrontViewPosition:(FrontViewPosition*)frontViewPosition forSymetry:(int)symetry
{
    if ( symetry < 0 ) *frontViewPosition = FrontViewPositionLeft + symetry*(*frontViewPosition-FrontViewPositionLeft);
}

- (void)_getDragLocation:(CGFloat*)xLocation progress:(CGFloat*)progress
{
    UIView *frontView = _contentView.frontView;
    *xLocation = frontView.frame.origin.x;

    int symetry = *xLocation<0 ? -1 : 1;
    
    CGFloat xWidth = symetry < 0 ? _rightViewRevealWidth : _rearViewRevealWidth;
    if ( xWidth < 0 ) xWidth = _contentView.bounds.size.width + xWidth;
    
    *progress = *xLocation/xWidth * symetry;
}


#pragma mark - Deferred block execution queue

// Define a convenience macro to enqueue single statements
#define _enqueue(code) [self _enqueueBlock:^{code;}];

// Defers the execution of the passed in block until a paired _dequeue call is received,
// or executes the block right away if no pending requests are present.
- (void)_enqueueBlock:(void (^)(void))block
{
    [_animationQueue insertObject:block atIndex:0];
    if ( _animationQueue.count == 1)
    {
        block();
    }
}

// Removes the top most block in the queue and executes the following one if any.
// Calls to this method must be paired with calls to _enqueueBlock, particularly it may be called
// from within a block passed to _enqueueBlock to remove itself when done with animations.  
- (void)_dequeue
{
    [_animationQueue removeLastObject];

    if ( _animationQueue.count > 0 )
    {
        void (^block)(void) = [_animationQueue lastObject];
        block();
    }
}


#pragma mark - Gesture Delegate


- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
    // only allow gesture if no previous request is in process
    if ( _animationQueue.count == 0 )
    {
        if ( recognizer == _panGestureRecognizer )
            return [self _panGestureShouldBegin];
        
        if ( recognizer == _tapGestureRecognizer )
            return [self _tapGestureShouldBegin];
    }

    return NO;
}


- (BOOL)_tapGestureShouldBegin
{
    if ( _frontViewPosition == FrontViewPositionLeft ||
        _frontViewPosition == FrontViewPositionRightMostRemoved ||
        _frontViewPosition ==FrontViewPositionLeftSideMostRemoved )
            return NO;
    
    // forbid gesture if the following delegate is implemented and returns NO
    if ( [_delegate respondsToSelector:@selector(revealControllerTapGestureShouldBegin:)] )
        if ( [_delegate revealControllerTapGestureShouldBegin:self] == NO )
            return NO;
    
    return YES;
}


- (BOOL)_panGestureShouldBegin
{
//    // only allow gesture if no previous request is in process
//    if ( recognizer != _panGestureRecognizer || _animationQueue.count != 0 )
//        return NO;
    
    // forbid gesture if the following delegate is implemented and returns NO
    if ( [_delegate respondsToSelector:@selector(revealControllerPanGestureShouldBegin:)] )
        if ( [_delegate revealControllerPanGestureShouldBegin:self] == NO )
            return NO;

    UIView *recognizerView = _panGestureRecognizer.view;
    CGFloat xLocation = [_panGestureRecognizer locationInView:recognizerView].x;
    CGFloat width = recognizerView.bounds.size.width;
    
    BOOL draggableBorderAllowing = (
        _frontViewPosition != FrontViewPositionLeft || _draggableBorderWidth == 0.0f ||
        xLocation <= _draggableBorderWidth || xLocation >= (width - _draggableBorderWidth) );

    // allow gesture only within the bounds defined by the draggableBorderWidth property
    return draggableBorderAllowing ;
}


#pragma mark - Gesture Based Reveal


- (void)_handleTapGesture:(UITapGestureRecognizer *)recognizer
{
    NSTimeInterval duration = _toggleAnimationDuration;
    [self _setFrontViewPosition:FrontViewPositionLeft withDuration:duration];
}



- (void)_handleRevealGesture:(UIPanGestureRecognizer *)recognizer
{
    switch ( recognizer.state )
    {
        case UIGestureRecognizerStateBegan:
            [self _handleRevealGestureStateBeganWithRecognizer:recognizer];
            break;
            
        case UIGestureRecognizerStateChanged:
            [self _handleRevealGestureStateChangedWithRecognizer:recognizer];
            break;
            
        case UIGestureRecognizerStateEnded:
            [self _handleRevealGestureStateEndedWithRecognizer:recognizer];
            break;
            
        case UIGestureRecognizerStateCancelled:
        //case UIGestureRecognizerStateFailed:
            [self _handleRevealGestureStateCancelledWithRecognizer:recognizer];
            break;
            
        default:
            break;
    }
}


- (void)_handleRevealGestureStateBeganWithRecognizer:(UIPanGestureRecognizer *)recognizer
{
    // we know that we will not get here unless the animationQueue is empty because the recognizer
    // delegate prevents it, however we do not want any forthcoming programatic actions to disturb
    // the gesture, so we just enqueue a dummy block to ensure any programatic acctions will be
    // scheduled after the gesture is completed
    [self _enqueueBlock:^{}]; // <-- dummy block

    // we store the initial position and initialize a target position
    _panInitialFrontPosition = _frontViewPosition;

    // we disable user interactions on the views, however programatic accions will still be
    // enqueued to be performed after the gesture completes
    [self _disableUserInteraction];
    [self _notifyPanGestureBegan];
}


- (void)_handleRevealGestureStateChangedWithRecognizer:(UIPanGestureRecognizer *)recognizer
{
    CGFloat translation = [recognizer translationInView:_contentView].x;
    
    CGFloat baseLocation = [_contentView frontLocationForPosition:_panInitialFrontPosition];
    CGFloat xLocation = baseLocation + translation;
    
    if ( xLocation < 0 )
    {
        if ( _rightViewController == nil ) xLocation = 0;
        [self _rightViewDeploymentForNewFrontViewPosition:FrontViewPositionLeftSide]();
        [self _rearViewDeploymentForNewFrontViewPosition:FrontViewPositionLeftSide]();
    }
    
    if ( xLocation > 0 )
    {
        if ( _rearViewController == nil ) xLocation = 0;
        [self _rightViewDeploymentForNewFrontViewPosition:FrontViewPositionRight]();
        [self _rearViewDeploymentForNewFrontViewPosition:FrontViewPositionRight]();
    }
    
    [_contentView dragFrontViewToXLocation:xLocation];
    [self _notifyPanGestureMoved];
}


- (void)_handleRevealGestureStateEndedWithRecognizer:(UIPanGestureRecognizer *)recognizer
{
    UIView *frontView = _contentView.frontView;
    
    CGFloat xLocation = frontView.frame.origin.x;
    CGFloat velocity = [recognizer velocityInView:_contentView].x;
    //NSLog( @"Velocity:%1.4f", velocity);
    
    // depending on position we compute a simetric replacement of widths and positions
    int symetry = xLocation<0 ? -1 : 1;
    
    // simetring computing of widths
    CGFloat revealWidth ;
    CGFloat revealOverdraw ;
    BOOL bounceBack;
    BOOL stableDrag;
    
    [self _getRevealWidth:&revealWidth revealOverDraw:&revealOverdraw forSymetry:symetry];
    [self _getBounceBack:&bounceBack pStableDrag:&stableDrag forSymetry:symetry];
    
    // simetric replacement of position
    xLocation = xLocation * symetry;
    
    // initially we assume drag to left and default duration
    FrontViewPosition frontViewPosition = FrontViewPositionLeft;
    NSTimeInterval duration = _toggleAnimationDuration;

    // Velocity driven change:
    if (fabsf(velocity) > _quickFlickVelocity)
    {
        // we may need to set the drag position and to adjust the animation duration
        CGFloat journey = xLocation;
        if (velocity*symetry > 0.0f)
        {
            frontViewPosition = FrontViewPositionRight;
            journey = revealWidth - xLocation;
            if (xLocation > revealWidth)
            {
                if (!bounceBack && stableDrag /*&& xPosition > _rearViewRevealWidth+_rearViewRevealOverdraw*0.5f*/)
                {
                    frontViewPosition = FrontViewPositionRightMost;
                    journey = revealWidth+revealOverdraw - xLocation;
                }
            }
        }
        
        duration = fabsf(journey/velocity);
    }
    
    // Position driven change:
    else
    {    
        // we may need to set the drag position        
        if (xLocation > revealWidth*0.5f)
        {
            frontViewPosition = FrontViewPositionRight;
            if (xLocation > revealWidth)
            {
                if (bounceBack)
                    frontViewPosition = FrontViewPositionLeft;

                else if (stableDrag && xLocation > revealWidth+revealOverdraw*0.5f)
                    frontViewPosition = FrontViewPositionRightMost;
            }
        }
    }
    
    // symetric replacement of frontViewPosition
    [self _getAdjustedFrontViewPosition:&frontViewPosition forSymetry:symetry];
    
    // restore user interaction and animate to the final position
    [self _restoreUserInteraction];
    [self _notifyPanGestureEnded];
    [self _setFrontViewPosition:frontViewPosition withDuration:duration];
}


- (void)_handleRevealGestureStateCancelledWithRecognizer:(UIPanGestureRecognizer *)recognizer
{    
    [self _restoreUserInteraction];
    [self _notifyPanGestureEnded];
    [self _dequeue];
}


#pragma mark Enqueued position and controller setup

- (void)_dispatchSetFrontViewPosition:(FrontViewPosition)frontViewPosition animated:(BOOL)animated
{
    NSTimeInterval duration = animated?_toggleAnimationDuration:0.0;
    __weak SWRevealViewController *theSelf = self;
    _enqueue( [theSelf _setFrontViewPosition:frontViewPosition withDuration:duration] );
}


- (void)_dispatchSetFrontViewController:(UIViewController *)newFrontViewController animated:(BOOL)animated
{
    FrontViewPosition preReplacementPosition = FrontViewPositionLeft;
    if ( _frontViewPosition > FrontViewPositionLeft ) preReplacementPosition = FrontViewPositionRightMost;
    if ( _frontViewPosition < FrontViewPositionLeft ) preReplacementPosition = FrontViewPositionLeftSideMost;
    
    NSTimeInterval duration = animated?_toggleAnimationDuration:0.0;
    NSTimeInterval firstDuration = duration;
    int initialPosDif = abs( _frontViewPosition - preReplacementPosition );
    if ( initialPosDif == 1 ) firstDuration *= 0.8;
    else if ( initialPosDif == 0 ) firstDuration = 0;
    
    __weak SWRevealViewController *theSelf = self;
    if ( animated )
    {
        _enqueue( [theSelf _setFrontViewPosition:preReplacementPosition withDuration:firstDuration] );
        _enqueue( [theSelf _setFrontViewController:newFrontViewController] );
        _enqueue( [theSelf _setFrontViewPosition:FrontViewPositionLeft withDuration:duration] );
    }
    else
    {
        _enqueue( [theSelf _setFrontViewController:newFrontViewController] );
    }
}


- (void)_dispatchSetRearViewController:(UIViewController *)newRearViewController
{
    __weak SWRevealViewController *theSelf = self;
    _enqueue( [theSelf _setRearViewController:newRearViewController] );
}


- (void)_dispatchSetRightViewController:(UIViewController *)newRightViewController
{
    __weak SWRevealViewController *theSelf = self;
    _enqueue( [theSelf _setRightViewController:newRightViewController] );
}


#pragma mark animated view controller deployment and layout

// Primitive method for view controller deployment and animated layout to the given position.
- (void)_setFrontViewPosition:(FrontViewPosition)newPosition withDuration:(NSTimeInterval)duration
{
    void (^rearDeploymentCompletion)() = [self _rearViewDeploymentForNewFrontViewPosition:newPosition];
    void (^rightDeploymentCompletion)() = [self _rightViewDeploymentForNewFrontViewPosition:newPosition];
    void (^frontDeploymentCompletion)() = [self _frontViewDeploymentForNewFrontViewPosition:newPosition];
    
    void (^animations)() = ^()
    {
        // Calling this in the animation block causes the status bar to appear/dissapear in sync with our own animation
        if ( [self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
            [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate) withObject:nil];
    
        // We call the layoutSubviews method on the contentView view and send a delegate, which will
        // occur inside of an animation block if any animated transition is being performed
        [_contentView layoutSubviews];
    
        if ([_delegate respondsToSelector:@selector(revealController:animateToPosition:)])
            [_delegate revealController:self animateToPosition:_frontViewPosition];
    };
    
    void (^completion)(BOOL) = ^(BOOL finished)
    {
        rearDeploymentCompletion();
        rightDeploymentCompletion();
        frontDeploymentCompletion();
        [self _dequeue];
    };
    
    if ( duration > 0.0f )
    {
        [UIView animateWithDuration:duration delay:0.0
        options:UIViewAnimationOptionCurveEaseOut
        animations:animations completion:completion];
    }
    else
    {
        animations();
        completion(YES);
    }
}

// primitive method for front controller transition
- (void)_setFrontViewController:(UIViewController*)newFrontViewController
{
    UIViewController *old = _frontViewController;
    _frontViewController = newFrontViewController;
    [self _transitionFromViewController:old toViewController:newFrontViewController inView:_contentView.frontView]();
    [self _dequeue];
}

// Primitive method for rear controller transition
- (void)_setRearViewController:(UIViewController*)newRearViewController
{
    UIViewController *old = _rearViewController;
    _rearViewController = newRearViewController;
    [self _transitionFromViewController:old toViewController:newRearViewController inView:_contentView.rearView]();
    [self _dequeue];
}

// Primitive method for right controller transition
- (void)_setRightViewController:(UIViewController*)newRightViewController
{
    UIViewController *old = _rightViewController;
    _rightViewController = newRightViewController;
    [self _transitionFromViewController:old toViewController:newRightViewController inView:_contentView.rightView]();
    [self _dequeue];
    
//    UIViewController *old = _rightViewController;
//    void (^completion)() = [self _transitionRearController:old toController:newRightViewController inView:_contentView.rightView];
//    [newRightViewController.view setAlpha:0.0];
//    [UIView animateWithDuration:_toggleAnimationDuration
//    animations:^
//    {
//        [old.view setAlpha:0.0f];
//        [newRightViewController.view setAlpha:1.0];
//    }
//    completion:^(BOOL finished)
//    {
//        completion();
//        [self _dequeue];
//    }];
}


#pragma mark Position based view controller deployment

// Deploy/Undeploy of the front view controller following the containment principles. Returns a block
// that must be invoked on animation completion in order to finish deployment
- (void (^)(void))_frontViewDeploymentForNewFrontViewPosition:(FrontViewPosition)newPosition
{
    if ( (_rightViewController == nil && newPosition < FrontViewPositionLeft) ||
         (_rearViewController == nil && newPosition > FrontViewPositionLeft) )
        newPosition = FrontViewPositionLeft;
    
    BOOL positionIsChanging = (_frontViewPosition != newPosition);
    
    BOOL appear =
        (_frontViewPosition >= FrontViewPositionRightMostRemoved || _frontViewPosition <= FrontViewPositionLeftSideMostRemoved) &&
        (newPosition < FrontViewPositionRightMostRemoved && newPosition > FrontViewPositionLeftSideMostRemoved);
    
    BOOL disappear =
        (newPosition >= FrontViewPositionRightMostRemoved || newPosition <= FrontViewPositionLeftSideMostRemoved ) &&
        (_frontViewPosition < FrontViewPositionRightMostRemoved && _frontViewPosition > FrontViewPositionLeftSideMostRemoved);
    
    if ( positionIsChanging )
    {
        if ( [_delegate respondsToSelector:@selector(revealController:willMoveToPosition:)] )
            [_delegate revealController:self willMoveToPosition:newPosition];
    }
    
    _frontViewPosition = newPosition;
    
    void (^deploymentCompletion)() =
        [self _deploymentForViewController:_frontViewController inView:_contentView.frontView appear:appear disappear:disappear];
    
    void (^completion)() = ^()
    {
        deploymentCompletion();
        if ( positionIsChanging )
        {
            if ( [_delegate respondsToSelector:@selector(revealController:didMoveToPosition:)] )
                [_delegate revealController:self didMoveToPosition:newPosition];
        }
    };

    return completion;
}

// Deploy/Undeploy of the left view controller following the containment principles. Returns a block
// that must be invoked on animation completion in order to finish deployment
- (void (^)(void))_rearViewDeploymentForNewFrontViewPosition:(FrontViewPosition)newPosition
{
    if ( _presentFrontViewHierarchically )
        newPosition = FrontViewPositionRight;
    
    if ( _rearViewController == nil && newPosition > FrontViewPositionLeft )
        newPosition = FrontViewPositionLeft;

    BOOL appear = (_rearViewPosition <= FrontViewPositionLeft || _rearViewPosition == FrontViewPositionNone) && newPosition > FrontViewPositionLeft;
    BOOL disappear = (newPosition <= FrontViewPositionLeft || newPosition == FrontViewPositionNone) && _rearViewPosition > FrontViewPositionLeft;
    
    if ( appear )
        [_contentView prepareRearViewForPosition:newPosition];
    
    _rearViewPosition = newPosition;
    
    return [self _deploymentForViewController:_rearViewController inView:_contentView.rearView appear:appear disappear:disappear];
}

// Deploy/Undeploy of the right view controller following the containment principles. Returns a block
// that must be invoked on animation completion in order to finish deployment
- (void (^)(void))_rightViewDeploymentForNewFrontViewPosition:(FrontViewPosition)newPosition
{
    if ( _rightViewController == nil && newPosition < FrontViewPositionLeft )
        newPosition = FrontViewPositionLeft;

    BOOL appear = _rightViewPosition >= FrontViewPositionLeft && newPosition < FrontViewPositionLeft ;
    BOOL disappear = newPosition >= FrontViewPositionLeft && _rightViewPosition < FrontViewPositionLeft;
    
    if ( appear )
        [_contentView prepareRightViewForPosition:newPosition];
    
    _rightViewPosition = newPosition;
    
    return [self _deploymentForViewController:_rightViewController inView:_contentView.rightView appear:appear disappear:disappear];
}


- (void (^)(void)) _deploymentForViewController:(UIViewController*)controller inView:(UIView*)view appear:(BOOL)appear disappear:(BOOL)disappear
{
    if ( appear ) return [self _deployForViewController:controller inView:view];
    if ( disappear ) return [self _undeployForViewController:controller];
    return ^{};
}


#pragma mark Containment view controller deployment and transition

// Containment Deploy method. Returns a block to be invoked at the
// animation completion, or right after return in case of non-animated deployment.
- (void (^)(void))_deployForViewController:(UIViewController*)controller inView:(UIView*)view
{
    if ( !controller || !view )
        return ^(void){};
    
    CGRect frame = view.bounds;
    
    UIView *controllerView = controller.view;
    controllerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    controllerView.frame = frame;
    
    if ( [controller respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)] && [controllerView isKindOfClass:[UIScrollView class]] )
    {
        BOOL adjust = (BOOL)[controller performSelector:@selector(automaticallyAdjustsScrollViewInsets) withObject:nil];
        
        if ( adjust )
        {
            [(id)controllerView setContentInset:UIEdgeInsetsMake(statusBarAdjustment(_contentView), 0, 0, 0)];
        }
    }
    
    [view addSubview:controllerView];
    
    void (^completionBlock)(void) = ^(void)
    {
        // nothing to do on completion at this stage
    };
    
    return completionBlock;
}

// Containment Undeploy method. Returns a block to be invoked at the
// animation completion, or right after return in case of non-animated deployment.
- (void (^)(void))_undeployForViewController:(UIViewController*)controller
{
    if (!controller)
        return ^(void){};

    // nothing to do before completion at this stage
    
    void (^completionBlock)(void) = ^(void)
    {
        [controller.view removeFromSuperview];
    };
    
    return completionBlock;
}

// Containment Transition method. Returns a block to be invoked at the
// animation completion, or right after return in case of non-animated transition.
- (void(^)(void))_transitionFromViewController:(UIViewController*)fromController toViewController:(UIViewController*)toController inView:(UIView*)view
{
    if ( fromController == toController )
        return ^(void){};
    
    if ( toController ) [self addChildViewController:toController];
    
    void (^deployCompletion)() = [self _deployForViewController:toController inView:view];
    
    [fromController willMoveToParentViewController:nil];
    
    void (^undeployCompletion)() = [self _undeployForViewController:fromController];
    
    void (^completionBlock)(void) = ^(void)
    {
        undeployCompletion() ;
        [fromController removeFromParentViewController];
        
        deployCompletion() ;
        [toController didMoveToParentViewController:self];
    };
    return completionBlock;
}


@end


#pragma mark - UIViewController(SWRevealViewController) Category

@implementation UIViewController(SWRevealViewController)

- (SWRevealViewController*)revealViewController
{
    UIViewController *parent = self;
    Class revealClass = [SWRevealViewController class];
    
    while ( nil != (parent = [parent parentViewController]) && ![parent isKindOfClass:revealClass] )
    {
    }
    
    return (id)parent;
}

@end


#pragma mark - SWRevealViewControllerSegue Class

@implementation SWRevealViewControllerSegue

- (void)perform
{
    if ( _performBlock != nil )
    {
        _performBlock( self, self.sourceViewController, self.destinationViewController );
    }
}

@end

