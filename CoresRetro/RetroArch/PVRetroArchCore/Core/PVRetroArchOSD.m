/*
 *  PVRetroArchOSD.m
 *  PVRetroArch
 *
 *  Bridges RetroArch OSD messages to PVToast via NSNotificationCenter.
 *  Called from runloop_msg_queue_push() in runloop.c.
 */

#import <Foundation/Foundation.h>
#import "PVRetroArchOSD.h"

void pv_retroarch_post_osd(const char *msg, unsigned prio, unsigned duration) {
    if (!msg || msg[0] == '\0')
        return;

    NSString *nsMsg = [NSString stringWithUTF8String:msg];
    if (nsMsg.length == 0)
        return;

    /* Convert RetroArch frame-count duration to seconds (assume ~60fps). */
    NSTimeInterval seconds = (duration > 0) ? ((double)duration / 60.0) : 3.0;
    /* Clamp to reasonable range */
    if (seconds < 1.0) seconds = 1.0;
    if (seconds > 10.0) seconds = 10.0;

    /* Map RetroArch priority to PVOSDType:
     *   0 = info, 1 = success, 2 = warning, 3 = error
     * RetroArch uses higher prio for more important messages.
     * We treat prio >= 3 as warning, otherwise info. */
    int osdType = (prio >= 3) ? 2 : 0;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"PVOSDMessageNotification"
                          object:nil
                        userInfo:@{ @"PVOSDMessage":  nsMsg,
                                    @"PVOSDType":     @(osdType),
                                    @"PVOSDDuration": @(seconds) }];
    });
}
