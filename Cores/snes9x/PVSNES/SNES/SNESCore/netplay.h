/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _NETPLAY_H_
#define _NETPLAY_H_

/*
 * Client to server joypad update
 *
 * magic        1
 * sequence_no  1
 * opcode       1
 * joypad data  4
 *
 * Server to client joypad update
 * magic        1
 * sequence_no  1
 * opcode       1 + num joypads (top 3 bits)
 * joypad data  4 * n
 */

#ifdef _DEBUG
#define NP_DEBUG 1
#endif

#define NP_VERSION 10
#define NP_JOYPAD_HIST_SIZE 120
#define NP_DEFAULT_PORT 6096

#define NP_MAX_CLIENTS 8

#define NP_SERV_MAGIC 'S'
#define NP_CLNT_MAGIC 'C'

#define NP_CLNT_HELLO 0
#define NP_CLNT_JOYPAD 1
#define NP_CLNT_RESET 2
#define NP_CLNT_PAUSE 3
#define NP_CLNT_LOAD_ROM 4
#define NP_CLNT_ROM_IMAGE 5
#define NP_CLNT_FREEZE_FILE 6
#define NP_CLNT_SRAM_DATA 7
#define NP_CLNT_READY 8
#define NP_CLNT_LOADED_ROM 9
#define NP_CLNT_RECEIVED_ROM_IMAGE 10
#define NP_CLNT_WAITING_FOR_ROM_IMAGE 11

#define NP_SERV_HELLO 0
#define NP_SERV_JOYPAD 1
#define NP_SERV_RESET 2
#define NP_SERV_PAUSE 3
#define NP_SERV_LOAD_ROM 4
#define NP_SERV_ROM_IMAGE 5
#define NP_SERV_FREEZE_FILE 6
#define NP_SERV_SRAM_DATA 7
#define NP_SERV_READY 8
// ...
#define NP_SERV_JOYPAD_SWAP 12

struct SNPClient
{
    volatile uint8 SendSequenceNum;
    volatile uint8 ReceiveSequenceNum;
    volatile bool8 Connected;
    volatile bool8 SaidHello;
    volatile bool8 Paused;
    volatile bool8 Ready;
    int Socket;
    char *ROMName;
    char *HostName;
    char *Who;
};

enum {
    NP_SERVER_SEND_ROM_IMAGE,
    NP_SERVER_SYNC_ALL,
    NP_SERVER_SYNC_CLIENT,
    NP_SERVER_SEND_FREEZE_FILE_ALL,
    NP_SERVER_SEND_ROM_LOAD_REQUEST_ALL,
    NP_SERVER_RESET_ALL,
    NP_SERVER_SEND_SRAM_ALL,
    NP_SERVER_SEND_SRAM
};

#define NP_MAX_TASKS 20

struct NPServerTask
{
    uint32 Task;
    void  *Data;
};

struct SNPServer
{
    struct SNPClient Clients [NP_MAX_CLIENTS];
    int    NumClients;
    volatile struct NPServerTask TaskQueue [NP_MAX_TASKS];
    volatile uint32 TaskHead;
    volatile uint32 TaskTail;
    int    Socket;
    uint32 FrameTime;
    uint32 FrameCount;
    char   ROMName [30];
    uint32 Joypads [NP_MAX_CLIENTS];
    bool8  ClientPaused;
    uint32 Paused;
    bool8  SendROMImageOnConnect;
    bool8  SyncByReset;
};

#define NP_MAX_ACTION_LEN 200

struct SNetPlay
{
    volatile uint8  MySequenceNum;
    volatile uint8  ServerSequenceNum;
    volatile bool8  Connected;
    volatile bool8  Abort;
    volatile uint8  Player;
    volatile bool8  ClientsReady [NP_MAX_CLIENTS];
    volatile bool8  ClientsPaused [NP_MAX_CLIENTS];
    volatile bool8  Paused;
    volatile bool8  PendingWait4Sync;
    volatile uint8  PercentageComplete;
    volatile bool8  Waiting4EmulationThread;
    volatile bool8  Answer;
#ifdef __WIN32__
    HANDLE          ReplyEvent;
#endif
    volatile int    Socket;
    char *ServerHostName;
    char *ROMName;
    int Port;
    volatile uint32 JoypadWriteInd;
    volatile uint32 JoypadReadInd;
    uint32 Joypads [NP_JOYPAD_HIST_SIZE][NP_MAX_CLIENTS];
    uint32 Frame [NP_JOYPAD_HIST_SIZE];
    uint32 FrameCount;
    uint32 MaxFrameSkip;
    uint32 MaxBehindFrameCount;
    bool8 JoypadsReady [NP_JOYPAD_HIST_SIZE][NP_MAX_CLIENTS];
    char   ActionMsg [NP_MAX_ACTION_LEN];
    char   ErrorMsg [NP_MAX_ACTION_LEN];
    char   WarningMsg [NP_MAX_ACTION_LEN];
};

extern "C" struct SNetPlay NetPlay;

//
// NETPLAY_CLIENT_HELLO message format:
// header
// frame_time (4)
// ROMName (variable)

#define WRITE_LONG(p, v) { \
*((p) + 0) = (uint8) ((v) >> 24); \
*((p) + 1) = (uint8) ((v) >> 16); \
*((p) + 2) = (uint8) ((v) >> 8); \
*((p) + 3) = (uint8) ((v) >> 0); \
}

#define READ_LONG(p) \
((((uint8) *((p) + 0)) << 24) | \
 (((uint8) *((p) + 1)) << 16) | \
 (((uint8) *((p) + 2)) <<  8) | \
 (((uint8) *((p) + 3)) <<  0))

bool8 S9xNPConnectToServer (const char *server_name, int port,
                            const char *rom_name);
bool8 S9xNPWaitForHeartBeat ();
bool8 S9xNPWaitForHeartBeatDelay (uint32 time_msec = 0);
bool8 S9xNPCheckForHeartBeat (uint32 time_msec = 0);
uint32 S9xNPGetJoypad (int which1);
bool8 S9xNPSendJoypadUpdate (uint32 joypad);
void S9xNPDisconnect ();
bool8 S9xNPInitialise ();
bool8 S9xNPSendData (int fd, const uint8 *data, int len);
bool8 S9xNPGetData (int fd, uint8 *data, int len);

void S9xNPSyncClients ();
void S9xNPStepJoypadHistory ();

void S9xNPResetJoypadReadPos ();
bool8 S9xNPSendReady (uint8 op = NP_CLNT_READY);
bool8 S9xNPSendPause (bool8 pause);
void S9xNPReset ();
void S9xNPSetAction (const char *action, bool8 force = FALSE);
void S9xNPSetError (const char *error);
void S9xNPSetWarning (const char *warning);
void S9xNPDiscardHeartbeats ();
void S9xNPServerQueueSendingFreezeFile (const char *filename);
void S9xNPServerQueueSyncAll ();
void S9xNPServerQueueSendingROMImage ();
void S9xNPServerQueueSendingLoadROMRequest (const char *filename);

void S9xNPServerAddTask (uint32 task, void *data);

bool8 S9xNPStartServer (int port);
void S9xNPStopServer ();
void S9xNPSendJoypadSwap ();
#ifdef __WIN32__
#define S9xGetMilliTime timeGetTime
#else
uint32 S9xGetMilliTime ();
#endif
#endif
