#ifndef __MDFN_PNG_H
#define __MDFN_PNG_H

#include <mednafen/video.h>
#include <mednafen/FileStream.h>

class PNGWrite
{
 public:

 PNGWrite(const std::string& path, const MDFN_Surface *src, const MDFN_Rect &rect, const int32 *LineWidths);
 ~PNGWrite();


 static void WriteChunk(FileStream &pngfile, uint32 size, const char *type, const uint8 *data);

 private:

 void WriteIt(FileStream &pngfile, const MDFN_Surface *src, const MDFN_Rect &rect, const int32 *LineWidths);
 void EncodeImage(const MDFN_Surface *src, const MDFN_PixelFormat &format, const MDFN_Rect &rect, const int32 *LineWidths, const int png_width);

 FileStream ownfile;
 std::vector<uint8> compmem;
 std::vector<uint8> tmp_buffer;
};

#endif

