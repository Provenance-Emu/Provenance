/*
 *  PVRetroArchOSD.h
 *  PVRetroArch
 *
 *  Bridges RetroArch OSD messages to PVToast via NSNotificationCenter.
 */

#ifndef PV_RETROARCH_OSD_H
#define PV_RETROARCH_OSD_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Post an OSD message to PVToast via PVOSDMessageNotification.
 *
 * @param msg      The message string (UTF-8).
 * @param category RetroArch MESSAGE_QUEUE_CATEGORY_* value cast to unsigned
 *                 (0=INFO, 1=ERROR, 2=WARNING, 3=SUCCESS). Maps to PVOSDType.
 * @param duration_ms Pre-computed display duration in milliseconds, derived
 *                    from the original frame-count duration and the core's
 *                    actual FPS (caller performs the conversion).
 */
void pv_retroarch_post_osd(const char *msg, unsigned category, unsigned duration_ms);

#ifdef __cplusplus
}
#endif

#endif /* PV_RETROARCH_OSD_H */
