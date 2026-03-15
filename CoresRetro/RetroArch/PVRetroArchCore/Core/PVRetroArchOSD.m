/*
 *  PVRetroArchOSD.m
 *  PVRetroArch
 *
 *  Bridges RetroArch OSD messages to PVToast via NSNotificationCenter.
 *  Called from runloop_msg_queue_push() in runloop.c.
 */

#import <Foundation/Foundation.h>
#import "PVRetroArchOSD.h"

void pv_retroarch_post_osd(const char *msg, unsigned prio, unsigned category, unsigned duration) {
    @autoreleasepool {
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

        /* Map MESSAGE_QUEUE_CATEGORY_* to PVOSDType:
         *   0 (INFO)    -> PVOSDTypeInfo    (0)
         *   1 (WARNING) -> PVOSDTypeWarning (2)
         *   2 (ERROR)   -> PVOSDTypeError   (3)
         */
        int osdType;
        switch (category) {
            case 2:  osdType = 3; break;  /* ERROR   -> PVOSDTypeError   */
            case 1:  osdType = 2; break;  /* WARNING -> PVOSDTypeWarning */
            default: osdType = 0; break;  /* INFO    -> PVOSDTypeInfo    */
        }

        /* NSNotificationCenter is thread-safe for posting; no need to
         * dispatch to the main queue here — the observer decides threading. */
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"PVOSDMessageNotification"
                          object:nil
                        userInfo:@{ @"PVOSDMessage":  nsMsg,
                                    @"PVOSDType":     @(osdType),
                                    @"PVOSDDuration": @(seconds) }];
    }
}
