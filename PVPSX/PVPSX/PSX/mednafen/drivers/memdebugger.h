#ifndef __MDFN_DRIVERS_MEMDEBUGGER_H
#define __MDFN_DRIVERS_MEMDEBUGGER_H

#include <iconv.h>
#include <vector>
#include <string>

class MemDebuggerPrompt;

class MemDebugger
{
 public:

 MemDebugger();
 ~MemDebugger();

 void Draw(MDFN_Surface *surface, const MDFN_Rect *rect, const MDFN_Rect *screen_rect);
 int Event(const SDL_Event *event);
 void SetActive(bool newia);

 private:

 bool ICV_Init(const char *newcode);
 void ChangePos(int64 delta);
 void DoCrazy(void);

 uint8* TextToBS(const char *text, size_t *TheCount);
 void PromptFinish(const std::string &pstring);
 bool DoBSSearch(uint32 byte_count, uint8 *thebytes);
 bool DoRSearch(uint32 byte_count, uint8 *the_bytes);


 // Local cache variable set after game load to reduce dereferences and make the code nicer.
 // (the game structure's debugger info struct doesn't change during emulation, so this is safe)
 const std::vector<AddressSpaceType> *AddressSpaces;
 const AddressSpaceType *ASpace; // Current address space

 bool IsActive;
 std::vector<uint32> ASpacePos;
 std::vector<uint64> SizeCache;
 std::vector<uint64> GoGoPowerDD;

 int CurASpace; // Current address space number

 bool LowNib;
 bool InEditMode;
 bool InTextArea; // Right side text vs left side numbers, selected via TAB

 std::string BSS_String, RS_String, TS_String;
 char *error_string;
 uint32 error_time;

 typedef enum
 {
  None = 0,
  Goto,
  GotoDD,
  ByteStringSearch,
  RelSearch,
  TextSearch,
  DumpMem,
  LoadMem,
  SetCharset,
 } PromptType;

 iconv_t ict;
 iconv_t ict_to_utf8;
 iconv_t ict_utf16_to_game;

 std::string GameCode;

 PromptType InPrompt;

 MemDebuggerPrompt *myprompt;

 friend class MemDebuggerPrompt;
};

#endif
