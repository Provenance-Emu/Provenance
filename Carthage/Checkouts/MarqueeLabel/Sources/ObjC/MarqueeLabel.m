
//
//  MarqueeLabel.m
//
//  Created by Charles Powell on 1/31/11.
//  Copyright (c) 2011-2015 Charles Powell. All rights reserved.
//

#import "MarqueeLabel.h"
#import <QuartzCore/QuartzCore.h>

// Notification strings
NSString *const kMarqueeLabelControllerRestartNotification = @"MarqueeLabelViewControllerRestart";
NSString *const kMarqueeLabelShouldLabelizeNotification = @"MarqueeLabelShouldLabelizeNotification";
NSString *const kMarqueeLabelShouldAnimateNotification = @"MarqueeLabelShouldAnimateNotification";
NSString *const kMarqueeLabelAnimationCompletionBlock = @"MarqueeLabelAnimationCompletionBlock";

// Animation completion block
typedef void(^MLAnimationCompletionBlock)(BOOL finished);

// iOS Version check for iOS 8.0.0
#define SYSTEM_VERSION_IS_8_0_X ([[[UIDevice currentDevice] systemVersion] hasPrefix:@"8.0"])

// Define "a long time" for MLLeft and MLRight types
#define CGFLOAT_LONG_DURATION 60*60*24*365 // One year in seconds

// Helpers
@interface GradientSetupAnimation : CABasicAnimation
@end

@interface UIView (MarqueeLabelHelpers)
- (UIViewController *)firstAvailableViewController;
- (id)traverseResponderChainForFirstViewController;
@end

@interface CAMediaTimingFunction (MarqueeLabelHelpers)
- (NSArray *)controlPoints;
- (CGFloat)durationPercentageForPositionPercentage:(CGFloat)positionPercentage withDuration:(NSTimeInterval)duration;
@end

@interface MarqueeLabel()

@property (nonatomic, strong) UILabel *subLabel;

@property (nonatomic, assign) NSTimeInterval animationDuration;
@property (nonatomic, assign, readonly) BOOL labelShouldScroll;
@property (nonatomic, weak) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, assign) CGRect homeLabelFrame;
@property (nonatomic, assign) CGFloat awayOffset;
@property (nonatomic, assign, readwrite) BOOL isPaused;

// Support
@property (nonatomic, copy) MLAnimationCompletionBlock scrollCompletionBlock;
@property (nonatomic, strong) NSArray *gradientColors;
CGPoint MLOffsetCGPoint(CGPoint point, CGFloat offset);

@end


@implementation MarqueeLabel

#pragma mark - Class Methods and handlers

+ (void)restartLabelsOfController:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelControllerRestartNotification];
}

+ (void)controllerViewWillAppear:(UIViewController *)controller {
    [MarqueeLabel restartLabelsOfController:controller];
}

+ (void)controllerViewDidAppear:(UIViewController *)controller {
    [MarqueeLabel restartLabelsOfController:controller];
}

+ (void)controllerViewAppearing:(UIViewController *)controller {
    [MarqueeLabel restartLabelsOfController:controller];
}

+ (void)controllerLabelsShouldLabelize:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelShouldLabelizeNotification];
}

+ (void)controllerLabelsShouldAnimate:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelShouldAnimateNotification];
}

+ (void)notifyController:(UIViewController *)controller withMessage:(NSString *)message
{
    if (controller && message) {
        [[NSNotificationCenter defaultCenter] postNotificationName:message
                                                            object:nil
                                                          userInfo:[NSDictionary dictionaryWithObject:controller
                                                                                               forKey:@"controller"]];
    }
}

- (void)viewControllerShouldRestart:(NSNotification *)notification {
    UIViewController *controller = [[notification userInfo] objectForKey:@"controller"];
    if (controller == [self firstAvailableViewController]) {
        [self restartLabel];
    }
}

- (void)labelsShouldLabelize:(NSNotification *)notification {
    UIViewController *controller = [[notification userInfo] objectForKey:@"controller"];
    if (controller == [self firstAvailableViewController]) {
        self.labelize = YES;
    }
}

- (void)labelsShouldAnimate:(NSNotification *)notification {
    UIViewController *controller = [[notification userInfo] objectForKey:@"controller"];
    if (controller == [self firstAvailableViewController]) {
        self.labelize = NO;
    }
}

#pragma mark - Initialization and Label Config

- (id)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame duration:7.0 andFadeLength:0.0];
}

- (id)initWithFrame:(CGRect)frame duration:(NSTimeInterval)aLengthOfScroll andFadeLength:(CGFloat)aFadeLength {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLabel];
        
        _scrollDuration = aLengthOfScroll;
        self.fadeLength = MIN(aFadeLength, frame.size.width/2);
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame rate:(CGFloat)pixelsPerSec andFadeLength:(CGFloat)aFadeLength {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLabel];
        
        _rate = pixelsPerSec;
        self.fadeLength = MIN(aFadeLength, frame.size.width/2);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupLabel];
        
        if (self.scrollDuration == 0) {
            self.scrollDuration = 7.0;
        }
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self forwardPropertiesToSubLabel];
}

- (void)prepareForInterfaceBuilder {
    [super prepareForInterfaceBuilder];
    [self forwardPropertiesToSubLabel];
}

+ (Class)layerClass {
    return [CAReplicatorLayer class];
}

- (CAReplicatorLayer *)repliLayer {
    return (CAReplicatorLayer *)self.layer;
}

- (CAGradientLayer *)maskLayer {
    return (CAGradientLayer *)self.layer.mask;
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    // Do NOT call super, to prevent UILabel superclass from drawing into context
    // Label drawing is handled by sublabel and CAReplicatorLayer layer class
    
    // Draw only background color
    CGContextSetFillColorWithColor(ctx, self.backgroundColor.CGColor);
    CGContextFillRect(ctx, layer.bounds);
}

- (void)forwardPropertiesToSubLabel {
    /*
     Note that this method is currently ONLY called from awakeFromNib, i.e. when
     text properties are set via a Storyboard. As the Storyboard/IB doesn't currently
     support attributed strings, there's no need to "forward" the super attributedString value.
     */
    
    // Since we're a UILabel, we actually do implement all of UILabel's properties.
    // We don't care about these values, we just want to forward them on to our sublabel.
    NSArray *properties = @[@"baselineAdjustment", @"enabled", @"highlighted", @"highlightedTextColor",
                            @"minimumFontSize", @"textAlignment",
                            @"userInteractionEnabled", @"adjustsFontSizeToFitWidth",
                            @"lineBreakMode", @"numberOfLines", @"contentMode"];
    
    // Iterate through properties
    self.subLabel.text = super.text;
    self.subLabel.font = super.font;
    self.subLabel.textColor = super.textColor;
    self.subLabel.backgroundColor = (super.backgroundColor == nil ? [UIColor clearColor] : super.backgroundColor);
    self.subLabel.shadowColor = super.shadowColor;
    self.subLabel.shadowOffset = super.shadowOffset;
    for (NSString *property in properties) {
        id val = [super valueForKey:property];
        [self.subLabel setValue:val forKey:property];
    }
}

- (void)setupLabel {
    
    // Basic UILabel options override
    self.clipsToBounds = YES;
    self.numberOfLines = 1;
    
    // Create first sublabel
    self.subLabel = [[UILabel alloc] initWithFrame:self.bounds];
    self.subLabel.tag = 700;
    self.subLabel.layer.anchorPoint = CGPointMake(0.0f, 0.0f);
    
    [self addSubview:self.subLabel];
    
    // Setup default values
    _marqueeType = MLContinuous;
    _awayOffset = 0.0f;
    _animationCurve = UIViewAnimationOptionCurveLinear;
    _labelize = NO;
    _holdScrolling = NO;
    _tapToScroll = NO;
    _isPaused = NO;
    _fadeLength = 0.0f;
    _animationDelay = 1.0;
    _animationDuration = 0.0f;
    _leadingBuffer = 0.0f;
    _trailingBuffer = 0.0f;
    
    // Add notification observers
    // Custom class notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewControllerShouldRestart:) name:kMarqueeLabelControllerRestartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(labelsShouldLabelize:) name:kMarqueeLabelShouldLabelizeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(labelsShouldAnimate:) name:kMarqueeLabelShouldAnimateNotification object:nil];
    
    // UIApplication state notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restartLabel) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shutdownLabel) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)minimizeLabelFrameWithMaximumSize:(CGSize)maxSize adjustHeight:(BOOL)adjustHeight {
    if (self.subLabel.text != nil) {
        // Calculate text size
        if (CGSizeEqualToSize(maxSize, CGSizeZero)) {
            maxSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
        }
        CGSize minimumLabelSize = [self subLabelSize];
        
        // Adjust for fade length
        CGSize minimumSize = CGSizeMake(minimumLabelSize.width + (self.fadeLength * 2), minimumLabelSize.height);
        
        // Find minimum size of options
        minimumSize = CGSizeMake(MIN(minimumSize.width, maxSize.width), MIN(minimumSize.height, maxSize.height));
        
        // Apply to frame
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, minimumSize.width, (adjustHeight ? minimumSize.height : self.frame.size.height));
    }
}

-(void)didMoveToSuperview {
    [self updateSublabel];
}

#pragma mark - MarqueeLabel Heavy Lifting

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self updateSublabel];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (!newWindow) {
        [self shutdownLabel];
    }
}

- (void)didMoveToWindow {
    if (!self.window) {
        [self shutdownLabel];
    } else {
        [self updateSublabel];
    }
}

- (void)updateSublabel {
    [self updateSublabelAndBeginScroll:YES];
}

- (void)updateSublabelAndBeginScroll:(BOOL)beginScroll {
    if (!self.subLabel.text || !self.superview) {
        return;
    }
    
    // Calculate expected size
    CGSize expectedLabelSize = [self subLabelSize];
    
    
    // Invalidate intrinsic size
    [self invalidateIntrinsicContentSize];
    
    // Move to home
    [self returnLabelToOriginImmediately];
    
    // Configure gradient for the current condition
    [self applyGradientMaskForFadeLength:self.fadeLength animated:YES];
    
    // Check if label should scroll
    // Can be because: 1) text fits, or 2) labelization
    // The holdScrolling property does NOT affect this
    if (!self.labelShouldScroll) {
        // Set text alignment and break mode to act like normal label
        self.subLabel.textAlignment = [super textAlignment];
        self.subLabel.lineBreakMode = [super lineBreakMode];
        
        CGRect labelFrame, unusedFrame;
        switch (self.marqueeType) {
            case MLContinuousReverse:
            case MLRightLeft:
            case MLRight:
                CGRectDivide(self.bounds, &unusedFrame, &labelFrame, self.leadingBuffer, CGRectMaxXEdge);
                labelFrame = CGRectIntegral(labelFrame);
                break;
                
            default:
                labelFrame = CGRectIntegral(CGRectMake(self.leadingBuffer, 0.0f, self.bounds.size.width - self.leadingBuffer, self.bounds.size.height));
                break;
        }
        
        self.homeLabelFrame = labelFrame;
        self.awayOffset = 0.0f;
        
        // Remove an additional sublabels (for continuous types)
        self.repliLayer.instanceCount = 1;
        
        // Set sublabel frame calculated labelFrame
        self.subLabel.frame = labelFrame;
        
        // Remove fade, as by definition none is needed in this case
        [self removeGradientMask];
        
        return;
    }
    
    // Label DOES need to scroll
    
    [self.subLabel setLineBreakMode:NSLineBreakByClipping];
    
    // Spacing between primary and second sublabel must be at least equal to leadingBuffer, and at least equal to the fadeLength
    CGFloat minTrailing = MAX(MAX(self.leadingBuffer, self.trailingBuffer), self.fadeLength);
    
    switch (self.marqueeType) {
        case MLContinuous:
        case MLContinuousReverse:
        {
            if (self.marqueeType == MLContinuous) {
                self.homeLabelFrame = CGRectIntegral(CGRectMake(self.leadingBuffer, 0.0f, expectedLabelSize.width, self.bounds.size.height));
                self.awayOffset = -(self.homeLabelFrame.size.width + minTrailing);
            } else {
                self.homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - (expectedLabelSize.width + self.leadingBuffer), 0.0f, expectedLabelSize.width, self.bounds.size.height));
                self.awayOffset = (self.homeLabelFrame.size.width + minTrailing);
            }
            
            self.subLabel.frame = self.homeLabelFrame;
            
            // Configure replication
            self.repliLayer.instanceCount = 2;
            self.repliLayer.instanceTransform = CATransform3DMakeTranslation(-self.awayOffset, 0.0, 0.0);
            
            // Recompute the animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval) fabs(self.awayOffset) / self.rate) : (self.scrollDuration);
            
            break;
        }
            
        case MLRightLeft:
        case MLRight:
        {
            self.homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - (expectedLabelSize.width + self.leadingBuffer), 0.0f, expectedLabelSize.width, self.bounds.size.height));
            self.awayOffset = (expectedLabelSize.width + self.trailingBuffer + self.leadingBuffer) - self.bounds.size.width;
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? (NSTimeInterval)fabs(self.awayOffset / self.rate) : (self.scrollDuration);
            
            // Set frame and text
            self.subLabel.frame = self.homeLabelFrame;
            
            // Remove any replication
            self.repliLayer.instanceCount = 1;
            
            // Enforce text alignment for this type
            self.subLabel.textAlignment = NSTextAlignmentRight;
            
            break;
        }
            
        case MLLeftRight:
        case MLLeft:
        {
            self.homeLabelFrame = CGRectIntegral(CGRectMake(self.leadingBuffer, 0.0f, expectedLabelSize.width, self.bounds.size.height));
            self.awayOffset = self.bounds.size.width - (expectedLabelSize.width + self.leadingBuffer + self.trailingBuffer);
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? (NSTimeInterval)fabs(self.awayOffset / self.rate) : (self.scrollDuration);
            
            // Set frame
            self.subLabel.frame = self.homeLabelFrame;
            
            // Remove any replication
            self.repliLayer.instanceCount = 1;
            
            // Enforce text alignment for this type
            self.subLabel.textAlignment = NSTextAlignmentLeft;
            
            break;
        }
            
        default:
        {
            // Something strange has happened
            self.homeLabelFrame = CGRectZero;
            self.awayOffset = 0.0f;
            
            // Do not attempt to begin scroll
            return;
            break;
        }
            
    } //end of marqueeType switch
    
    if (!self.tapToScroll && !self.holdScrolling && beginScroll) {
        [self beginScroll];
    }
}

- (CGSize)subLabelSize {
    // Calculate expected size
    CGSize expectedLabelSize = CGSizeZero;
    CGSize maximumLabelSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    
    // Get size of subLabel
    expectedLabelSize = [self.subLabel sizeThatFits:maximumLabelSize];
#ifdef TARGET_OS_IOS
    // Sanitize width to 5461.0f (largest width a UILabel will draw on an iPhone 6S Plus)
    expectedLabelSize.width = MIN(expectedLabelSize.width, 5461.0f);
#elif TARGET_OS_TV
    // Sanitize width to 16384.0 (largest width a UILabel will draw on tvOS)
    expectedLabelSize.width = MIN(expectedLabelSize.width, 16384.0f);
#endif
    // Adjust to own height (make text baseline match normal label)
    expectedLabelSize.height = self.bounds.size.height;
    
    return expectedLabelSize;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fitSize = [self.subLabel sizeThatFits:size];
    fitSize.width += self.leadingBuffer;
    return fitSize;
}

#pragma mark - Animation Handlers

- (BOOL)labelShouldScroll {
    BOOL stringLength = ([self.subLabel.text length] > 0);
    if (!stringLength) {
        return NO;
    }
    
    BOOL labelTooLarge = ([self subLabelSize].width + self.leadingBuffer > self.bounds.size.width + FLT_EPSILON);
    BOOL animationHasDuration = (self.scrollDuration > 0.0f || self.rate > 0.0f);
    return (!self.labelize && labelTooLarge && animationHasDuration);
}

- (BOOL)labelReadyForScroll {
    // Check if we have a superview
    if (!self.superview) {
        return NO;
    }
    
    if (!self.window) {
        return NO;
    }
    
    // Check if our view controller is ready
    UIViewController *viewController = [self firstAvailableViewController];
    if (!viewController.isViewLoaded) {
        return NO;
    }
    
    return YES;
}

- (void)beginScroll {
    [self beginScrollWithDelay:YES];
}

- (void)beginScrollWithDelay:(BOOL)delay {
    switch (self.marqueeType) {
        case MLContinuous:
        case MLContinuousReverse:
            [self scrollContinuousWithInterval:self.animationDuration after:(delay ? self.animationDelay : 0.0)];
            break;
        case MLLeft:
        case MLRight:
            [self scrollAwayWithInterval:self.animationDuration delayAmount:(delay ? self.animationDelay : 0.0) shouldReturn:NO];
            break;
        default:
            [self scrollAwayWithInterval:self.animationDuration];
            break;
    }
}

- (void)returnLabelToOriginImmediately {
    // Remove gradient animations
    [self.layer.mask removeAllAnimations];
    
    // Remove sublabel position animations
    [self.subLabel.layer removeAllAnimations];
    
    // Remove compeltion blocks
    self.scrollCompletionBlock = nil;
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval {
    [self scrollAwayWithInterval:interval delay:YES];
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval delay:(BOOL)delay {
    [self scrollAwayWithInterval:interval delayAmount:(delay ? self.animationDelay : 0.0) shouldReturn:YES];
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval delayAmount:(NSTimeInterval)delayAmount shouldReturn:(BOOL)shouldReturn {
    // Check for conditions which would prevent scrolling
    if (![self labelReadyForScroll]) {
        return;
    }
    
    // Return labels to home (cancel any animations)
    [self returnLabelToOriginImmediately];
    
    // Call pre-animation method
    [self labelWillBeginScroll];
    
    // Animate
    [CATransaction begin];
    
    // Set Duration
    [CATransaction setAnimationDuration:(!shouldReturn ? CGFLOAT_MAX : 2.0 * (delayAmount + interval))];
    
    // Create animation for gradient, if needed
    if (self.fadeLength != 0.0f) {
        CAKeyframeAnimation *gradAnim = [self keyFrameAnimationForGradientFadeLength:self.fadeLength
                                                                            interval:interval
                                                                               delay:delayAmount];
        [self.layer.mask addAnimation:gradAnim forKey:@"gradient"];
    }
    
    __weak __typeof__(self) weakSelf = self;
    self.scrollCompletionBlock = ^(BOOL finished) {
        if (!weakSelf) {
            return;
        }
        
        // Call returned home method
        [weakSelf labelReturnedToHome:YES];
        
        // Check to ensure that:
        // 1) The instance is still attached to a window - this completion block is called for
        //    many reasons, including if the animation is removed due to the view being removed
        //    from the UIWindow (typically when the view controller is no longer the "top" view)
        if (!weakSelf.window) {
            return;
        }
        // 2) We don't double fire if an animation already exists
        if ([weakSelf.subLabel.layer animationForKey:@"position"]) {
            return;
        }
        // 3) We don't not start automatically if the animation was unexpectedly interrupted
        if (!finished) {
            // Do not continue into the next loop
            return;
        }
        // 4) A completion block still exists for the NEXT loop. A notable case here is if
        // returnLabelToHome was called during a subclass's labelReturnToHome function
        if (!weakSelf.scrollCompletionBlock) {
            return;
        }
        
        // Begin again, if conditions met
        if (weakSelf.labelShouldScroll && !weakSelf.tapToScroll && !weakSelf.holdScrolling) {
            [weakSelf scrollAwayWithInterval:interval delayAmount:delayAmount shouldReturn:shouldReturn];
        }
    };
    
    
    // Create animation for position
    CGPoint homeOrigin = self.homeLabelFrame.origin;
    CGPoint awayOrigin = MLOffsetCGPoint(self.homeLabelFrame.origin, self.awayOffset);
    
    NSArray *values = nil;
    switch (self.marqueeType) {
        case MLLeft:
        case MLRight:
            values = @[[NSValue valueWithCGPoint:homeOrigin],      // Initial location, home
                       [NSValue valueWithCGPoint:homeOrigin],      // Initial delay, at home
                       [NSValue valueWithCGPoint:awayOrigin],      // Animation to away
                       [NSValue valueWithCGPoint:awayOrigin]];     // Delay at away
            break;
            
        default:
            values = @[[NSValue valueWithCGPoint:homeOrigin],      // Initial location, home
                       [NSValue valueWithCGPoint:homeOrigin],      // Initial delay, at home
                       [NSValue valueWithCGPoint:awayOrigin],      // Animation to away
                       [NSValue valueWithCGPoint:awayOrigin],      // Delay at away
                       [NSValue valueWithCGPoint:homeOrigin]];     // Animation to home
            break;
    }
    
    CAKeyframeAnimation *awayAnim = [self keyFrameAnimationForProperty:@"position"
                                                                values:values
                                                              interval:interval
                                                                 delay:delayAmount];
    // Add completion block
    [awayAnim setValue:@(YES) forKey:kMarqueeLabelAnimationCompletionBlock];
    
    // Add animation
    [self.subLabel.layer addAnimation:awayAnim forKey:@"position"];
    
    [CATransaction commit];
}

- (void)scrollContinuousWithInterval:(NSTimeInterval)interval after:(NSTimeInterval)delayAmount {
    [self scrollContinuousWithInterval:interval after:delayAmount labelAnimation:nil gradientAnimation:nil];
}

- (void)scrollContinuousWithInterval:(NSTimeInterval)interval
                               after:(NSTimeInterval)delayAmount
                      labelAnimation:(CAKeyframeAnimation *)labelAnimation
                   gradientAnimation:(CAKeyframeAnimation *)gradientAnimation {
    // Check for conditions which would prevent scrolling
    if (![self labelReadyForScroll]) {
        return;
    }
    
    // Return labels to home (cancel any animations)
    [self returnLabelToOriginImmediately];
    
    // Call pre-animation method
    [self labelWillBeginScroll];
    
    // Animate
    [CATransaction begin];
    
    // Set Duration
    [CATransaction setAnimationDuration:(delayAmount + interval)];
    
    // Create animation for gradient, if needed
    if (self.fadeLength != 0.0f) {
        if (!gradientAnimation) {
            gradientAnimation = [self keyFrameAnimationForGradientFadeLength:self.fadeLength
                                                                    interval:interval
                                                                       delay:delayAmount];
        }
        [self.layer.mask addAnimation:gradientAnimation forKey:@"gradient"];
    }
    
    // Create animation for sublabel positions, if needed
    if (!labelAnimation) {
        CGPoint homeOrigin = self.homeLabelFrame.origin;
        CGPoint awayOrigin = MLOffsetCGPoint(self.homeLabelFrame.origin, self.awayOffset);
        NSArray *values = @[[NSValue valueWithCGPoint:homeOrigin],      // Initial location, home
                            [NSValue valueWithCGPoint:homeOrigin],      // Initial delay, at home
                            [NSValue valueWithCGPoint:awayOrigin]];     // Animation to home
        
        labelAnimation = [self keyFrameAnimationForProperty:@"position"
                                                     values:values
                                                   interval:interval
                                                      delay:delayAmount];
    }
    
    __weak __typeof__(self) weakSelf = self;
    self.scrollCompletionBlock = ^(BOOL finished) {
        if (!finished || !weakSelf) {
            // Do not continue into the next loop
            return;
        }
        // Call returned home method
        [weakSelf labelReturnedToHome:YES];
        // Check to ensure that:
        // 1) We don't double fire if an animation already exists
        // 2) The instance is still attached to a window - this completion block is called for
        //    many reasons, including if the animation is removed due to the view being removed
        //    from the UIWindow (typically when the view controller is no longer the "top" view)
        if (weakSelf.window && ![weakSelf.subLabel.layer animationForKey:@"position"]) {
            // Begin again, if conditions met
            if (weakSelf.labelShouldScroll && !weakSelf.tapToScroll && !weakSelf.holdScrolling) {
                [weakSelf scrollContinuousWithInterval:interval
                                             after:delayAmount
                                    labelAnimation:labelAnimation
                                 gradientAnimation:gradientAnimation];
            }
        }
    };
    
    
    // Attach completion block
    [labelAnimation setValue:@(YES) forKey:kMarqueeLabelAnimationCompletionBlock];
    
    // Add animation
    [self.subLabel.layer addAnimation:labelAnimation forKey:@"position"];
    
    [CATransaction commit];
}

- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength animated:(BOOL)animated {
    
    // Remove any in-flight animations
    [self.layer.mask removeAllAnimations];
    
    // Check for zero-length fade
    if (fadeLength <= 0.0f) {
        [self removeGradientMask];
        return;
    }
    
    // Configure gradient mask without implicit animations
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    CAGradientLayer *gradientMask = (CAGradientLayer *)self.layer.mask;
    
    // Set up colors
    NSObject *transparent = (NSObject *)[[UIColor clearColor] CGColor];
    NSObject *opaque = (NSObject *)[[UIColor blackColor] CGColor];
    
    if (!gradientMask) {
        // Create CAGradientLayer if needed
        gradientMask = [CAGradientLayer layer];
        gradientMask.shouldRasterize = YES;
        gradientMask.rasterizationScale = [UIScreen mainScreen].scale;
        gradientMask.startPoint = CGPointMake(0.0f, 0.5f);
        gradientMask.endPoint = CGPointMake(1.0f, 0.5f);
    }
    
    // Check if there is a mask-to-bounds size mismatch
    if (!CGRectEqualToRect(gradientMask.bounds, self.bounds)) {
        // Adjust stops based on fade length
        CGFloat leftFadeStop = fadeLength/self.bounds.size.width;
        CGFloat rightFadeStop = fadeLength/self.bounds.size.width;
        gradientMask.locations = @[@(0.0f), @(leftFadeStop), @(1.0f - rightFadeStop), @(1.0f)];
    }
    
    gradientMask.bounds = self.layer.bounds;
    gradientMask.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    
    // Set mask
    self.layer.mask = gradientMask;
    
    // Determine colors for non-scrolling label (i.e. at home)
    NSArray *adjustedColors;
    BOOL trailingFadeNeeded = self.labelShouldScroll;
    switch (self.marqueeType) {
        case MLContinuousReverse:
        case MLRightLeft:
        case MLRight:
            adjustedColors = @[(trailingFadeNeeded ? transparent : opaque),
                               opaque,
                               opaque,
                               opaque];
            break;
            
        default:
            // MLContinuous
            // MLLeftRight
            adjustedColors = @[opaque,
                               opaque,
                               opaque,
                               (trailingFadeNeeded ? transparent : opaque)];
            break;
    }
    
    // Check for IBDesignable
#if TARGET_INTERFACE_BUILDER
    animated = NO;
#endif
    
    if (animated) {
        // Finish transaction
        [CATransaction commit];
        
        // Create animation for color change
        GradientSetupAnimation *colorAnimation = [GradientSetupAnimation animationWithKeyPath:@"colors"];
        colorAnimation.fromValue = gradientMask.colors;
        colorAnimation.toValue = adjustedColors;
        colorAnimation.duration = 0.25;
        colorAnimation.removedOnCompletion = NO;
        colorAnimation.delegate = self;
        [gradientMask addAnimation:colorAnimation forKey:@"setupFade"];
    } else {
        gradientMask.colors = adjustedColors;
        [CATransaction commit];
    }
}

- (void)removeGradientMask {
    self.layer.mask = nil;
}

- (CAKeyframeAnimation *)keyFrameAnimationForGradientFadeLength:(CGFloat)fadeLength
                                                       interval:(NSTimeInterval)interval
                                                          delay:(NSTimeInterval)delayAmount
{
    // Setup
    NSArray *values = nil;
    NSArray *keyTimes = nil;
    NSTimeInterval totalDuration;
    NSObject *transp = (NSObject *)[[UIColor clearColor] CGColor];
    NSObject *opaque = (NSObject *)[[UIColor blackColor] CGColor];
    
    // Create new animation
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"colors"];
    
    // Get timing function
    CAMediaTimingFunction *timingFunction = [self timingFunctionForAnimationOptions:self.animationCurve];
    
    // Define keyTimes
    switch (self.marqueeType) {
        case MLLeftRight:
        case MLRightLeft:
            // Calculate total animation duration
            totalDuration = 2.0 * (delayAmount + interval);
            keyTimes = @[@(0.0),                                                        // 1) Initial gradient
                         @(delayAmount/totalDuration),                                  // 2) Begin of LE fade-in, just as scroll away starts
                         @((delayAmount + 0.4)/totalDuration),                          // 3) End of LE fade in [LE fully faded]
                         @((delayAmount + interval - 0.4)/totalDuration),               // 4) Begin of TE fade out, just before scroll away finishes
                         @((delayAmount + interval)/totalDuration),                     // 5) End of TE fade out [TE fade removed]
                         @((delayAmount + interval + delayAmount)/totalDuration),       // 6) Begin of TE fade back in, just as scroll home starts
                         @((delayAmount + interval + delayAmount + 0.4)/totalDuration), // 7) End of TE fade back in [TE fully faded]
                         @((totalDuration - 0.4)/totalDuration),                        // 8) Begin of LE fade out, just before scroll home finishes
                         @(1.0)];                                                       // 9) End of LE fade out, just as scroll home finishes
            break;
            
        case MLLeft:
        case MLRight:
            // Calculate total animation duration
            totalDuration = CGFLOAT_MAX;
            keyTimes = @[@(0.0),                                                        // 1) Initial gradient
                         @(delayAmount/totalDuration),                                  // 2) Begin of LE fade-in, just as scroll away starts
                         @((delayAmount + 0.4)/totalDuration),                          // 3) End of LE fade in [LE fully faded]
                         @((delayAmount + interval - 0.4)/totalDuration),               // 4) Begin of TE fade out, just before scroll away finishes
                         @((delayAmount + interval)/totalDuration),                     // 5) End of TE fade out [TE fade removed]
                         @(1.0)];                                                       
            break;
        case MLContinuousReverse:
        default:
            // Calculate total animation duration
            totalDuration = delayAmount + interval;
            
            // Find when the lead label will be totally offscreen
            CGFloat startFadeFraction = fabs((self.subLabel.bounds.size.width + self.leadingBuffer) / self.awayOffset);
            // Find when the animation will hit that point
            CGFloat startFadeTimeFraction = [timingFunction durationPercentageForPositionPercentage:startFadeFraction withDuration:totalDuration];
            NSTimeInterval startFadeTime = delayAmount + startFadeTimeFraction * interval;
            
            keyTimes = @[
                         @(0.0),                                            // Initial gradient
                         @(delayAmount/totalDuration),                      // Begin of fade in
                         @((delayAmount + 0.2)/totalDuration),              // End of fade in, just as scroll away starts
                         @((startFadeTime)/totalDuration),                  // Begin of fade out, just before scroll home completes
                         @((startFadeTime + 0.1)/totalDuration),            // End of fade out, as scroll home completes
                         @(1.0)                                             // Buffer final value (used on continuous types)
                         ];
            break;
    }
    
    // Define gradient values
    // Get curent layer values
    CAGradientLayer *currentMask = [[self maskLayer] presentationLayer];
    NSArray *currentValues = currentMask.colors;
    
    switch (self.marqueeType) {
        case MLContinuousReverse:
            values = @[
                       (currentValues ? currentValues : @[transp, opaque, opaque, opaque]),           // Initial gradient
                       @[transp, opaque, opaque, opaque],           // Begin of fade in
                       @[transp, opaque, opaque, transp],           // End of fade in, just as scroll away starts
                       @[transp, opaque, opaque, transp],           // Begin of fade out, just before scroll home completes
                       @[transp, opaque, opaque, opaque],           // End of fade out, as scroll home completes
                       @[transp, opaque, opaque, opaque]            // Final "home" value
                       ];
            break;
            
        case MLRight:
            values = @[
                       (currentValues ? currentValues : @[transp, opaque, opaque, opaque]),           // 1)
                       @[transp, opaque, opaque, opaque],           // 2)
                       @[transp, opaque, opaque, transp],           // 3)
                       @[transp, opaque, opaque, transp],           // 4)
                       @[opaque, opaque, opaque, transp],           // 5)
                       @[opaque, opaque, opaque, transp],           // 6)
                       ];
            break;
            
        case MLRightLeft:
            values = @[
                       (currentValues ? currentValues : @[transp, opaque, opaque, opaque]),           // 1)
                       @[transp, opaque, opaque, opaque],           // 2)
                       @[transp, opaque, opaque, transp],           // 3)
                       @[transp, opaque, opaque, transp],           // 4)
                       @[opaque, opaque, opaque, transp],           // 5)
                       @[opaque, opaque, opaque, transp],           // 6)
                       @[transp, opaque, opaque, transp],           // 7)
                       @[transp, opaque, opaque, transp],           // 8)
                       @[transp, opaque, opaque, opaque]            // 9)
                       ];
            break;
            
        case MLContinuous:
            values = @[
                       (currentValues ? currentValues : @[opaque, opaque, opaque, transp]),           // Initial gradient
                       @[opaque, opaque, opaque, transp],           // Begin of fade in
                       @[transp, opaque, opaque, transp],           // End of fade in, just as scroll away starts
                       @[transp, opaque, opaque, transp],           // Begin of fade out, just before scroll home completes
                       @[opaque, opaque, opaque, transp],           // End of fade out, as scroll home completes
                       @[opaque, opaque, opaque, transp]            // Final "home" value
                       ];
            break;
            
        case MLLeft:
            values = @[
                       (currentValues ? currentValues : @[opaque, opaque, opaque, transp]),           // 1)
                       @[opaque, opaque, opaque, transp],           // 2)
                       @[transp, opaque, opaque, transp],           // 3)
                       @[transp, opaque, opaque, transp],           // 4)
                       @[transp, opaque, opaque, opaque],           // 5)
                       @[transp, opaque, opaque, opaque],           // 6)
                       ];
            break;
            
        case MLLeftRight:
        default:
            values = @[
                       (currentValues ? currentValues : @[opaque, opaque, opaque, transp]),           // 1)
                       @[opaque, opaque, opaque, transp],           // 2)
                       @[transp, opaque, opaque, transp],           // 3)
                       @[transp, opaque, opaque, transp],           // 4)
                       @[transp, opaque, opaque, opaque],           // 5)
                       @[transp, opaque, opaque, opaque],           // 6)
                       @[transp, opaque, opaque, transp],           // 7)
                       @[transp, opaque, opaque, transp],           // 8)
                       @[opaque, opaque, opaque, transp]            // 9)
                       ];
            break;
    }
    
    animation.values = values;
    animation.keyTimes = keyTimes;
    animation.timingFunctions = @[timingFunction, timingFunction, timingFunction, timingFunction];
    
    return animation;
}

- (CAKeyframeAnimation *)keyFrameAnimationForProperty:(NSString *)property
                                               values:(NSArray *)values
                                             interval:(NSTimeInterval)interval
                                                delay:(NSTimeInterval)delayAmount
{
    // Create new animation
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:property];
    
    // Get timing function
    CAMediaTimingFunction *timingFunction = [self timingFunctionForAnimationOptions:self.animationCurve];
    
    // Calculate times based on marqueeType
    NSTimeInterval totalDuration;
    switch (self.marqueeType) {
        case MLLeftRight:
        case MLRightLeft:
            NSAssert(values.count == 5, @"Incorrect number of values passed for MLLeftRight-type animation");
            totalDuration = 2.0 * (delayAmount + interval);
            // Set up keyTimes
            animation.keyTimes = @[@(0.0),                                                   // Initial location, home
                                   @(delayAmount/totalDuration),                             // Initial delay, at home
                                   @((delayAmount + interval)/totalDuration),                // Animation to away
                                   @((delayAmount + interval + delayAmount)/totalDuration),  // Delay at away
                                   @(1.0)];                                                  // Animation to home
            
            animation.timingFunctions = @[timingFunction,
                                          timingFunction,
                                          timingFunction,
                                          timingFunction];
            
            break;
            
        case MLLeft:
        case MLRight:
            NSAssert(values.count == 4, @"Incorrect number of values passed for MLLeft-type animation");
            totalDuration = CGFLOAT_MAX;
            // Set up keyTimes
            animation.keyTimes = @[@(0.0),                                                   // Initial location, home
                                   @(delayAmount/totalDuration),                             // Initial delay, at home
                                   @((delayAmount + interval)/totalDuration),                // Animation to away
                                   @(1.0)];                                                  // Animation to home
            
            animation.timingFunctions = @[timingFunction,
                                          timingFunction,
                                          timingFunction];
            
            break;
            
            // MLContinuous
            // MLContinuousReverse
        default:
            NSAssert(values.count == 3, @"Incorrect number of values passed for MLContinous-type animation");
            totalDuration = delayAmount + interval;
            // Set up keyTimes
            animation.keyTimes = @[@(0.0),                              // Initial location, home
                                   @(delayAmount/totalDuration),        // Initial delay, at home
                                   @(1.0)];                             // Animation to away
            
            animation.timingFunctions = @[timingFunction,
                                          timingFunction];
            
            break;
    }
    
    // Set values
    animation.values = values;
    animation.delegate = self;
    
    return animation;
}

- (CAMediaTimingFunction *)timingFunctionForAnimationOptions:(UIViewAnimationOptions)animationOptions {
    NSString *timingFunction;
    switch (animationOptions) {
        case UIViewAnimationOptionCurveEaseIn:
            timingFunction = kCAMediaTimingFunctionEaseIn;
            break;
            
        case UIViewAnimationOptionCurveEaseInOut:
            timingFunction = kCAMediaTimingFunctionEaseInEaseOut;
            break;
            
        case UIViewAnimationOptionCurveEaseOut:
            timingFunction = kCAMediaTimingFunctionEaseOut;
            break;
            
        default:
            timingFunction = kCAMediaTimingFunctionLinear;
            break;
    }
    
    return [CAMediaTimingFunction functionWithName:timingFunction];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if ([anim isMemberOfClass:[GradientSetupAnimation class]]) {
        GradientSetupAnimation *setupFade = (GradientSetupAnimation *)anim;
        NSArray *finalColors = setupFade.toValue;
        if (finalColors) {
            [(CAGradientLayer *)self.layer.mask setColors:finalColors];
        }
        // Remove any/all setupFade animations regardless
        [self.layer.mask removeAnimationForKey:@"setupFade"];
    } else {
        if (self.scrollCompletionBlock) {
            self.scrollCompletionBlock(flag);
        }
    }
}

#pragma mark - Label Control

- (void)restartLabel {
    // Shutdown the label
    [self shutdownLabel];
    // Restart scrolling if appropriate
    if (self.labelShouldScroll && !self.tapToScroll && !self.holdScrolling) {
        [self beginScroll];
    }
}

- (void)resetLabel {
    [self returnLabelToOriginImmediately];
    self.homeLabelFrame = CGRectNull;
    self.awayOffset = 0.0f;
}

- (void)shutdownLabel {
    // Bring label to home location
    [self returnLabelToOriginImmediately];
    // Apply gradient mask for home location
    [self applyGradientMaskForFadeLength:self.fadeLength animated:false];
}

-(void)pauseLabel
{
    // Only pause if label is not already paused, and already in a scrolling animation
    if (!self.isPaused && self.awayFromHome) {
        // Pause sublabel position animation
        CFTimeInterval labelPauseTime = [self.subLabel.layer convertTime:CACurrentMediaTime() fromLayer:nil];
        self.subLabel.layer.speed = 0.0;
        self.subLabel.layer.timeOffset = labelPauseTime;
        // Pause gradient fade animation
        CFTimeInterval gradientPauseTime = [self.layer.mask convertTime:CACurrentMediaTime() fromLayer:nil];
        self.layer.mask.speed = 0.0;
        self.layer.mask.timeOffset = gradientPauseTime;
        
        self.isPaused = YES;
    }
}

-(void)unpauseLabel
{
    if (self.isPaused) {
        // Unpause sublabel position animation
        CFTimeInterval labelPausedTime = self.subLabel.layer.timeOffset;
        self.subLabel.layer.speed = 1.0;
        self.subLabel.layer.timeOffset = 0.0;
        self.subLabel.layer.beginTime = 0.0;
        self.subLabel.layer.beginTime = [self.subLabel.layer convertTime:CACurrentMediaTime() fromLayer:nil] - labelPausedTime;
        // Unpause gradient fade animation
        CFTimeInterval gradientPauseTime = self.layer.mask.timeOffset;
        self.layer.mask.speed = 1.0;
        self.layer.mask.timeOffset = 0.0;
        self.layer.mask.beginTime = 0.0;
        self.layer.mask.beginTime = [self.layer.mask convertTime:CACurrentMediaTime() fromLayer:nil] - gradientPauseTime;
        
        self.isPaused = NO;
    }
}

- (void)labelWasTapped:(UITapGestureRecognizer *)recognizer {
    if (self.labelShouldScroll && !self.awayFromHome) {
        [self beginScrollWithDelay:NO];
    }
}

- (void)triggerScrollStart {
    if (self.labelShouldScroll && !self.awayFromHome) {
        [self beginScroll];
    }
}

- (void)labelWillBeginScroll {
    // Default implementation does nothing
    return;
}

- (void)labelReturnedToHome:(BOOL)finished {
    // Default implementation does nothing
    return;
}

#pragma mark - Modified UIView Methods/Getters/Setters

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    // Check if device is running iOS 8.0.X
    if(SYSTEM_VERSION_IS_8_0_X) {
        // If so, force update because layoutSubviews is not called
        [self updateSublabel];
    }
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    
    // Check if device is running iOS 8.0.X
    if(SYSTEM_VERSION_IS_8_0_X) {
        // If so, force update because layoutSubviews is not called
        [self updateSublabel];
    }
    
}

#pragma mark - Modified UILabel Methods/Getters/Setters

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 100000 && !(TARGET_OS_TV)
- (UIView *)viewForBaselineLayout {
    // Use subLabel view for handling baseline layouts
    return self.subLabel;
}
#endif

- (UIView *)viewForLastBaselineLayout {
    // Use subLabel view for handling baseline layouts
    return self.subLabel;
}

- (UIView *)viewForFirstBaselineLayout {
    // Use subLabel view for handling baseline layouts
    return self.subLabel;
}

- (NSString *)text {
    return self.subLabel.text;
}

- (void)setText:(NSString *)text {
    if ([text isEqualToString:self.subLabel.text]) {
        return;
    }
    self.subLabel.text = text;
    super.text = text;
    [self updateSublabel];
}

- (NSAttributedString *)attributedText {
    return self.subLabel.attributedText;
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if ([attributedText isEqualToAttributedString:self.subLabel.attributedText]) {
        return;
    }
    self.subLabel.attributedText = attributedText;
    super.attributedText = attributedText;
    [self updateSublabel];
}

- (UIFont *)font {
    return self.subLabel.font;
}

- (void)setFont:(UIFont *)font {
    if ([font isEqual:self.subLabel.font]) {
        return;
    }
    self.subLabel.font = font;
    super.font = font;
    [self updateSublabel];
}

- (UIColor *)textColor {
    return self.subLabel.textColor;
}

- (void)setTextColor:(UIColor *)textColor {
    self.subLabel.textColor = textColor;
    super.textColor = textColor;
}

- (UIColor *)backgroundColor {
    return self.subLabel.backgroundColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    self.subLabel.backgroundColor = backgroundColor;
    super.backgroundColor = backgroundColor;
}

- (UIColor *)shadowColor {
    return self.subLabel.shadowColor;
}

- (void)setShadowColor:(UIColor *)shadowColor {
    self.subLabel.shadowColor = shadowColor;
    super.shadowColor = shadowColor;
}

- (CGSize)shadowOffset {
    return self.subLabel.shadowOffset;
}

- (void)setShadowOffset:(CGSize)shadowOffset {
    self.subLabel.shadowOffset = shadowOffset;
    super.shadowOffset = shadowOffset;
}

- (UIColor *)highlightedTextColor {
    return self.subLabel.highlightedTextColor;
}

- (void)setHighlightedTextColor:(UIColor *)highlightedTextColor {
    self.subLabel.highlightedTextColor = highlightedTextColor;
    super.highlightedTextColor = highlightedTextColor;
}

- (BOOL)isHighlighted {
    return self.subLabel.isHighlighted;
}

- (void)setHighlighted:(BOOL)highlighted {
    self.subLabel.highlighted = highlighted;
    super.highlighted = highlighted;
}

- (BOOL)isEnabled {
    return self.subLabel.isEnabled;
}

- (void)setEnabled:(BOOL)enabled {
    self.subLabel.enabled = enabled;
    super.enabled = enabled;
}

- (void)setNumberOfLines:(NSInteger)numberOfLines {
    // By the nature of MarqueeLabel, this is 1
    [super setNumberOfLines:1];
}

- (void)setAdjustsFontSizeToFitWidth:(BOOL)adjustsFontSizeToFitWidth {
    // By the nature of MarqueeLabel, this is NO
    [super setAdjustsFontSizeToFitWidth:NO];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
- (void)setMinimumFontSize:(CGFloat)minimumFontSize {
    [super setMinimumFontSize:0.0];
}
#endif

- (UIBaselineAdjustment)baselineAdjustment {
    return self.subLabel.baselineAdjustment;
}

- (void)setBaselineAdjustment:(UIBaselineAdjustment)baselineAdjustment {
    self.subLabel.baselineAdjustment = baselineAdjustment;
    super.baselineAdjustment = baselineAdjustment;
}

- (UIColor *)tintColor {
    return self.subLabel.tintColor;
}

- (void)setTintColor:(UIColor *)tintColor {
    self.subLabel.tintColor = tintColor;
    super.tintColor = tintColor;
}

- (void)tintColorDidChange {
    [super tintColorDidChange];
    [self.subLabel tintColorDidChange];
}

- (CGSize)intrinsicContentSize {
    CGSize contentSize = self.subLabel.intrinsicContentSize;
    contentSize.width += self.leadingBuffer;
    return contentSize;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
- (void)setAdjustsLetterSpacingToFitWidth:(BOOL)adjustsLetterSpacingToFitWidth {
    // By the nature of MarqueeLabel, this is NO
    [super setAdjustsLetterSpacingToFitWidth:NO];
}
#endif

- (void)setMinimumScaleFactor:(CGFloat)minimumScaleFactor {
    [super setMinimumScaleFactor:0.0f];
}

- (UIViewContentMode)contentMode {
    return self.subLabel.contentMode;
}

- (void)setContentMode:(UIViewContentMode)contentMode {
    super.contentMode = contentMode;
    self.subLabel.contentMode = contentMode;
}

- (void)setIsAccessibilityElement:(BOOL)isAccessibilityElement {
    [super setIsAccessibilityElement:isAccessibilityElement];
    self.subLabel.isAccessibilityElement = isAccessibilityElement;
}

#pragma mark - Custom Getters and Setters

- (void)setRate:(CGFloat)rate {
    if (_rate == rate) {
        return;
    }
    
    _scrollDuration = 0.0f;
    _rate = rate;
    [self updateSublabel];
}

- (void)setScrollDuration:(CGFloat)lengthOfScroll {
    if (_scrollDuration == lengthOfScroll) {
        return;
    }
    
    _rate = 0.0f;
    _scrollDuration = lengthOfScroll;
    [self updateSublabel];
}

- (void)setAnimationCurve:(UIViewAnimationOptions)animationCurve {
    if (_animationCurve == animationCurve) {
        return;
    }
    
    NSUInteger allowableOptions = UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionCurveLinear;
    if ((allowableOptions & animationCurve) == animationCurve) {
        _animationCurve = animationCurve;
    }
}

- (void)setLeadingBuffer:(CGFloat)leadingBuffer {
    if (_leadingBuffer == leadingBuffer) {
        return;
    }
    
    // Do not allow negative values
    _leadingBuffer = fabs(leadingBuffer);
    [self updateSublabel];
}

- (void)setTrailingBuffer:(CGFloat)trailingBuffer {
    if (_trailingBuffer == trailingBuffer) {
        return;
    }
    
    // Do not allow negative values
    _trailingBuffer = fabs(trailingBuffer);
    [self updateSublabel];
}

- (void)setContinuousMarqueeExtraBuffer:(CGFloat)continuousMarqueeExtraBuffer {
    [self setTrailingBuffer:continuousMarqueeExtraBuffer];
}

- (CGFloat)continuousMarqueeExtraBuffer {
    return self.trailingBuffer;
}

- (void)setFadeLength:(CGFloat)fadeLength {
    if (_fadeLength == fadeLength) {
        return;
    }
    
    _fadeLength = fadeLength;
    
    [self updateSublabel];
}

- (void)setTapToScroll:(BOOL)tapToScroll {
    if (_tapToScroll == tapToScroll) {
        return;
    }
    
    _tapToScroll = tapToScroll;
    
    if (_tapToScroll) {
        UITapGestureRecognizer *newTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelWasTapped:)];
        [self addGestureRecognizer:newTapRecognizer];
        self.tapRecognizer = newTapRecognizer;
        self.userInteractionEnabled = YES;
    } else {
        [self removeGestureRecognizer:self.tapRecognizer];
        self.tapRecognizer = nil;
        self.userInteractionEnabled = NO;
    }
}

- (void)setMarqueeType:(MarqueeType)marqueeType {
    if (marqueeType == _marqueeType) {
        return;
    }
    
    _marqueeType = marqueeType;
    
    [self updateSublabel];
}

- (void)setLabelize:(BOOL)labelize {
    if (_labelize == labelize) {
        return;
    }
    
    _labelize = labelize;
    
    [self updateSublabelAndBeginScroll:YES];
}

- (void)setHoldScrolling:(BOOL)holdScrolling {
    if (_holdScrolling == holdScrolling) {
        return;
    }
    
    _holdScrolling = holdScrolling;
    
    if (!holdScrolling && !(self.awayFromHome || self.labelize || self.tapToScroll) && self.labelShouldScroll) {
        [self beginScroll];
    }
}

- (BOOL)awayFromHome {
    CALayer *presentationLayer = self.subLabel.layer.presentationLayer;
    if (!presentationLayer) {
        return NO;
    }
    return !(presentationLayer.position.x == self.homeLabelFrame.origin.x);
}

#pragma mark - Support

- (NSArray *)gradientColors {
    if (!_gradientColors) {
        NSObject *transparent = (NSObject *)[[UIColor clearColor] CGColor];
        NSObject *opaque = (NSObject *)[[UIColor blackColor] CGColor];
        _gradientColors = [NSArray arrayWithObjects: transparent, opaque, opaque, transparent, nil];
    }
    return _gradientColors;
}

#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end



#pragma mark - Helpers

CGPoint MLOffsetCGPoint(CGPoint point, CGFloat offset) {
    return CGPointMake(point.x + offset, point.y);
}

@implementation GradientSetupAnimation

@end

@implementation UIView (MarqueeLabelHelpers)
// Thanks to Phil M
// http://stackoverflow.com/questions/1340434/get-to-uiviewcontroller-from-uiview-on-iphone

- (id)firstAvailableViewController
{
    // convenience function for casting and to "mask" the recursive function
    return [self traverseResponderChainForFirstViewController];
}

- (id)traverseResponderChainForFirstViewController
{
    id nextResponder = [self nextResponder];
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        return nextResponder;
    } else if ([nextResponder isKindOfClass:[UIView class]]) {
        return [nextResponder traverseResponderChainForFirstViewController];
    } else {
        return nil;
    }
}

@end

@implementation CAMediaTimingFunction (MarqueeLabelHelpers)

- (CGFloat)durationPercentageForPositionPercentage:(CGFloat)positionPercentage withDuration:(NSTimeInterval)duration
{
    // Finds the animation duration percentage that corresponds with the given animation "position" percentage.
    // Utilizes Newton's Method to solve for the parametric Bezier curve that is used by CAMediaAnimation.
    
    NSArray *controlPoints = [self controlPoints];
    CGFloat epsilon = 1.0f / (100.0f * duration);
    
    // Find the t value that gives the position percentage we want
    CGFloat t_found = [self solveTForY:positionPercentage
                           withEpsilon:epsilon
                         controlPoints:controlPoints];
    
    // With that t, find the corresponding animation percentage
    CGFloat durationPercentage = [self XforCurveAt:t_found withControlPoints:controlPoints];
    
    return durationPercentage;
}

- (CGFloat)solveTForY:(CGFloat)y_0 withEpsilon:(CGFloat)epsilon controlPoints:(NSArray *)controlPoints
{
    // Use Newton's Method: http://en.wikipedia.org/wiki/Newton's_method
    // For first guess, use t = y (i.e. if curve were linear)
    CGFloat t0 = y_0;
    CGFloat t1 = y_0;
    CGFloat f0, df0;
    
    for (int i = 0; i < 15; i++) {
        // Base this iteration of t1 calculated from last iteration
        t0 = t1;
        // Calculate f(t0)
        f0 = [self YforCurveAt:t0 withControlPoints:controlPoints] - y_0;
        // Check if this is close (enough)
        if (fabs(f0) < epsilon) {
            // Done!
            return t0;
        }
        // Else continue Newton's Method
        df0 = [self derivativeYValueForCurveAt:t0 withControlPoints:controlPoints];
        // Check if derivative is small or zero ( http://en.wikipedia.org/wiki/Newton's_method#Failure_analysis )
        if (fabs(df0) < 1e-6) {
            NSLog(@"MarqueeLabel: Newton's Method failure, small/zero derivative!");
            break;
        }
        // Else recalculate t1
        t1 = t0 - f0/df0;
    }
    
    NSLog(@"MarqueeLabel: Failed to find t for Y input!");
    return t0;
}

- (CGFloat)YforCurveAt:(CGFloat)t withControlPoints:(NSArray *)controlPoints
{
    CGPoint P0 = [controlPoints[0] CGPointValue];
    CGPoint P1 = [controlPoints[1] CGPointValue];
    CGPoint P2 = [controlPoints[2] CGPointValue];
    CGPoint P3 = [controlPoints[3] CGPointValue];
    
    // Per http://en.wikipedia.org/wiki/Bezier_curve#Cubic_B.C3.A9zier_curves
    return  powf((1 - t),3) * P0.y +
    3.0f * powf(1 - t, 2) * t * P1.y +
    3.0f * (1 - t) * powf(t, 2) * P2.y +
    powf(t, 3) * P3.y;
    
}

- (CGFloat)XforCurveAt:(CGFloat)t withControlPoints:(NSArray *)controlPoints
{
    CGPoint P0 = [controlPoints[0] CGPointValue];
    CGPoint P1 = [controlPoints[1] CGPointValue];
    CGPoint P2 = [controlPoints[2] CGPointValue];
    CGPoint P3 = [controlPoints[3] CGPointValue];
    
    // Per http://en.wikipedia.org/wiki/Bezier_curve#Cubic_B.C3.A9zier_curves
    return  powf((1 - t),3) * P0.x +
    3.0f * powf(1 - t, 2) * t * P1.x +
    3.0f * (1 - t) * powf(t, 2) * P2.x +
    powf(t, 3) * P3.x;
    
}

- (CGFloat)derivativeYValueForCurveAt:(CGFloat)t withControlPoints:(NSArray *)controlPoints
{
    CGPoint P0 = [controlPoints[0] CGPointValue];
    CGPoint P1 = [controlPoints[1] CGPointValue];
    CGPoint P2 = [controlPoints[2] CGPointValue];
    CGPoint P3 = [controlPoints[3] CGPointValue];
    
    return  powf(t, 2) * (-3.0f * P0.y - 9.0f * P1.y - 9.0f * P2.y + 3.0f * P3.y) +
    t * (6.0f * P0.y + 6.0f * P2.y) +
    (-3.0f * P0.y + 3.0f * P1.y);
}

- (NSArray *)controlPoints
{
    float point[2];
    NSMutableArray *pointArray = [NSMutableArray array];
    for (int i = 0; i <= 3; i++) {
        [self getControlPointAtIndex:i values:point];
        [pointArray addObject:[NSValue valueWithCGPoint:CGPointMake(point[0], point[1])]];
    }
    
    return [NSArray arrayWithArray:pointArray];
}

@end
