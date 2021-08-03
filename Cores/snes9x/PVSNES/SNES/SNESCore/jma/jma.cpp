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


#include "jma.h"
using namespace std;

#include "portable.h"
#include "7z.h"
#include "crc32.h"

namespace JMA
{
  const char jma_magic[] = { 'J', 'M', 'A', 0, 'N' };
  const unsigned int jma_header_length = 5;  
  const unsigned char jma_version = 0;
  const unsigned int jma_version_length = 1;
  const unsigned int jma_total_header_length = jma_header_length + jma_version_length + UINT_SIZE;
  
  //Convert DOS/zip/JMA integer time to to time_t
  time_t uint_to_time(unsigned short date, unsigned short time)
  {
    tm formatted_time;
  
    formatted_time.tm_mday = date & 0x1F;
    formatted_time.tm_mon  = ((date >> 5) & 0xF) - 1;
    formatted_time.tm_year = ((date >> 9) & 0x7f) + 80;
    formatted_time.tm_sec  = (time & 0x1F) * 2;
    formatted_time.tm_min  = (time >> 5) & 0x3F;
    formatted_time.tm_hour = (time >> 11) & 0x1F;
  
    return(mktime(&formatted_time));
  }
    
  
  //Retreive the file block, what else?
  void jma_open::retrieve_file_block() throw(jma_errors)
  {
    unsigned char uint_buffer[UINT_SIZE];
    unsigned char ushort_buffer[USHORT_SIZE];
    
    //File block size is the last UINT in the file
    stream.seekg(-UINT_SIZE,ios::end);
    stream.read((char *)uint_buffer, UINT_SIZE);
    size_t file_block_size = charp_to_uint(uint_buffer);
    
    //Currently at the end of the file, so that's the file size
    size_t jma_file_size = stream.tellg();
    
    //The file block can't be larger than the JMA file without it's header.
    //This if can probably be improved
    if (file_block_size >= jma_file_size-jma_total_header_length)
    {
      throw(JMA_BAD_FILE);
    }
    
    //Seek to before file block so we can read the file block
    stream.seekg(-((int)file_block_size+UINT_SIZE),ios::end);
    
    jma_file_info file_info;
    char byte;
    
    //Minimum file name length is 2 bytes, a char and a null
    //Minimum comment length is 1 byte, a null
    //There are currently 2 UINTs and 2 USHORTs per file
    while (file_block_size >= 2+1+UINT_SIZE*2+USHORT_SIZE*2) //This does allow for a gap, but that's okay
    {
      //First stored in the file block is the file name null terminated
      file_info.name = "";
      
      stream.get(byte);
      while (byte)
      {
        file_info.name += byte;
        stream.get(byte);
      }

      //There must be a file name or the file is bad
      if (!file_info.name.length())
      {
        throw(JMA_BAD_FILE);
      } 
      
      //Same trick as above for the comment
      file_info.comment = "";

      stream.get(byte);
      while (byte)
      {
        file_info.comment += byte;
        stream.get(byte);
      }
      
      //Next is a UINT representing the file's size
      stream.read((char *)uint_buffer, UINT_SIZE);
      file_info.size = charp_to_uint(uint_buffer);
      
      //Followed by CRC32
      stream.read((char *)uint_buffer, UINT_SIZE);
      file_info.crc32 = charp_to_uint(uint_buffer);
      
      //Special USHORT representation of file's date
      stream.read((char *)ushort_buffer, USHORT_SIZE);
      file_info.date = charp_to_ushort(ushort_buffer);
      
      //Special USHORT representation of file's time
      stream.read((char *)ushort_buffer, USHORT_SIZE);
      file_info.time = charp_to_ushort(ushort_buffer);
      
      file_info.buffer = 0; //Pointing to null till we decompress files
      
      files.push_back(file_info); //Put file info into our structure
      
      //Subtract size of the file info we just read
      file_block_size -= file_info.name.length()+file_info.comment.length()+2+UINT_SIZE*2+USHORT_SIZE*2;
    }
  }

  
  //Constructor for opening JMA files for reading
  jma_open::jma_open(const char *compressed_file_name) throw (jma_errors) 
  {
    decompressed_buffer = 0;
    compressed_buffer = 0;
    
    stream.open(compressed_file_name, ios::in | ios::binary);
    if (!stream)
    {
      throw(JMA_NO_OPEN);
    }

    //Header is "JMA\0N"
    unsigned char header[jma_header_length];
    stream.read((char *)header, jma_header_length);
    if (memcmp(jma_magic, header, jma_header_length))
    {
      throw(JMA_BAD_FILE);
    }
    
    //Not the cleanest code but logical
    stream.read((char *)header, 5);
    if (*header == 0) //Version 0
    {
      chunk_size = charp_to_uint(header+1); //Chunk size is a UINT that follows version #
      retrieve_file_block();
    }
    else
    {
      throw(JMA_UNSUPPORTED_VERSION);
    }
  }

  //Destructor only has to close the stream if neccesary
  jma_open::~jma_open()
  {
    if (stream)
    {
      stream.close();
    }
  }

  //Return a vector containing useful info about the files in the JMA
  vector<jma_public_file_info> jma_open::get_files_info()
  {
    vector<jma_public_file_info> file_info_vector;
    jma_public_file_info file_info;
    
    for (vector<jma_file_info>::iterator i = files.begin(); i != files.end(); i++)
    {
      file_info.name = i->name;
      file_info.comment = i->comment;
      file_info.size = i->size;
      file_info.datetime = uint_to_time(i->date, i->time);
      file_info.crc32 = i->crc32;
      file_info_vector.push_back(file_info);
    }
    
    return(file_info_vector);
  }
  
  //Skip forward a given number of chunks
  void jma_open::chunk_seek(unsigned int chunk_num) throw(jma_errors)
  {
    //Check the stream is open
    if (!stream)
    {
      throw(JMA_NO_OPEN);
    }
   
    //Move forward over header
    stream.seekg(jma_total_header_length, ios::beg);

    unsigned char int4_buffer[UINT_SIZE]; 
    
    while (chunk_num--)
    {
      //Read in size of chunk
      stream.read((char *)int4_buffer, UINT_SIZE);
        
      //Skip chunk plus it's CRC32
      stream.seekg(charp_to_uint(int4_buffer)+UINT_SIZE, ios::cur);  
    }
  } 
    
  //Return a vector of pointers to each file in the JMA, the buffer to hold all the files
  //must be initilized outside.
  vector<unsigned char *> jma_open::get_all_files(unsigned char *buffer) throw(jma_errors)
  {
    //If there's no stream we can't read from it, so exit
    if (!stream)
    {
      throw(JMA_NO_OPEN);
    }
    
    //Seek to the first chunk
    chunk_seek(0);
    
    //Set the buffer that decompressed data goes to
    decompressed_buffer = buffer;
    
    //If the JMA is not solid
    if (chunk_size)
    {
      unsigned char int4_buffer[UINT_SIZE];  
      size_t size = get_total_size(files);
      
      //For each chunk in the file...
      for (size_t remaining_size = size; remaining_size; remaining_size -= chunk_size)
      {
        //Read the compressed size
        stream.read((char *)int4_buffer, UINT_SIZE);
        size_t compressed_size = charp_to_uint(int4_buffer);

        //Allocate memory of the correct size to hold the compressed data in the JMA
        //Throw error on failure as that is unrecoverable from
        try
        {
          compressed_buffer = new unsigned char[compressed_size];
        }
        catch (bad_alloc xa)
        {
          throw(JMA_NO_MEM_ALLOC);
        }

        //Read all the compressed data in
        stream.read((char *)compressed_buffer, compressed_size);
        
        //Read the expected CRC of compressed data from the file
        stream.read((char *)int4_buffer, UINT_SIZE);

        //If it doesn't match, throw error and cleanup memory
        if (CRC32lib::CRC32(compressed_buffer, compressed_size) != charp_to_uint(int4_buffer))
        {
          delete[] compressed_buffer;
          throw(JMA_BAD_FILE);
        }
        
        //Decompress the data, cleanup memory on failure
        if (!decompress_lzma_7z(compressed_buffer, compressed_size, 
                                decompressed_buffer+size-remaining_size, 
                                (remaining_size > chunk_size) ? chunk_size : remaining_size))
        {
          delete[] compressed_buffer;
          throw(JMA_DECOMPRESS_FAILED);
        }
        delete[] compressed_buffer;
      }
    }
    else //Solidly compressed JMA
    {
      unsigned char int4_buffer[UINT_SIZE]; 
      
      //read the size of the compressed data
      stream.read((char *)int4_buffer, UINT_SIZE);
      size_t compressed_size = charp_to_uint(int4_buffer);

      //Allocate memory of the right size to hold the compressed data in the JMA
      try
      {
        compressed_buffer = new unsigned char[compressed_size];
      }
      catch (bad_alloc xa)
      {
        throw(JMA_NO_MEM_ALLOC);
      }
      
      //Copy the compressed data into memory
      stream.read((char *)compressed_buffer, compressed_size);
      size_t size = get_total_size(files);
      
      //Read the CRC of the compressed data
      stream.read((char *)int4_buffer, UINT_SIZE);
      
      //If it doesn't match, complain
      if (CRC32lib::CRC32(compressed_buffer, compressed_size) != charp_to_uint(int4_buffer))
      {
        delete[] compressed_buffer;
        throw(JMA_BAD_FILE);
      }

      //decompress the data
      if (!decompress_lzma_7z(compressed_buffer, compressed_size, decompressed_buffer, size))
      {
        delete[] compressed_buffer;
        throw(JMA_DECOMPRESS_FAILED);
      }
      delete[] compressed_buffer;
    }
  
    vector<unsigned char *> file_pointers;
    size_t size = 0;
    
    //For each file, add it's pointer to the vector, size is pointer offset in the buffer
    for (vector<jma_file_info>::iterator i = files.begin(); i != files.end(); i++)
    {
      i->buffer = decompressed_buffer+size;
      file_pointers.push_back(decompressed_buffer+size);
      size += i->size;
    }

    //Return the vector of pointers
    return(file_pointers);  
  }

  //Extracts the file with a given name found in the archive to the given buffer
  void jma_open::extract_file(string& name, unsigned char *buffer) throw(jma_errors)
  {
    if (!stream)
    {
      throw(JMA_NO_OPEN);
    }
   
    size_t size_to_skip = 0;
    size_t our_file_size = 0;
    
    //Search through the vector of file information
    for (vector<jma_file_info>::iterator i = files.begin(); i != files.end(); i++)
    {
      if (i->name == name)
      {
        //Set the variable so we can tell we found it
        our_file_size = i->size;
        break;
      }
      
      //Keep a running total of size
      size_to_skip += i->size;
    }
   
    if (!our_file_size) //File with the specified name was not found in the archive
    {
      throw(JMA_FILE_NOT_FOUND);
    }

    //If the JMA only contains one file, we can skip a lot of overhead
    if (files.size() == 1)
    {
      get_all_files(buffer);
      return;
    }
    
    if (chunk_size) //we are using non-solid archive..
    {
      unsigned int chunks_to_skip = size_to_skip / chunk_size;
      
      //skip over requisite number of chunks
      chunk_seek(chunks_to_skip);
     
      //Allocate memory for compressed and decompressed data
      unsigned char *comp_buffer = 0, *decomp_buffer = 0;
      try
      {
        //Compressed data size is <= non compressed size
        unsigned char *combined_buffer = new unsigned char[chunk_size*2];
        comp_buffer = combined_buffer;
        decomp_buffer = combined_buffer+chunk_size;
      }
      catch (bad_alloc xa)
      {
        throw(JMA_NO_MEM_ALLOC);
      }
      
      size_t first_chunk_offset = size_to_skip % chunk_size;
      unsigned char int4_buffer[UINT_SIZE];
      for (size_t i = 0; i < our_file_size;)
      {
        //Get size
        stream.read((char *) int4_buffer, UINT_SIZE);
        size_t compressed_size = charp_to_uint(int4_buffer);
        
        //Read all the compressed data in
        stream.read((char *)comp_buffer, compressed_size);

        //Read the CRC of the compressed data
        stream.read((char *)int4_buffer, UINT_SIZE);
      
        //If it doesn't match, complain
        if (CRC32lib::CRC32(comp_buffer, compressed_size) != charp_to_uint(int4_buffer))
        {
          delete[] comp_buffer;
          throw(JMA_BAD_FILE);
        }
                
        //Decompress chunk
        if (!decompress_lzma_7z(comp_buffer, compressed_size, decomp_buffer, chunk_size))
        {
          delete[] comp_buffer;
          throw(JMA_DECOMPRESS_FAILED);
        }
        else
        {
          size_t copy_amount = our_file_size-i > chunk_size ? chunk_size : our_file_size-i;
          copy_amount -= first_chunk_offset;
          memcpy(buffer+i, decomp_buffer+first_chunk_offset, copy_amount);
          first_chunk_offset = 0;
          i += copy_amount;
        }
      }
      delete[] comp_buffer;
    }
    else //Solid JMA
    {
      unsigned char *decomp_buffer = 0;
      try
      {
        decomp_buffer = new unsigned char[get_total_size(files)];
      }
      catch (bad_alloc xa)
      {
        throw(JMA_NO_MEM_ALLOC);
      }
      
      get_all_files(decomp_buffer);
      
      memcpy(buffer, decomp_buffer+size_to_skip, our_file_size);
    
      delete[] decomp_buffer;
    }
  }

}


