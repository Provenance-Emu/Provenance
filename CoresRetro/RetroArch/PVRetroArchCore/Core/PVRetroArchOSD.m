/*
 *  PVRetroArchOSD.m
 *  PVRetroArch
 *
 *  Bridges RetroArch OSD messages to PVToast via NSNotificationCenter.
 *  Called from runloop_msg_queue_push() in runloop.c.
 */

#import <PVCoreObjCBridge/PVOSDNotification.h>
#import "PVRetroArchOSD.h"

void pv_retroarch_post_osd(const char *msg, unsigned category, unsigned duration) {
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
    PVOSDType osdType;
    switch (category) {
        case 2:  osdType = PVOSDTypeError;   break;
        case 1:  osdType = PVOSDTypeWarning; break;
        default: osdType = PVOSDTypeInfo;    break;
    }

    /* PVOSDNotification handles autorelease pool and thread-safe posting. */
    [PVOSDNotification postMessage:nsMsg type:osdType duration:seconds];
}
