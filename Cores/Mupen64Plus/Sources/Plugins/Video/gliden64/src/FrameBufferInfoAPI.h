#ifndef _FRAME_BUFFER_INFO_API_H_
#define _FRAME_BUFFER_INFO_API_H_

#if defined(__cplusplus)
extern "C" {
#endif

#ifdef OS_WINDOWS
  #define EXPORT	__declspec(dllexport)
  #define CALL		__cdecl
#else
  #define EXPORT 	__attribute__((visibility("default")))
  #define CALL
#endif

/******************************************************************
  Function: FrameBufferWrite
  Purpose:  This function is called to notify the dll that the
            frame buffer has been modified by CPU at the given address.
  input:    addr		rdram address
			size		1 = unsigned char, 2 = unsigned short, 4=unsigned int
  output:   none
*******************************************************************/
EXPORT void CALL FBWrite(unsigned int addr, unsigned int size);

struct FrameBufferModifyEntry;

/******************************************************************
  Function: FrameBufferWriteList
  Purpose:  This function is called to notify the dll that the
            frame buffer has been modified by CPU at the given address.
  input:    FrameBufferModifyEntry *plist
			size = size of the plist, max = 1024
  output:   none
*******************************************************************/
EXPORT void CALL FBWList(FrameBufferModifyEntry *plist, unsigned int size);

/******************************************************************
  Function: FrameBufferRead
  Purpose:  This function is called to notify the dll that the
            frame buffer memory is beening read at the given address.
			DLL should copy content from its render buffer to the frame buffer
			in N64 RDRAM
			DLL is responsible to maintain its own frame buffer memory addr list
			DLL should copy 4KB block content back to RDRAM frame buffer.
			Emulator should not call this function again if other memory
			is read within the same 4KB range
  input:    addr		rdram address
  output:   none
*******************************************************************/
EXPORT void CALL FBRead(unsigned int addr);

/************************************************************************
Function: FBGetFrameBufferInfo
Purpose:  This function is called by the emulator core to retrieve depth
buffer information from the video plugin in order to be able
to notify the video plugin about CPU depth buffer read/write
operations

size:
= 1		byte
= 2		word (16 bit) <-- this is N64 default depth buffer format
= 4		dword (32 bit)

when depth buffer information is not available yet, set all values
in the FrameBufferInfo structure to 0

input:    FrameBufferInfo *pinfo
pinfo is pointed to a FrameBufferInfo structure which to be
filled in by this function
output:   Values are return in the FrameBufferInfo structure
************************************************************************/
EXPORT void CALL FBGetFrameBufferInfo(void *pinfo);

#if defined(__cplusplus)
}
#endif

#endif // _FRAME_BUFFER_INFO_API_H_
