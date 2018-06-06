#ifndef __MDFN_NETPLAY_DRIVER_H
#define __MDFN_NETPLAY_DRIVER_H

void MDFNI_NetplayConnect(void);
void MDFNI_NetplayDisconnect(void);

/* Parse and handle a line of UI text(may include / commands) */
void MDFNI_NetplayLine(const char *text, bool &inputable, bool &viewable);

/* Display netplay-related text. */
/* NetEcho will be set to true if the displayed text is a network
   echo of what we typed.
*/
void MDFND_NetplayText(const char* text, bool NetEcho);
void MDFND_NetplaySetHints(bool active, bool behind, uint32 local_players_mask);

#endif
