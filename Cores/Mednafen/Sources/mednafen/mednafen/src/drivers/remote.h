#ifndef __MDFN_DRIVERS_REMOTE_H
#define __MDFN_DRIVERS_REMOTE_H

// Call all of these from the game(emulation) thread(or main thread if we haven't split off yet).

void CheckForSTDIOMessages(void);
bool InitSTDIOInterface(const char *key);
void Remote_SendInfoMessage(const char *message);
void Remote_SendErrorMessage(const char *message);
void Remote_SendWarningMessage(const char *message);

#endif
