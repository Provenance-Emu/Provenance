/*
  _____     ___ ____
   ____|   |    ____|      PS2LIB OpenSource Project
  |     ___|   |____       (C)2002, Pukko 
  ------------------------------------------------------------------------
  pad.h
                           Pad externals 
                           rev 1.2 (20020113)
*/

#ifndef _XPAD_H_
#define _XPAD_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Initialise xpadman
 * a = 0 should work..
 */
int xpadInit(int a);

/*
 * End all xpad communication (not tested)
 */
int xpadEnd();

/*
 * The user should provide a pointer to a 256 byte
 * 64 byte aligned xpad data area for each xpad port opened
 *
 * return != 0 => OK
 */
int xpadPortOpen(int port, int slot, void *xpadArea);

/*
 * not tested :/
 */
int xpadPortClose(int port, int slot);

/*
 * Read xpad data
 * Result is stored in 'data' which should point to a 32 byte array
 */
unsigned char xpadRead(int port, int slot, struct padButtonStatus *data);

unsigned int xpadGetFrameCount(int port, int slot);

/*
 * Get current xpad state
 * Wait until state == 6 (Ready) before trying to access the xpad
 */
int xpadGetState(int port, int slot);

/*
 * Get pad request state
 */
unsigned char xpadGetReqState(int port, int slot);

/*
 * Set pad request state (after a param setting)
 * No need to export this one perhaps..
 */
int xpadSetReqState(int port, int slot, int state);

/*
 * Debug print functions
 * uh.. these are actually not tested :)
 */
void xpadStateInt2String(int state, char buf[16]);
void xpadReqStateInt2String(int state, char buf[16]);

/*
 * Returns # slots on the PS2? (usally 2)
 */
int xpadGetPortMax(void);

/*
 * Returns # slots the port has (usually 1)
 * probably 4 if using a multi tap (not tested)
 */
int xpadGetSlotMax(int port);

/*
 * Returns the padman.irx version
 * NOT SUPPORTED on module rom0:padman
 */
int xpadGetModVersion();

/*
 * Get pad info (digital (4), dualshock (7), etc..)
 * 
 * Returns ID: 
 *     3 - KONAMI GUN
 *     4 - DIGITAL PAD
 *     5 - JOYSTICK
 *     6 - NAMCO GUN
 *     7 - DUAL SHOCK
 */
int xpadInfoMode(int port, int slot, int infoMode, int index);

/*
 * mode = 1, -> Analog/dual shock enabled; mode = 0 -> Digital  
 * lock = 3 -> Mode not changeable by user
 */
int xpadSetMainMode(int port, int slot, int mode, int lock);

/*
 * Check if the pad has pressure sensitive buttons
 */
int xpadInfoPressMode(int port, int slot);

/*
 * Pressure sensitive mode ON
 */
int xpadEnterPressMode(int port, int slot);

/*
 * Check for newer version
 * Pressure sensitive mode OFF
 */
int xpadExitPressMode(int port, int slot);

/*
 * Dunno if these need to be exported
 */
int xpadGetButtonMask(int port, int slot);
int xpadSetButtonInfo(int port, int slot, int buttonInfo);

/*
 * Get actuator status for this controller
 * If padInfoAct(port, slot, -1, 0) != 0, the controller has actuators
 * (i think ;) )
 */
unsigned char xpadInfoAct(int port, int slot, int word, int byte);

/*
 * Initalise actuators. On dual shock controller:
 * act_align[0] = 0 enables 'small' engine
 * act_align[1] = 1 enables 'big' engine
 * set act_align[2-5] to 0xff (disable)
 */
int xpadSetActAlign(int port, int slot, char act_align[6]);

/*
 * Set actuator status
 * On dual shock controller, 
 * act_align[0] = 0/1 turns off/on 'small' engine
 * act_align[1] = 0-255 sets 'big' engine speed
 */
int xpadSetActDirect(int port, int slot, char act_align[6]);

/*
 * Dunno about this one.. always returns 1?
 * I guess it should've returned if the pad was connected.. or?
 *
 * NOT SUPPORTED with module rom0:padman
 */
int xpadGetConnection(int port, int slot);

#ifdef __cplusplus
}
#endif

#endif



