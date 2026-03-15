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

        /* Convert pre-computed RetroArch millisecond duration to seconds.
         * The caller (runloop.c) has already applied any core FPS / timing conversion,
         * so we use the provided value directly, falling back to 3s if unset. */
        NSTimeInterval seconds = (duration_ms > 0) ? ((double)duration_ms / 1000.0) : 3.0;

        /* Map MESSAGE_QUEUE_CATEGORY_* to PVOSDType.
         * Actual RetroArch enum (libretro-common/include/queues/message_queue.h):
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
