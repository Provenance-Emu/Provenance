#pragma once
#import "PVAzaharCoreBridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVAzaharCoreBridge (Video)
/// Main thread. Creates the render view inside `touchViewController.view` and the emu window.
- (void)setupRenderView;
/// Main thread, after the emu thread has been joined.
- (void)teardownRenderView;
// EmulatorCoreViewportPositioning (DeltaSkin screen frame), implemented in this category.
- (void)setUseCustomRenderViewLayout:(BOOL)enabled;
- (void)applyRenderViewFrameInTouchView:(CGRect)frame;
- (BOOL)isShuttingDownForViewportUpdates;
#if !TARGET_OS_TV
- (void)sendTouchEvent:(UITouch *)touch ended:(BOOL)ended;
#endif
@end

NS_ASSUME_NONNULL_END
