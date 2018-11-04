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

/*

 RELEASE NOTES
 
 Version 1.1.2 (Current Version)
 
 - The status bar style and appearance are now handled in sync with the class animations. 
    You can implement the methods preferredStatusBarStyle and prefersStatusBarHidden on your child controllers to define the desired appearance
    
 - The loadView method now calls a method, loadStoryboardControllers, just for the purpose of loading child controllers from a storyboard.
    You can override this method and remove the @try @catch statements if you want the debuger not to stop at them in case you have set an exception breakpoint.
 
 Version 1.1.1
 
 - You can now get a tapGestureRecognizer from the class. See the tapGestureRecognizer method for more information.
 
 - Both the panGestureRecognizer and the tapGestureRecognizer are now attached to the revealViewController's front content view
    by default, so they will start working just by calling their access methods even if you do not attach them to any of your views.
    This enables you to dissable interactions on your views -for example based on position- without breaking normal gesture behavior.
 
 - Corrected a bug that caused a crash on iOS6 and earlier.
 
 Version 1.1.0

 - The method setFrontViewController:animated now performs the correct animations both for left and right controllers.

 - The class now automatically handles the status bar appearance depending on the currently shown child controller.

 Version 1.0.8
 
 - Support for constant width frontView by setting a negative value to reveal widths. See properties rearViewRevealWidth and rightViewRevealWidth
 
 - Support for draggableBorderWidth. See property of the same name.
 
 - The Pan gesture recongnizer can be disabled by implementing the following delegate method and returning NO
    revealControllerPanGestureShouldBegin:

 - Added the ability to track pan gesture reveal progress through the following new delegate methods
    revealController:panGestureBeganFromLocation:progress:
    revealController:panGestureMovedToLocation:progress:
    revealController:panGestureEndedToLocation:progress:
 
 Previous Versions
 
 - No release notes were updated for previous versions.

*/


#import <UIKit/UIKit.h>

@class SWRevealViewController;
@protocol SWRevealViewControllerDelegate;

#pragma mark - SWRevealViewController Class

// Enum values for setFrontViewPosition:animated:
typedef enum
{
    // Front controller is removed from view. Animated transitioning from this state will cause the same
    // effect than animating from FrontViewPositionLeftSideMost. Use this instead of FrontViewPositionLeftSideMost when
    // you want to remove the front view controller view from the view hierarchy.
    FrontViewPositionLeftSideMostRemoved,
    
    // Left most position, front view is presented left-offseted by rightViewRevealWidth+rigthViewRevealOverdraw
    FrontViewPositionLeftSideMost,
    
    // Left position, front view is presented left-offseted by rightViewRevealWidth
    FrontViewPositionLeftSide,

    // Center position, rear view is hidden behind front controller
	FrontViewPositionLeft,
    
    // Right possition, front view is presented right-offseted by rearViewRevealWidth
	FrontViewPositionRight,
    
    // Right most possition, front view is presented right-offseted by rearViewRevealWidth+rearViewRevealOverdraw
	FrontViewPositionRightMost,
    
    // Front controller is removed from view. Animated transitioning from this state will cause the same
    // effect than animating from FrontViewPositionRightMost. Use this instead of FrontViewPositionRightMost when
    // you intent to remove the front controller view from the view hierarchy.
    FrontViewPositionRightMostRemoved,
    
} FrontViewPosition;


@interface SWRevealViewController : UIViewController

// Object instance init and rear view setting
- (id)initWithRearViewController:(UIViewController *)rearViewController frontViewController:(UIViewController *)frontViewController;

// Rear view controller, can be nil if not used
@property (strong, nonatomic) UIViewController *rearViewController;

// Optional right view controller, can be nil if not used
@property (strong, nonatomic) UIViewController *rightViewController;

// Front view controller, can be nil on initialization but must be supplied by the time its view is loaded
@property (strong, nonatomic) UIViewController *frontViewController;

// Sets the frontViewController using a default set of chained animations consisting on moving the
// presented frontViewController to the top most right, replacing it, and moving it back to the left position
- (void)setFrontViewController:(UIViewController *)frontViewController animated:(BOOL)animated;

// Front view position, use this to set a particular position state on the controller
// On initialization it is set to FrontViewPositionLeft
@property (assign, nonatomic) FrontViewPosition frontViewPosition;

// Chained animation of the frontViewController position. You can call it several times in a row to achieve
// any set of animations you wish. Animations will be chained and performed one after the other.
- (void)setFrontViewPosition:(FrontViewPosition)frontViewPosition animated:(BOOL)animated;

// Toogles the current state of the front controller between Left or Right and fully visible
// Use setFrontViewPosition to set a particular position
- (void)revealToggleAnimated:(BOOL)animated;
- (void)rightRevealToggleAnimated:(BOOL)animated; // <-- simetric implementation of the above for the rightViewController

// The following methods are meant to be directly connected to the action method of a button
// to perform user triggered postion change of the controller views. This is ussually added to a
// button on top left or right of the frontViewController
- (void)revealToggle:(id)sender;
- (void)rightRevealToggle:(id)sender; // <-- simetric implementation of the above for the rightViewController

// The following method will provide a panGestureRecognizer suitable to be added to any view
// in order to perform usual drag and swipe gestures to reveal the rear views. This is usually added to the top bar
// of a front controller, but it can be added to your frontViewController view or to the reveal controller view to provide full screen panning.
// The provided panGestureRecognizer is initially added to the reveal controller's front container view, so you can dissable
// user interactions on your controllers views and the recognizer will continue working. 
- (UIPanGestureRecognizer*)panGestureRecognizer;

// The following method will provide a tapGestureRecognizer suitable to be added to any view on the frontController
// for concealing the rear views. By default no tap recognizer is created or added to any view, however if you call this method after
// the controller's view has been loaded the recognizer is added to the reveal controller's front container view.
// Thus, you can disable user interactions on your frontViewController view without affecting the tap recognizer.
- (UITapGestureRecognizer*)tapGestureRecognizer;

// The following properties are provided for further customization, they are set to default values on initialization,
// you should not generally have to set them

// Defines how much of the rear or right view is shown, default is 260. A negative value indicates that the reveal width should be
// computed by substracting the full front view width, so the revealed frontView width is constant.
@property (assign, nonatomic) CGFloat rearViewRevealWidth;
@property (assign, nonatomic) CGFloat rightViewRevealWidth; // <-- simetric implementation of the above for the rightViewController

// Defines how much of an overdraw can occur when dragging further than 'rearViewRevealWidth', default is 60.
@property (assign, nonatomic) CGFloat rearViewRevealOverdraw;
@property (assign, nonatomic) CGFloat rightViewRevealOverdraw;   // <-- simetric implementation of the above for the rightViewController

// Defines how much displacement is applied to the rear view when animating or dragging the front view, default is 40.
@property (assign, nonatomic) CGFloat rearViewRevealDisplacement;
@property (assign, nonatomic) CGFloat rightViewRevealDisplacement;

// Defines a width on the border of the view attached to the panGesturRecognizer where the gesture is allowed,
// default is 0 which means no restriction.
@property (assign, nonatomic) CGFloat draggableBorderWidth;

// If YES (the default) the controller will bounce to the Left position when dragging further than 'rearViewRevealWidth'
@property (assign, nonatomic) BOOL bounceBackOnOverdraw;
@property (assign, nonatomic) BOOL bounceBackOnLeftOverdraw;

// If YES (default is NO) the controller will allow permanent dragging up to the rightMostPosition
@property (assign, nonatomic) BOOL stableDragOnOverdraw;
@property (assign, nonatomic) BOOL stableDragOnLeftOverdraw; // <-- simetric implementation of the above for the rightViewController

// If YES (default is NO) the front view controller will be ofsseted vertically by the height of a navigation bar.
// Use this on iOS7 when you add an instance of RevealViewController as a child of a UINavigationController (or another SWRevealViewController)
// and you want the front view controller to be presented below the navigation bar of its UINavigationController grand parent .
// The rearViewController will still appear full size and blurred behind the navigation bar of its UINavigationController grand parent
@property (assign, nonatomic) BOOL presentFrontViewHierarchically;

// Velocity required for the controller to toggle its state based on a swipe movement, default is 300
@property (assign, nonatomic) CGFloat quickFlickVelocity;

// Default duration for the revealToggle animation, default is 0.25
@property (assign, nonatomic) NSTimeInterval toggleAnimationDuration;

// Defines the radius of the front view's shadow, default is 2.5f
@property (assign, nonatomic) CGFloat frontViewShadowRadius;

// Defines the radius of the front view's shadow offset default is {0.0f,2.5f}
@property (assign, nonatomic) CGSize frontViewShadowOffset;

//Defines the front view's shadow opacity, default is 1.0f
@property (assign, nonatomic) CGFloat frontViewShadowOpacity;

// The class properly handles all the relevant calls to appearance methods on the contained controllers.
// Moreover you can assign a delegate to let the class inform you on positions and animation activity.

// Delegate
@property (weak, nonatomic) id<SWRevealViewControllerDelegate> delegate;

@end

#pragma mark - SWRevealViewControllerDelegate Protocol

@protocol SWRevealViewControllerDelegate<NSObject>

@optional

// The following delegate methods will be called before and after the front view moves to a position
- (void)revealController:(SWRevealViewController *)revealController willMoveToPosition:(FrontViewPosition)position;
- (void)revealController:(SWRevealViewController *)revealController didMoveToPosition:(FrontViewPosition)position;

// This will be called inside the reveal animation, thus you can use it to place your own code that will be animated in sync
- (void)revealController:(SWRevealViewController *)revealController animateToPosition:(FrontViewPosition)position;

// Implement this to return NO when you want the pan gesture recognizer to be ignored
- (BOOL)revealControllerPanGestureShouldBegin:(SWRevealViewController *)revealController;

// Implement this to return NO when you want the tap gesture recognizer to be ignored
- (BOOL)revealControllerTapGestureShouldBegin:(SWRevealViewController *)revealController;

// Called when the gestureRecognizer began and ended
- (void)revealControllerPanGestureBegan:(SWRevealViewController *)revealController;
- (void)revealControllerPanGestureEnded:(SWRevealViewController *)revealController;

// The following methods provide a means to track the evolution of the gesture recognizer.
// The 'location' parameter is the X origin coordinate of the front view as the user drags it
// The 'progress' parameter is a positive value from 0 to 1 indicating the front view location relative to the
// rearRevealWidth or rightRevealWidth. 1 is fully revealed, dragging ocurring in the overDraw region will result in values above 1.
- (void)revealController:(SWRevealViewController *)revealController panGestureBeganFromLocation:(CGFloat)location progress:(CGFloat)progress;
- (void)revealController:(SWRevealViewController *)revealController panGestureMovedToLocation:(CGFloat)location progress:(CGFloat)progress;
- (void)revealController:(SWRevealViewController *)revealController panGestureEndedToLocation:(CGFloat)location progress:(CGFloat)progress;

@end


#pragma mark - UIViewController(SWRevealViewController) Category

// We add a category of UIViewController to let childViewControllers easily access their parent SWRevealViewController
@interface UIViewController(SWRevealViewController)

- (SWRevealViewController*)revealViewController;

@end


// This will allow the class to be defined on a storyboard
#pragma mark - SWRevealViewControllerSegue

@interface SWRevealViewControllerSegue : UIStoryboardSegue

@property (strong) void(^performBlock)( SWRevealViewControllerSegue* segue, UIViewController* svc, UIViewController* dvc );

@end


