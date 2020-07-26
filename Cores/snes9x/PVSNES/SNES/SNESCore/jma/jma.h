/*******************************************************************************
  Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
 
  (c) Copyright 1996 - 2002 Gary Henderson (gary.henderson@ntlworld.com) and
                            Jerremy Koot (jkoot@snes9x.com)

  (c) Copyright 2001 - 2004 John Weidman (jweidman@slip.net)

  (c) Copyright 2002 - 2004 Brad Jorsch (anomie@users.sourceforge.net),
                            funkyass (funkyass@spam.shaw.ca),
                            Joel Yliluoma (http://iki.fi/bisqwit/)
                            Kris Bleakley (codeviolation@hotmail.com),
                            Matthew Kendora,
                            Nach (n-a-c-h@users.sourceforge.net),
                            Peter Bortas (peter@bortas.org) and
                            zones (kasumitokoduck@yahoo.com)

  C4 x86 assembler and some C emulation code
  (c) Copyright 2000 - 2003 zsKnight (zsknight@zsnes.com),
                            _Demo_ (_demo_@zsnes.com), and Nach

  C4 C++ code
  (c) Copyright 2003 Brad Jorsch

  DSP-1 emulator code
  (c) Copyright 1998 - 2004 Ivar (ivar@snes9x.com), _Demo_, Gary Henderson,
                            John Weidman, neviksti (neviksti@hotmail.com),
                            Kris Bleakley, Andreas Naive

  DSP-2 emulator code
  (c) Copyright 2003 Kris Bleakley, John Weidman, neviksti, Matthew Kendora, and
                     Lord Nightmare (lord_nightmare@users.sourceforge.net

  OBC1 emulator code
  (c) Copyright 2001 - 2004 zsKnight, pagefault (pagefault@zsnes.com) and
                            Kris Bleakley
  Ported from x86 assembler to C by sanmaiwashi

  SPC7110 and RTC C++ emulator code
  (c) Copyright 2002 Matthew Kendora with research by
                     zsKnight, John Weidman, and Dark Force

  S-DD1 C emulator code
  (c) Copyright 2003 Brad Jorsch with research by
                     Andreas Naive and John Weidman
 
  S-RTC C emulator code
  (c) Copyright 2001 John Weidman
  
  ST010 C++ emulator code
  (c) Copyright 2003 Feather, Kris Bleakley, John Weidman and Matthew Kendora

  Super FX x86 assembler emulator code 
  (c) Copyright 1998 - 2003 zsKnight, _Demo_, and pagefault 

  Super FX C emulator code 
  (c) Copyright 1997 - 1999 Ivar, Gary Henderson and John Weidman


  SH assembler code partly based on x86 assembler code
  (c) Copyright 2002 - 2004 Marcus Comstedt (marcus@mc.pp.se) 

  JMA compressed file support
  (c) Copyright 2004 NSRT Team (http://nsrt.edgeemu.com)
 
  Specific ports contains the works of other authors. See headers in
  individual files.
 
  Snes9x homepage: http://www.snes9x.com
 
  Permission to use, copy, modify and distribute Snes9x in both binary and
  source form, for non-commercial purposes, is hereby granted without fee,
  providing that this license information and copyright notice appear with
  all copies and any derived work.
 
  This software is provided 'as-is', without any express or implied
  warranty. In no event shall the authors be held liable for any damages
  arising from the use of this software.
 
  Snes9x is freeware for PERSONAL USE only. Commercial users should
  seek permission of the copyright holders first. Commercial use includes
  charging money for Snes9x or software derived from Snes9x.
 
  The copyright holders request that bug fixes and improvements to the code
  should be forwarded to them so everyone can benefit from the modifications
  in future versions.
 
  Super NES and Super Nintendo Entertainment System are trademarks of
  Nintendo Co., Limited and its subsidiary companies.
*******************************************************************************/


#ifndef JMA_H
#define JMA_H

#include <string>
#include <fstream>
#include <vector>
#include <time.h>

namespace JMA
{
  enum jma_errors { JMA_NO_CREATE, JMA_NO_MEM_ALLOC, JMA_NO_OPEN, JMA_BAD_FILE, 
                    JMA_UNSUPPORTED_VERSION, JMA_COMPRESS_FAILED, JMA_DECOMPRESS_FAILED,
                    JMA_FILE_NOT_FOUND };
  
  struct jma_file_info_base
  {
    std::string name;
    std::string comment;
    size_t size;
    unsigned int crc32;
  };
                    
  struct jma_public_file_info : jma_file_info_base
  {
    time_t datetime;
  };
  
  struct jma_file_info : jma_file_info_base
  {
    unsigned short date;
    unsigned short time;
    const unsigned char *buffer;
  };

  template<class jma_file_type>
  inline size_t get_total_size(std::vector<jma_file_type>& files)
  {
    size_t size = 0;
    for (typename std::vector<jma_file_type>::iterator i = files.begin(); i != files.end(); i++)
    {
      size += i->size; //We do have a problem if this wraps around
    }
  
    return(size);
  }

  class jma_open
  {
    public:
    jma_open(const char *) throw(jma_errors);
    ~jma_open();
    
    std::vector<jma_public_file_info> get_files_info();
    std::vector<unsigned char *> get_all_files(unsigned char *) throw(jma_errors);
    void extract_file(std::string& name, unsigned char *) throw(jma_errors);
    
    private:
    std::ifstream stream;
    std::vector<jma_file_info> files;
    size_t chunk_size;
    unsigned char *decompressed_buffer;
    unsigned char *compressed_buffer;
  
    void chunk_seek(unsigned int) throw(jma_errors);
    void retrieve_file_block() throw(jma_errors);
  };
  
}
#endif
