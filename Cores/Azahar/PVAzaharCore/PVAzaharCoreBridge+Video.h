#pragma once
#import "PVAzaharCoreBridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVAzaharCoreBridge (Video)
/// Main thread. Creates the render view inside `touchViewController.view` and the emu window.
- (void)setupRenderView;
/// Re-runs the current layout after a Settings::values.layout_option / swap_screen change. Any thread.
- (void)relayoutWindow;
/// Main thread, after the emu thread has been joined.
- (void)teardownRenderView;
#if !TARGET_OS_TV
- (void)sendTouchEvent:(UITouch *)touch ended:(BOOL)ended;
#endif
@end

NS_ASSUME_NONNULL_END
