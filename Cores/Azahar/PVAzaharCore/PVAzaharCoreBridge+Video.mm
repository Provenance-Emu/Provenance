#import "PVAzaharCoreBridge+Video.h"
#import "PVAzaharCoreBridge+Private.h"
#import <PVAzahar/PVAzahar-Swift.h>
#import <PVLogging/PVLoggingObjC.h>
@import PVCoreBridge;
#include "Glue/AzaharEmuWindow.h"

// Conformance lives on the category that defines the methods, so a missing one still warns.
#include <algorithm>
#include <cmath>

namespace {
u16 ToU16(CGFloat v) { return static_cast<u16>(std::clamp<CGFloat>(std::round(v), 0, 65535)); }

/// Window layout from bridge state, on the emu thread. A dual-screen skin's two rects become azahar's
/// custom layout for the current orientation; otherwise the user's layout options apply.
void ApplyLayoutSettings(bool skin, bool singleArea, CGRect top, CGRect bottom, NSInteger layoutOpt,
                         NSInteger portraitOpt, bool swap, bool portrait) {
    auto& v = Settings::values;
    v.swap_screen.SetValue(swap);
    ILOG(@"[PVAzahar] layout branch=%s", skin ? "skin" : (singleArea ? "singleArea" : "user"));
    if (!skin) {
        if (singleArea) {
            // One skin area holds both screens: a wide area reads as side by side, anything else
            // as stacked. The user's layout option only applies without a skin.
            v.layout_option.SetValue(portrait ? Settings::LayoutOption::Default : Settings::LayoutOption::SideScreen);
            v.portrait_layout_option.SetValue(Settings::PortraitLayoutOption::PortraitTopFullWidth);
        } else {
            v.layout_option.SetValue(PVAzaharLayoutOption(layoutOpt));
            v.portrait_layout_option.SetValue(PVAzaharPortraitLayoutOption(portraitOpt));
        }
        return;
    }
    if (portrait) {
        v.custom_portrait_top_x.SetValue(ToU16(top.origin.x));
        v.custom_portrait_top_y.SetValue(ToU16(top.origin.y));
        v.custom_portrait_top_width.SetValue(ToU16(top.size.width));
        v.custom_portrait_top_height.SetValue(ToU16(top.size.height));
        v.custom_portrait_bottom_x.SetValue(ToU16(bottom.origin.x));
        v.custom_portrait_bottom_y.SetValue(ToU16(bottom.origin.y));
        v.custom_portrait_bottom_width.SetValue(ToU16(bottom.size.width));
        v.custom_portrait_bottom_height.SetValue(ToU16(bottom.size.height));
        v.portrait_layout_option.SetValue(Settings::PortraitLayoutOption::PortraitCustomLayout);
    } else {
        v.custom_top_x.SetValue(ToU16(top.origin.x));
        v.custom_top_y.SetValue(ToU16(top.origin.y));
        v.custom_top_width.SetValue(ToU16(top.size.width));
        v.custom_top_height.SetValue(ToU16(top.size.height));
        v.custom_bottom_x.SetValue(ToU16(bottom.origin.x));
        v.custom_bottom_y.SetValue(ToU16(bottom.origin.y));
        v.custom_bottom_width.SetValue(ToU16(bottom.size.width));
        v.custom_bottom_height.SetValue(ToU16(bottom.size.height));
        v.layout_option.SetValue(Settings::LayoutOption::CustomLayout);
    }
}
} // namespace

@interface PVAzaharCoreBridge (ViewportPositioning) <EmulatorCoreViewportPositioning>
@end

@implementation PVAzaharCoreBridge (Video)

- (void)setupRenderView {
    if (!self.touchViewController) { ELOG(@"[PVAzahar] touchViewController is nil; host must set it before start"); return; }
    UIView *host = self.touchViewController.view;
    PVAzaharRenderView *view = [[PVAzaharRenderView alloc] initWithFrame:host.bounds];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    _renderView = view;
    // Stack just above the host GPU view when they share a superview (tvOS), else at the back.
    id renderDelegate = self.renderDelegate;
    UIViewController *gpuController = [renderDelegate isKindOfClass:[UIViewController class]] ? (UIViewController *)renderDelegate : nil;
    UIView *gpuView = gpuController.isViewLoaded ? gpuController.view : nil;
    if (gpuView && gpuView.superview == host) { [host insertSubview:view aboveSubview:gpuView]; }
    else { [host addSubview:view]; [host sendSubviewToBack:view]; }
    _renderViewConstraints = @[
        [view.topAnchor constraintEqualToAnchor:host.topAnchor],
        [view.bottomAnchor constraintEqualToAnchor:host.bottomAnchor],
        [view.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:host.trailingAnchor]];
    [NSLayoutConstraint activateConstraints:_renderViewConstraints];
    [host layoutIfNeeded];

    CAMetalLayer *layer = view.metalLayer;
    CGSize px = layer.drawableSize;
    if (px.width < 1 || px.height < 1) {
        // Host not laid out yet: fall back to the screen so azahar never builds a 0x0 layout.
        // The size-change callback below corrects it on the first real layout pass.
        const CGFloat scale = UIScreen.mainScreen.nativeScale;
        const CGSize pts = UIScreen.mainScreen.bounds.size;
        px = CGSizeMake(pts.width * scale, pts.height * scale);
        WLOG(@"[PVAzahar] render view has no size yet; using screen %@", NSStringFromCGSize(px));
    }
    const BOOL portrait = px.height > px.width;
    _window = std::make_unique<AzaharEmuWindow>(layer, (float)layer.contentsScale,
                                                (unsigned)px.width, (unsigned)px.height, portrait);

    __weak PVAzaharCoreBridge *weakSelf = self;
    // Layout-driven, not orientation notifications: those fire before bounds settle and don't exist on tvOS.
    view.onDrawableSizeChange = ^(CGSize size) { [weakSelf resizeWindowToPixelSize:size]; };
#if !TARGET_OS_TV
    view.onTouch = ^(UITouch *touch, BOOL ended) { [weakSelf sendTouchEvent:touch ended:ended]; };
#endif

    // Skin frames published before this view existed (the host does it in viewDidLoad) replay now,
    // so the first relayout already runs with the skin layout instead of waiting for a rotation.
    if (_hasPendingSkinFrames) {
        _hasPendingSkinFrames = NO;
        ILOG(@"[PVAzahar] replaying queued skin frames top=%@ bottom=%@", NSStringFromCGRect(_pendingSkinTop), NSStringFromCGRect(_pendingSkinBottom));
        [self applyDualScreenRenderFramesInTouchView:_pendingSkinTop bottom:_pendingSkinBottom];
    } else if (_hasPendingSingleArea) {
        _hasPendingSingleArea = NO;
        ILOG(@"[PVAzahar] replaying queued skin area %@", NSStringFromCGRect(_pendingSingleArea));
        [self applyRenderViewFrameInTouchView:_pendingSingleArea];
    }
}

/// Main thread (layoutSubviews). Queues the layout change onto the emu thread, which owns the window.
- (void)resizeWindowToPixelSize:(CGSize)px {
    if (!_window || px.width < 1 || px.height < 1) { return; }
    _lastDrawablePx = px;
    const bool portrait = px.height > px.width;
    const unsigned w = (unsigned)px.width, h = (unsigned)px.height;
    // Snapshot on main: the emu thread must not read the bridge's properties. Skin rects only fit
    // the drawable they were computed for; after a rotation the user layout fills in until the
    // host hands over new frames, instead of rects that overflow the window and show black.
    const bool skin = _skinLayoutActive && fabs(px.width - _skinUnionPx.width) < 2 && fabs(px.height - _skinUnionPx.height) < 2;
    const bool singleArea = _skinSingleAreaActive;
    const CGRect top = _skinTopPx, bottom = _skinBottomPx;
    const NSInteger layoutOpt = self.layoutOption, portraitOpt = self.portraitLayoutOption;
    const bool swap = self.swapScreens;
    ILOG(@"[PVAzahar] relayout %ux%u portrait=%d skinLayout=%d singleArea=%d pendingFrames=%d layout=%ld portraitLayout=%ld swap=%d",
         w, h, portrait, skin, singleArea, (int)(_hasPendingSkinFrames || _hasPendingSingleArea), (long)layoutOpt, (long)portraitOpt, swap);
    [self runOnEmuThread:[self, w, h, portrait, skin, singleArea, top, bottom, layoutOpt, portraitOpt, swap] {
        if (!_window) { return; }
        ApplyLayoutSettings(skin, singleArea, top, bottom, layoutOpt, portraitOpt, swap, portrait);
        _window->Resize(w, h, portrait);
    }];
}

- (void)relayoutWindow {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self relayoutWindow]; }); return; }
    PVAzaharRenderView *view = (PVAzaharRenderView *)_renderView;
    if (view) { [self resizeWindowToPixelSize:view.metalLayer.drawableSize]; }
}

- (void)teardownRenderView {
    PVAzaharRenderView *view = (PVAzaharRenderView *)_renderView;
    NSArray<NSLayoutConstraint *> *constraints = _renderViewConstraints;
    _renderView = nil;
    _renderViewConstraints = nil;
    // Frames queued before this render view existed must not replay into the next one.
    _hasPendingSkinFrames = NO;
    _hasPendingSingleArea = NO;
    if (!view) { return; }
    // Captures only the view and constraints, never self: this can run from the base class's dealloc.
    void (^detach)(void) = ^{
        view.onDrawableSizeChange = nil;
#if !TARGET_OS_TV
        view.onTouch = nil;
#endif
        if (constraints) { [NSLayoutConstraint deactivateConstraints:constraints]; }
        [view removeFromSuperview];
    };
    if (NSThread.isMainThread) { detach(); } else { dispatch_async(dispatch_get_main_queue(), detach); }
}

#pragma mark - PVCoreObjCBridge video properties

- (CGSize)bufferSize { return CGSizeMake(400 * MAX(1, self.resolutionFactor), 480 * MAX(1, self.resolutionFactor)); }
- (CGRect)screenRect { CGSize s = [self bufferSize]; return CGRectMake(0, 0, s.width, s.height); }
- (CGSize)aspectSize { return CGSizeMake(400, 480); }
- (BOOL)rendersToOpenGL { return YES; }   // "own surface" branch of PVMetalViewController.draw(in:)
// NO like Dolphin: rendersToVulkan marks frontend-presented cores that hand every frame to
// PVMetalViewController (thin PPSSPP). We present into our own layer, so claiming it left the host
// view waiting for an input texture it never gets and logging a GPU-recovery error every frame.
- (BOOL)rendersToVulkan { return NO; }
- (BOOL)isDoubleBuffered { return YES; }
- (const void *)videoBuffer { return NULL; }
- (NSTimeInterval)frameInterval { return 60.0; }
- (GLenum)pixelFormat { return 0x80E1; /* GL_BGRA */ }
- (GLenum)pixelType { return 0x1401; /* GL_UNSIGNED_BYTE */ }
- (GLenum)internalPixelFormat { return 0x1908; /* GL_RGBA */ }

#pragma mark - Touch (bottom screen)

#if !TARGET_OS_TV
- (void)sendTouchEvent:(UITouch *)touch ended:(BOOL)ended {
    if (!_renderView || !_window) { return; }
    const CGPoint p = [touch locationInView:_renderView];
    const CGFloat scale = ((PVAzaharRenderView *)_renderView).metalLayer.contentsScale;
    const float x = (float)(p.x * scale), y = (float)(p.y * scale);
    [self runOnEmuThread:[self, x, y, ended] { if (_window) { _window->Touch(!ended, x, y); } }];
}
#endif

@end

@implementation PVAzaharCoreBridge (ViewportPositioning)

#pragma mark - EmulatorCoreViewportPositioning (DeltaSkin screen frame)

- (void)setUseCustomRenderViewLayout:(BOOL)enabled {
    _useCustomRenderViewLayout = enabled;
    if (!enabled) { _skinLayoutActive = NO; _skinSingleAreaActive = NO; }
    if (!enabled && _renderView && _renderViewConstraints) {
        _renderView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:_renderViewConstraints];
        [_renderView.superview layoutIfNeeded];   // layoutSubviews reports the new drawable size
    }
}

- (void)applyRenderViewFrameInTouchView:(CGRect)frame {
    if (!_renderView) {
        ILOG(@"[PVAzahar] skin area queued before render view");
        _pendingSingleArea = frame; _hasPendingSingleArea = YES; _hasPendingSkinFrames = NO;
        return;
    }
    _hasPendingSingleArea = NO;
    const BOOL hadSkinLayout = _skinLayoutActive, hadSingleArea = _skinSingleAreaActive;
    // A frame covering the whole host is "no skin" (tvOS, or a reset): keep the user's layout.
    UIView *host = _renderView.superview;
    const BOOL fullBounds = host && CGRectEqualToRect(CGRectIntegral(frame), CGRectIntegral(host.bounds));
    _skinLayoutActive = NO;          // one frame: both screens go inside it...
    _skinSingleAreaActive = !fullBounds;     // ...laid out by the area's shape, not the user's option
    if (_renderViewConstraints) { [NSLayoutConstraint deactivateConstraints:_renderViewConstraints]; }
    _renderView.translatesAutoresizingMaskIntoConstraints = YES;
    _renderView.frame = frame;
    [_renderView layoutIfNeeded];   // layoutSubviews reports the new drawable size
    if (hadSkinLayout || hadSingleArea != _skinSingleAreaActive) { [self relayoutWindow]; }   // same size, different layout
}

/// Both skin screens, in touch-view points. The view covers their union and azahar's custom layout
/// puts each screen exactly where the skin drew it, so the skin's art and touch areas line up.
- (void)applyDualScreenRenderFramesInTouchView:(CGRect)top bottom:(CGRect)bottom {
    if (CGRectIsEmpty(top) || CGRectIsEmpty(bottom)) { return; }
    if (!_renderView) {
        ILOG(@"[PVAzahar] skin frames queued before render view");
        _pendingSkinTop = top; _pendingSkinBottom = bottom; _hasPendingSkinFrames = YES; _hasPendingSingleArea = NO;
        return;
    }
    _hasPendingSkinFrames = NO;
    const CGRect unionRect = CGRectIntegral(CGRectUnion(top, bottom));
    if (_renderViewConstraints) { [NSLayoutConstraint deactivateConstraints:_renderViewConstraints]; }
    _renderView.translatesAutoresizingMaskIntoConstraints = YES;
    _renderView.frame = unionRect;
    [_renderView layoutIfNeeded];
    const CGFloat scale = ((PVAzaharRenderView *)_renderView).metalLayer.contentsScale ?: UIScreen.mainScreen.nativeScale;
    auto toPx = [&](CGRect r) {
        return CGRectMake((r.origin.x - unionRect.origin.x) * scale, (r.origin.y - unionRect.origin.y) * scale,
                          r.size.width * scale, r.size.height * scale);
    };
    _skinTopPx = toPx(top);
    _skinBottomPx = toPx(bottom);
    _skinUnionPx = CGSizeMake(unionRect.size.width * scale, unionRect.size.height * scale);
    _skinLayoutActive = YES;
    _skinSingleAreaActive = NO;
    _useCustomRenderViewLayout = YES;
    [self relayoutWindow];   // layoutSubviews only reports size changes; the rects may differ at the same size
}

- (BOOL)isShuttingDownForViewportUpdates { return !_running; }

@end
