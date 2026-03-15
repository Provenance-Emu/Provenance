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
 * @param prio     RetroArch priority (higher = more important).
 * @param category RetroArch MESSAGE_QUEUE_CATEGORY_* value cast to unsigned
 *                 (0=INFO, 1=WARNING, 2=ERROR). Used to derive PVOSDType.
 * @param duration RetroArch original frame-count duration (before any widget
 *                 conversion), converted to seconds at ~60fps.
 */
void pv_retroarch_post_osd(const char *msg, unsigned prio, unsigned category, unsigned duration);

#ifdef __cplusplus
}
#endif

#endif /* PV_RETROARCH_OSD_H */
