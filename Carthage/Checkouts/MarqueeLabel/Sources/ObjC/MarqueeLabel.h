
//
//  MarqueeLabel.h
//  
//  Created by Charles Powell on 1/31/11.
//  Copyright (c) 2011-2015 Charles Powell. All rights reserved.
//

#import <UIKit/UIKit.h>

/** An enum that defines the types of `MarqueeLabel` scrolling */
typedef NS_ENUM(NSUInteger, MarqueeType) {
    /** Scrolls left first, then back right to the original position. */
    MLLeftRight = 0,
    /** Scrolls right first, then back left to the original position. */
    MLRightLeft = 1,
    /** Continuously scrolls left (with a pause at the original position if animationDelay is set). See the `trailingBuffer` property to define a spacing between the repeating strings.*/
    MLContinuous = 2,
    /** Continuously scrolls right (with a pause at the original position if animationDelay is set). See the `trailingBuffer` property to define a spacing between the repeating strings.*/
    MLContinuousReverse = 3,
    /** Scrolls left first, then does not return to the original position. */
    MLLeft = 4,
    /** Scrolls right first, then does not return to the original position. */
    MLRight = 5
};


#ifndef IBInspectable
#define IBInspectable
#endif

/**
 MarqueeLabel is a UILabel subclass adds a scrolling marquee effect when the text of a label instance outgrows the available width. Instances of `MarqueeLabel` can be configured
 for label scrolling direction/looping, speed/rate, and other options.
 */

IB_DESIGNABLE
@interface MarqueeLabel : UILabel <CAAnimationDelegate>

////////////////////////////////////////////////////////////////////////////////
/// @name Creating MarqueeLabels
////////////////////////////////////////////////////////////////////////////////

/** Returns a newly initialized `MarqueeLabel` instance.

 The default scroll duration of 7.0 seconds and fade length of 0.0 are used.
 
 @param frame A rectangle specifying the initial location and size of the view in its superview's coordinates. Text (for the given font, font size, etc.) that does not fit in this frame will automatically scroll.
 @return An initialized `MarqueeLabel` object or nil if the object couldn't be created.
*/

- (instancetype)initWithFrame:(CGRect)frame;


/** Returns a newly initialized `MarqueeLabel` instance with the specified scroll rate and edge transparency fade length.
 
 You must specify a non-zero rate, and you cannot thereafter modify the rate.
 
 @param frame A rectangle specifying the initial location and size of the view in its superview's coordinates. Text (for the given font, font size, etc.) that does not fit in this frame will automatically scroll.
 @param pixelsPerSec A rate of scroll for the label scroll animation. Must be non-zero. Note that this will be the maximum rate for ease-type animation.
 @param fadeLength A length of transparency fade at the left and right edges of the `MarqueeLabel` instance's frame.
 @see fadeLength
 @return An initialized `MarqueeLabel` object or nil if the object couldn't be created.
 */

- (instancetype)initWithFrame:(CGRect)frame rate:(CGFloat)pixelsPerSec andFadeLength:(CGFloat)fadeLength;


/** Returns a newly initialized `MarqueeLabel` instance with the specified scroll duration and edge transparency fade length.
 
 You must specify a non-zero duration, and you cannot thereafter modify the duration.
 
 @param frame A rectangle specifying the initial location and size of the view in its superview's coordinates. Text (for the given font, font size, etc.) that does not fit in this frame will automatically scroll.
 @param scrollDuration A scroll duration the label scroll animation. Must be non-zero. This will be the duration that the animation takes for one-half of the scroll cycle in the case of left-right and right-left marquee types, and for one loop of a continuous marquee type.
 @param fadeLength A length of transparency fade at the left and right edges of the `MarqueeLabel` instance's frame.
 @see fadeLength
 @return An initialized `MarqueeLabel` object or nil if the object couldn't be created.
 */

- (instancetype)initWithFrame:(CGRect)frame duration:(NSTimeInterval)scrollDuration andFadeLength:(CGFloat)fadeLength;


/** Resizes the view to the minimum size necessary to fully enclose the current text (i.e. without scrolling), up to the maximum size specified.
 
 The current origin of the frame is retained.
 
 @param maxSize The maximum size up to which the view should be resized. Passing `CGSizeZero` will result in no maximum size limit.
 @param adjustHeight A boolean that can be used to indicate if the view's height should also be adjusted. Note that this has no impact on scrolling.
 */
- (void)minimizeLabelFrameWithMaximumSize:(CGSize)maxSize adjustHeight:(BOOL)adjustHeight;


////////////////////////////////////////////////////////////////////////////////
/// @name Configuration Options
////////////////////////////////////////////////////////////////////////////////

/** Specifies the animation curve used in the scrolling motion of the labels.
 
 Allowable options:
 
    - `UIViewAnimationOptionCurveEaseInOut`
    - `UIViewAnimationOptionCurveEaseIn`
    - `UIViewAnimationOptionCurveEaseOut`
    - `UIViewAnimationOptionCurveLinear`
 
 Defaults to `UIViewAnimationOptionCurveEaseInOut`.
 */

@property (nonatomic, assign) UIViewAnimationOptions animationCurve;


/** A boolean property that sets whether the `MarqueeLabel` should behave like a normal UILabel.
 
 When set to `YES` the `MarqueeLabel` will behave like a normal UILabel, and  will not begin scrolling when the text is
 larger than the specified frame. The change takes effect immediately, removing any in-flight animation as well as any
 current edge fade. Note that the `MarqueeLabel` will respect the current values of the `lineBreakMode` and `textAlignment` 
 properties while labelized.
 
 To simply prevent automatic scrolling, use the `holdScrolling` property.
 
 Defaults to `NO`.
 
 @see holdScrolling
 @see lineBreakMode
 @warning The label will not automatically scroll when this property is set to `YES`.
 @warning The UILabel default setting for the `lineBreakMode` property is `NSLineBreakByTruncatingTail`, which truncates
 the text adds an ellipsis glyph (...). Set the `lineBreakMode` property to `NSLineBreakByClipping` in order to avoid the
 ellipsis, especially if using an edge transparency fade.
 */

@property (nonatomic, assign) IBInspectable BOOL labelize;


/** A boolean property that sets whether the `MarqueeLabel` should hold (prevent) label scrolling.
 
 When set to `YES`, the `MarqueeLabel` will not automatically scroll even its text is larger than the specified frame, 
 although the specified edge fades will remain.
 
 To set the `MarqueeLabel` to act like a normal UILabel, use the `labelize` property.
 
 Defaults to `NO`.
 
 @see labelize
 @warning The label will not automatically scroll when this property is set to `YES`.
 */

@property (nonatomic, assign) IBInspectable BOOL holdScrolling;


/** A boolean property that sets whether the `MarqueeLabel` should only begin a scroll when tapped.
 
 If this property is set to `YES`, the `MarqueeLabel` will begin a scroll animation cycle only when tapped. The label will
 not automatically being a scroll. This setting overrides the setting of the `holdScrolling` property.
 
 Defaults to `NO` .
 
 @warning The label will not automatically scroll when this property is set to `YES`.
 @see holdScrolling
 */

@property (nonatomic, assign) IBInspectable BOOL tapToScroll;


/** Defines the direction and method in which the `MarqueeLabel` instance scrolls.
 
 `MarqueeLabel` supports four types of scrolling: `MLLeftRight`, `MLRightLeft`, `MLContinuous`, and `MLContinuousReverse`.
 
 Given the nature of how text direction works, the options for the `marqueeType` property require specific text alignments
 and will set the textAlignment property accordingly.
 
 - `MLLeftRight` type is ONLY compatible with a label text alignment of `NSTextAlignmentLeft`.
 - `MLRightLeft` type is ONLY compatible with a label text alignment of `NSTextAlignmentRight`.
 - `MLContinuous` does not require a text alignment (it is effectively centered).
 - `MLContinuousReverse` does not require a text alignment (it is effectively centered).
 
 Defaults to `MLLeftRight`.
 
 @see MarqueeType
 @see textAlignment
 */

#if TARGET_INTERFACE_BUILDER
@property (nonatomic, assign) IBInspectable NSInteger marqueeType;
#else
@property (nonatomic, assign) MarqueeType marqueeType;
#endif

/** Defines the duration of the scrolling animation.
 
 This property sets the amount of time it will take for the scrolling animation to complete a
 scrolling cycle. Note that for `MLLeftRight` and `MLRightLeft`, a cycle consists of the animation away,
 a pause (if a delay is specified), and the animation back to the original position.
 
 Setting this property will automatically override any value previously set to the `rate` property, and the `rate`
 property will be set to `0.0`.
 
 @see rate
 */

@property (nonatomic, assign) IBInspectable CGFloat scrollDuration;


/** Defines the rate at which the label will scroll, in pixels per second.
 
 Setting this property will automatically override any value previousy set to the `scrollDuration` property, and the
 `scrollDuration` property will be set to `0.0`. Note that this is the rate at which the label would scroll if it
 moved at a constant speed - with other animation curves the rate will be slightly different.
 
 @see scrollDuration
 */

@property (nonatomic, assign) IBInspectable CGFloat rate;


/** A buffer (offset) between the leading edge of the label text and the label frame.
 
 This property adds additional space between the leading edge of the label text and the label frame. The
 leading edge is the edge of the label text facing the direction of scroll (i.e. the edge that animates
 offscreen first during scrolling).
 
 Defaults to `0`.
 
 @note The value set to this property affects label positioning at all times (including when `labelize` is set to `YES`),
 including when the text string length is short enough that the label does not need to scroll.
 
 @note For `MLContinuous`-type labels, the smallest value of `leadingBuffer`, 'trailingBuffer`, and `fadeLength`
 is used as spacing between the two label instances. Zero is an allowable value for all three properties.
 
 @see trailingBuffer
 @since Available in 2.1.0 and later.
 */

@property (nonatomic, assign) IBInspectable CGFloat leadingBuffer;


/** A buffer (offset) between the trailing edge of the label text and the label frame.
 
 This property adds additional space (buffer) between the trailing edge of the label text and the label frame. The
 trailing edge is the edge of the label text facing away from the direction of scroll (i.e. the edge that animates
 offscreen last during scrolling).
 
 Defaults to `0`.
 
 @note For `MLContinuous`-type labels, the smallest value of `leadingBuffer`, 'trailingBuffer`, and `fadeLength`
 is used as spacing between the two label instances. Zero is an allowable value for all three properties.
 
 @note The value set to this property has no effect when the `labelize` property is set to `YES`.
 
 @see leadingBuffer
 @since Available in 2.1.0 and later.
 */

@property (nonatomic, assign) IBInspectable CGFloat trailingBuffer;


/**
 @deprecated Use `trailingBuffer` instead. Values set to this property are simply forwarded to `trailingBuffer`.
 */
 
@property (nonatomic, assign) CGFloat continuousMarqueeExtraBuffer DEPRECATED_ATTRIBUTE;


/** The length of transparency fade at the left and right edges of the `MarqueeLabel` instance's frame.
 
 This propery sets the size (in points) of the view edge transparency fades on the left and right edges of a `MarqueeLabel`. The
 transparency fades from an alpha of 1.0 (fully visible) to 0.0 (fully transparent) over this distance. Values set to this property
 will be sanitized to prevent a fade length greater than 1/2 of the frame width.
 
 Defaults to `0`.
 */

@property (nonatomic, assign) IBInspectable CGFloat fadeLength;


/** The length of delay in seconds that the label pauses at the completion of a scroll. */

@property (nonatomic, assign) IBInspectable CGFloat animationDelay;


/** The read-only duration of the scroll animation (not including delay). 
 
 The value of this property is calculated when using the `scrollRate` property to set label animation speed. The value of this property
 is equal to the value of `scrollDuration` property when using the `scrollDuration` property to set label animation speed.
 
 @see scrollDuration
 @see scrollRate
 */

@property (nonatomic, readonly) NSTimeInterval animationDuration;



////////////////////////////////////////////////////////////////////////////////
/// @name Animation control
////////////////////////////////////////////////////////////////////////////////

/** Immediately resets the label to the home position, cancelling any in-flight scroll animation, and restarts the scroll animation if the appropriate conditions are met.
 
 @see resetLabel
 @see triggerScrollStart
 */

- (void)restartLabel;


/** Immediately resets the label to the home position, cancelling any in-flight scroll animation.
 
 The text is immediately returned to the home position. Scrolling will not resume automatically after a call to this method. 
 To re-initiate scrolling use a call to `restartLabel` or `triggerScrollStart`, or make a change to a UILabel property such as text, bounds/frame,
 font, font size, etc.
 
 @see restartLabel
 @see triggerScrollStart
 @since Available in 2.4.0 and later.
 */

- (void)shutdownLabel;


/** Resets the label text, recalculating the scroll animation.
 
 The text is immediately returned to the home position, and the scroll animation positions are cleared. Scrolling will not resume automatically after
 a call to this method. To re-initiate scrolling, use either a call to `restartLabel` or make a change to a UILabel property such as text, bounds/frame,
 font, font size, etc.
 
 @see restartLabel
 */

- (void)resetLabel;


/** Pauses the text scrolling animation, at any point during an in-progress animation.
 
 @note This method has no effect if a scroll animation is NOT already in progress. To prevent automatic scrolling on a newly-initialized label prior to its presentation onscreen, see the `holdScrolling` property.
 
 @see holdScrolling
 @see unpauseLabel
 */

- (void)pauseLabel;


/** Un-pauses a previously paused text scrolling animation. This method has no effect if the label was not previously paused using `pauseLabel`.
 
 @see pauseLabel
 */

- (void)unpauseLabel;


/** Overrides any non-size condition which is preventing the receiver from automatically scrolling, and begins a scroll animation.
 
 Currently the only non-size conditions which can prevent a label from scrolling are the `tapToScroll` and `holdScrolling` properties. This
 method will not force a label with a string that fits inside the label bounds (i.e. that would not automatically scroll) to begin a scroll
 animation.
 
 Upon the completion of the first forced scroll animation, the receiver will not automatically continue to scroll unless the conditions 
 preventing scrolling have been removed.
 
 @note This method has no effect if called during an already in-flight scroll animation.
 
 @see restartLabel
 @since Available in 2.2.0 and later.
 */

- (void)triggerScrollStart;



////////////////////////////////////////////////////////////////////////////////
/// @name Animation Status
////////////////////////////////////////////////////////////////////////////////

/** Called when the label animation is about to begin.
 
 The default implementation of this method does nothing. Subclasses may override this method in order to perform any custom actions just as
 the label animation begins. This is only called in the event that the conditions for scrolling to begin are met.
 
 @since Available in 1.5.0 and later.
 */

- (void)labelWillBeginScroll;


/** Called when the label animation has finished, and the label is at the home position.
 
 The default implementation of this method does nothing. Subclasses may override this method in order to perform any custom actions jas as
 the label animation completes, and before the next animation would begin (assuming the scroll conditions are met).
 
 @param finished A Boolean that indicates whether or not the scroll animation actually finished before the completion handler was called.
 @since Available in 1.5.0 and later.
 
 @warning This method will be called, and the `finished` parameter will be `NO`, when any property changes are made that would cause the label 
 scrolling to be automatically reset. This includes changes to label text and font/font size changes.
 */

- (void)labelReturnedToHome:(BOOL)finished;


/** A boolean property that indicates if the label's scroll animation has been paused.
 
 @see pauseLabel
 @see unpauseLabel
 */

@property (nonatomic, assign, readonly) BOOL isPaused;


/** A boolean property that indicates if the label is currently away from the home location.
 
 The "home" location is the traditional location of `UILabel` text. This property essentially reflects if a scroll animation is underway.
 */

@property (nonatomic, assign, readonly) BOOL awayFromHome;



////////////////////////////////////////////////////////////////////////////////
/// @name Bulk-manipulation Methods
////////////////////////////////////////////////////////////////////////////////

/** Convenience method to restart all `MarqueeLabel` instances that have the specified view controller in their next responder chain.
 
 This method sends a `NSNotification` to all `MarqueeLabel` instances with the specified view controller in their next responder chain.
 The scrolling animation of these instances will be automatically restarted. This is equivalent to calling `restartLabel` on all affected
 instances.
 
 There is currently no functional difference between this method and `controllerViewDidAppear:` or `controllerViewWillAppear:`. The methods may 
 be used interchangeably.
 
 @warning View controllers that appear with animation (such as from underneath a modal-style controller) can cause some `MarqueeLabel` text
 position "jumping" when this method is used in `viewDidAppear` if scroll animations are already underway. Use this method inside `viewWillAppear:`
 instead to avoid this problem.
 
 @warning This method may not function properly if passed the parent view controller when using view controller containment.
 
 @param controller The view controller that has appeared.
 @see restartLabel
 @see controllerViewDidAppear:
 @see controllerViewWillAppear:
 @since Available in 1.3.1 and later.
 */

+ (void)restartLabelsOfController:(UIViewController *)controller;


/** Convenience method to restart all `MarqueeLabel` instances that have the specified view controller in their next responder chain.
 
 Alternative to `restartLabelsOfController:`. This method is retained for backwards compatibility and future enhancements.
 
 @param controller The view controller that has appeared.
 @see restartLabel
 @see controllerViewWillAppear:
 @since Available in 1.2.7 and later.
 */

+ (void)controllerViewDidAppear:(UIViewController *)controller;


/** Convenience method to restart all `MarqueeLabel` instances that have the specified view controller in their next responder chain.
 
 Alternative to `restartLabelsOfController:`. This method is retained for backwards compatibility and future enhancements.
 
 @param controller The view controller that has appeared.
 @see restartLabel
 @see controllerViewDidAppear:
 @since Available in 1.2.8 and later.
 */

+ (void)controllerViewWillAppear:(UIViewController *)controller;


/**
 @deprecated Use `controllerViewDidAppear:` instead.
 */

+ (void)controllerViewAppearing:(UIViewController *)controller DEPRECATED_ATTRIBUTE;


/** Labelizes all `MarqueeLabel` instances that have the specified view controller in their next responder chain.
 
 This method sends an `NSNotification` to all `MarqueeLabel` instances with the specified view controller in their next
 responder chain. The `labelize` property of these `MarqueeLabel` instances will be set to `YES`.
 
 @param controller The view controller for which all `MarqueeLabel` instances should be labelized.
 @see labelize
 */

+ (void)controllerLabelsShouldLabelize:(UIViewController *)controller;


/** De-Labelizes all `MarqueeLabel` instances that have the specified view controller in their next responder chain.
 
 This method sends an `NSNotification` to all `MarqueeLabel` instances with the specified view controller in their next
 responder chain. The `labelize` property of these `MarqueeLabel` instances will be set to `NO` .
 
 @param controller The view controller for which all `MarqueeLabel` instances should be de-labelized.
 @see labelize
 */

+ (void)controllerLabelsShouldAnimate:(UIViewController *)controller;


@end


