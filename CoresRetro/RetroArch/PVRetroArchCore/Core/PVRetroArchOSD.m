/*
 *  PVRetroArchOSD.m
 *  PVRetroArch
 *
 *  Bridges RetroArch OSD messages to PVToast via NSNotificationCenter.
 *  Called from runloop_msg_queue_push() in runloop.c.
 */

#import <PVCoreObjCBridge/PVOSDNotification.h>
#import "PVRetroArchOSD.h"

void pv_retroarch_post_osd(const char *msg, unsigned category, unsigned duration_ms) {
    if (!msg || msg[0] == '\0')
        return;

    @autoreleasepool {
        NSString *nsMsg = [NSString stringWithUTF8String:msg];
        if (nsMsg.length == 0)
            return;

        /* Convert pre-computed millisecond duration to seconds.
         * The caller (runloop.c) already applied the core FPS conversion. */
        NSTimeInterval seconds = (duration_ms > 0) ? ((double)duration_ms / 1000.0) : 3.0;
        /* Clamp to reasonable range */
        if (seconds < 1.0) seconds = 1.0;
        if (seconds > 10.0) seconds = 10.0;

        /* Map MESSAGE_QUEUE_CATEGORY_* to PVOSDType.
         * Actual RetroArch enum (libretro-common/include/queues/message_queue.h):
         *   0 (INFO)    -> PVOSDTypeInfo    (0)
         *   1 (ERROR)   -> PVOSDTypeError   (3)
         *   2 (WARNING) -> PVOSDTypeWarning (2)
         *   3 (SUCCESS) -> PVOSDTypeSuccess (1)
         */
        PVOSDType osdType;
        switch (category) {
            case 1:  osdType = PVOSDTypeError;   break;
            case 2:  osdType = PVOSDTypeWarning; break;
            case 3:  osdType = PVOSDTypeSuccess; break;
            default: osdType = PVOSDTypeInfo;    break;
        }

        [PVOSDNotification postMessage:nsMsg type:osdType duration:seconds];
    }
}
