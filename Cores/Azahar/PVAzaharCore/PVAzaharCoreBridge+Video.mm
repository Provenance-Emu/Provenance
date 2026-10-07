#import "PVAzaharCoreBridge+Video.h"
#import "PVAzaharCoreBridge+Private.h"
#import <PVAzahar/PVAzahar-Swift.h>
#import <PVLogging/PVLoggingObjC.h>
#include "Glue/AzaharEmuWindow.h"

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
}

/// Main thread (layoutSubviews). Queues the layout change onto the emu thread, which owns the window.
- (void)resizeWindowToPixelSize:(CGSize)px {
    if (!_window || px.width < 1 || px.height < 1) { return; }
    const BOOL portrait = px.height > px.width;
    const unsigned w = (unsigned)px.width, h = (unsigned)px.height;
    [self runOnEmuThread:[self, w, h, portrait] { if (_window) { _window->Resize(w, h, portrait); } }];
}

- (void)teardownRenderView {
    PVAzaharRenderView *view = (PVAzaharRenderView *)_renderView;
    view.onDrawableSizeChange = nil;
#if !TARGET_OS_TV
    view.onTouch = nil;
#endif
    if (_renderViewConstraints) { [NSLayoutConstraint deactivateConstraints:_renderViewConstraints]; _renderViewConstraints = nil; }
    [view removeFromSuperview];
    _renderView = nil;
}

#pragma mark - EmulatorCoreViewportPositioning (DeltaSkin screen frame)

- (void)setUseCustomRenderViewLayout:(BOOL)enabled {
    _useCustomRenderViewLayout = enabled;
    if (!enabled && _renderView && _renderViewConstraints) {
        _renderView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:_renderViewConstraints];
        [_renderView.superview layoutIfNeeded];   // layoutSubviews reports the new drawable size
    }
}

- (void)applyRenderViewFrameInTouchView:(CGRect)frame {
    if (!_renderView) { return; }
    if (_renderViewConstraints) { [NSLayoutConstraint deactivateConstraints:_renderViewConstraints]; }
    _renderView.translatesAutoresizingMaskIntoConstraints = YES;
    _renderView.frame = frame;
    [_renderView layoutIfNeeded];   // layoutSubviews reports the new drawable size
}

- (BOOL)isShuttingDownForViewportUpdates { return !_running; }

#pragma mark - PVCoreObjCBridge video properties

- (CGSize)bufferSize { return CGSizeMake(400 * MAX(1, self.resolutionFactor), 480 * MAX(1, self.resolutionFactor)); }
- (CGRect)screenRect { CGSize s = [self bufferSize]; return CGRectMake(0, 0, s.width, s.height); }
- (CGSize)aspectSize { return CGSizeMake(400, 480); }
- (BOOL)rendersToOpenGL { return YES; }   // "own surface" branch of PVMetalViewController.draw(in:)
- (BOOL)rendersToVulkan { return YES; }
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
