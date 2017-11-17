/* 7zMain.c - Test application for 7z Decoder
2010-03-12 : Igor Pavlov : Public domain */

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <stdio.h>
#include <string.h>

#include "../../7z.h"
#ifdef _7ZIP_CRC_SUPPORT
#include "../../7zCrc.h"
#endif
#include "../../7zFile.h"
#include "../../7zVersion.h"

#include "7zAlloc.h"

#ifndef USE_WINDOWS_FILE
/* for mkdir */
#ifdef _WIN32
#include <direct.h>
#else
#include <sys/stat.h>
#include <errno.h>
#endif
#endif

#ifdef _WIN32
#define CHAR_PATH_SEPARATOR '\\'
#else
#define CHAR_PATH_SEPARATOR '/'
#endif

#include <assert.h>
#include <unistd.h>

static ISzAlloc g_Alloc = { SzAlloc, SzFree };

static int Buf_EnsureSize(CBuf *dest, size_t size)
{
  if (dest->size >= size)
    return 1;
  Buf_Free(dest, &g_Alloc);
  return Buf_Create(dest, size, &g_Alloc);
}

#ifndef _WIN32

static Byte kUtf8Limits[5] = { 0xC0, 0xE0, 0xF0, 0xF8, 0xFC };

static Bool Utf16_To_Utf8(Byte *dest, size_t *destLen, const UInt16 *src, size_t srcLen)
{
  size_t destPos = 0, srcPos = 0;
  for (;;)
  {
    unsigned numAdds;
    UInt32 value;
    if (srcPos == srcLen)
    {
      *destLen = destPos;
      return True;
    }
    value = src[srcPos++];
    if (value < 0x80)
    {
      if (dest)
        dest[destPos] = (char)value;
      destPos++;
      continue;
    }
    if (value >= 0xD800 && value < 0xE000)
    {
      UInt32 c2;
      if (value >= 0xDC00 || srcPos == srcLen)
        break;
      c2 = src[srcPos++];
      if (c2 < 0xDC00 || c2 >= 0xE000)
        break;
      value = (((value - 0xD800) << 10) | (c2 - 0xDC00)) + 0x10000;
    }
    for (numAdds = 1; numAdds < 5; numAdds++)
      if (value < (((UInt32)1) << (numAdds * 5 + 6)))
        break;
    if (dest)
      dest[destPos] = (char)(kUtf8Limits[numAdds - 1] + (value >> (6 * numAdds)));
    destPos++;
    do
    {
      numAdds--;
      if (dest)
        dest[destPos] = (char)(0x80 + ((value >> (6 * numAdds)) & 0x3F));
      destPos++;
    }
    while (numAdds != 0);
  }
  *destLen = destPos;
  return False;
}

static SRes Utf16_To_Utf8Buf(CBuf *dest, const UInt16 *src, size_t srcLen)
{
  size_t destLen = 0;
  Bool res;
  Utf16_To_Utf8(NULL, &destLen, src, srcLen);
  destLen += 1;
  if (!Buf_EnsureSize(dest, destLen))
    return SZ_ERROR_MEM;
  res = Utf16_To_Utf8(dest->data, &destLen, src, srcLen);
  dest->data[destLen] = 0;
  return res ? SZ_OK : SZ_ERROR_FAIL;
}
#endif

static WRes Utf16_To_Char(CBuf *buf, const UInt16 *s, int fileMode)
{
  int len = 0;
  for (len = 0; s[len] != '\0'; len++);

  #ifdef _WIN32
  {
    int size = len * 3 + 100;
    if (!Buf_EnsureSize(buf, size))
      return SZ_ERROR_MEM;
    {
      char defaultChar = '_';
      BOOL defUsed;
      int numChars = WideCharToMultiByte(fileMode ? (AreFileApisANSI() ? CP_ACP : CP_OEMCP) : CP_OEMCP,
          0, s, len, (char *)buf->data, size, &defaultChar, &defUsed);
      if (numChars == 0 || numChars >= size)
        return SZ_ERROR_FAIL;
      buf->data[numChars] = 0;
      return SZ_OK;
    }
  }
  #else
  fileMode = fileMode;
  return Utf16_To_Utf8Buf(buf, s, len);
  #endif
}

static WRes MyCreateDir(const UInt16 *name)
{
  #ifdef USE_WINDOWS_FILE
  
  return CreateDirectoryW(name, NULL) ? 0 : GetLastError();
  
  #else

  CBuf buf;
  WRes res;
  Buf_Init(&buf);
  RINOK(Utf16_To_Char(&buf, name, 1));

  res =
  #ifdef _WIN32
  _mkdir((const char *)buf.data)
  #else
  mkdir((const char *)buf.data, 0777)
  #endif
  == 0 ? 0 : errno;
  Buf_Free(&buf, &g_Alloc);
  return res;
  
  #endif
}

static WRes OutFile_OpenUtf16(CSzFile *p, const UInt16 *name)
{
  #ifdef USE_WINDOWS_FILE
  return OutFile_OpenW(p, name);
  #else
  CBuf buf;
  WRes res;
  Buf_Init(&buf);
  RINOK(Utf16_To_Char(&buf, name, 1));
  res = OutFile_Open(p, (const char *)buf.data);
  Buf_Free(&buf, &g_Alloc);
  return res;
  #endif
}

//static void PrintString(const UInt16 *s)
//{
//  CBuf buf;
//  Buf_Init(&buf);
//  if (Utf16_To_Char(&buf, s, 0) == 0)
//  {
//    printf("%s", buf.data);
//  }
//  Buf_Free(&buf, &g_Alloc);
//}

//static void UInt64ToStr(UInt64 value, char *s)
//{
//  char temp[32];
//  int pos = 0;
//  do
//  {
//    temp[pos++] = (char)('0' + (unsigned)(value % 10));
//    value /= 10;
//  }
//  while (value != 0);
//  do
//    *s++ = temp[--pos];
//  while (pos);
//  *s = '\0';
//}

//static char *UIntToStr(char *s, unsigned value, int numDigits)
//{
//  char temp[16];
//  int pos = 0;
//  do
//    temp[pos++] = (char)('0' + (value % 10));
//  while (value /= 10);
//  for (numDigits -= pos; numDigits > 0; numDigits--)
//    *s++ = '0';
//  do
//    *s++ = temp[--pos];
//  while (pos);
//  *s = '\0';
//  return s;
//}

#define PERIOD_4 (4 * 365 + 1)
#define PERIOD_100 (PERIOD_4 * 25 - 1)
#define PERIOD_400 (PERIOD_100 * 4 + 1)

//static void ConvertFileTimeToString(const CNtfsFileTime *ft, char *s)
//{
//  unsigned year, mon, day, hour, min, sec;
//  UInt64 v64 = (ft->Low | ((UInt64)ft->High << 32)) / 10000000;
//  Byte ms[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
//  unsigned t;
//  UInt32 v;
//  sec = (unsigned)(v64 % 60); v64 /= 60;
//  min = (unsigned)(v64 % 60); v64 /= 60;
//  hour = (unsigned)(v64 % 24); v64 /= 24;
//
//  v = (UInt32)v64;
//
//  year = (unsigned)(1601 + v / PERIOD_400 * 400);
//  v %= PERIOD_400;
//
//  t = v / PERIOD_100; if (t ==  4) t =  3; year += t * 100; v -= t * PERIOD_100;
//  t = v / PERIOD_4;   if (t == 25) t = 24; year += t * 4;   v -= t * PERIOD_4;
//  t = v / 365;        if (t ==  4) t =  3; year += t;       v -= t * 365;
//
//  if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))
//    ms[1] = 29;
//  for (mon = 1; mon <= 12; mon++)
//  {
//    unsigned s = ms[mon - 1];
//    if (v < s)
//      break;
//    v -= s;
//  }
//  day = (unsigned)v + 1;
//  s = UIntToStr(s, year, 4); *s++ = '-';
//  s = UIntToStr(s, mon, 2);  *s++ = '-';
//  s = UIntToStr(s, day, 2);  *s++ = ' ';
//  s = UIntToStr(s, hour, 2); *s++ = ':';
//  s = UIntToStr(s, min, 2);  *s++ = ':';
//  s = UIntToStr(s, sec, 2);
//  s = s; // Avoids clang analyzer error about s value not being read
//}

void PrintError(char *sz)
{
  printf("\nERROR: %s\n", sz);
}

//#ifdef USE_WINDOWS_FILE
//#define kEmptyAttribChar '.'
//static void GetAttribString(UInt32 wa, Bool isDir, char *s)
//{
//  s[0] = (char)(((wa & FILE_ATTRIBUTE_DIRECTORY) != 0 || isDir) ? 'D' : kEmptyAttribChar);
//  s[1] = (char)(((wa & FILE_ATTRIBUTE_READONLY) != 0) ? 'R': kEmptyAttribChar);
//  s[2] = (char)(((wa & FILE_ATTRIBUTE_HIDDEN) != 0) ? 'H': kEmptyAttribChar);
//  s[3] = (char)(((wa & FILE_ATTRIBUTE_SYSTEM) != 0) ? 'S': kEmptyAttribChar);
//  s[4] = (char)(((wa & FILE_ATTRIBUTE_ARCHIVE) != 0) ? 'A': kEmptyAttribChar);
//  s[5] = '\0';
//}
//#else
//static void GetAttribString(UInt32 wa, Bool isDir, char *s)
//{
//  s[0] = '\0';
//}
//#endif

//int MY_CDECL unused_main(int numargs, char *args[])
//{
//  CFileInStream archiveStream;
//  CLookToRead lookStream;
//  CSzArEx db;
//  SRes res;
//  ISzAlloc allocImp;
//  ISzAlloc allocTempImp;
//  UInt16 *temp = NULL;
//  size_t tempSize = 0;
//
//  printf("\n7z ANSI-C Decoder " MY_VERSION_COPYRIGHT_DATE "\n\n");
//  if (numargs == 1)
//  {
//    printf(
//      "Usage: 7zDec <command> <archive_name>\n\n"
//      "<Commands>\n"
//      "  e: Extract files from archive (without using directory names)\n"
//      "  l: List contents of archive\n"
//      "  t: Test integrity of archive\n"
//      "  x: eXtract files with full paths\n");
//    return 0;
//  }
//  if (numargs < 3)
//  {
//    PrintError("incorrect command");
//    return 1;
//  }
//
//  allocImp.Alloc = SzAlloc;
//  allocImp.Free = SzFree;
//
//  allocTempImp.Alloc = SzAllocTemp;
//  allocTempImp.Free = SzFreeTemp;
//
//  if (InFile_Open(&archiveStream.file, args[2]))
//  {
//    PrintError("can not open input file");
//    return 1;
//  }
//
//  FileInStream_CreateVTable(&archiveStream);
//  LookToRead_CreateVTable(&lookStream, False);
//  
//  lookStream.realStream = &archiveStream.s;
//  LookToRead_Init(&lookStream);
//
//#ifdef _7ZIP_CRC_SUPPORT
//  CrcGenerateTable();
//#endif
//
//  SzArEx_Init(&db);
//  res = SzArEx_Open(&db, &lookStream.s, &allocImp, &allocTempImp);
//  if (res == SZ_OK)
//  {
//    char *command = args[1];
//    int listCommand = 0, testCommand = 0, /*extractCommand = 0,*/ fullPaths = 0;
//    if (strcmp(command, "l") == 0) listCommand = 1;
//    else if (strcmp(command, "t") == 0) testCommand = 1;
//    else if (strcmp(command, "e") == 0) { /*extractCommand = 1;*/ }
//    else if (strcmp(command, "x") == 0) { /*extractCommand = 1;*/ fullPaths = 1; }
//    else
//    {
//      PrintError("incorrect command");
//      res = SZ_ERROR_FAIL;
//    }
//
//    if (res == SZ_OK)
//    {
//      UInt32 i;
//
//      /*
//      if you need cache, use these 3 variables.
//      if you use external function, you can make these variable as static.
//      */
//      UInt32 blockIndex = 0xFFFFFFFF; /* it can have any value before first call (if outBuffer = 0) */
//      Byte *outBuffer = 0; /* it must be 0 before first call for each new archive. */
//      size_t outBufferSize = 0;  /* it can have any value before first call (if outBuffer = 0) */
//
//      for (i = 0; i < db.db.NumFiles; i++)
//      {
//        size_t offset = 0;
//        size_t outSizeProcessed = 0;
//        const CSzFileItem *f = db.db.Files + i;
//        size_t len;
//        if (listCommand == 0 && f->IsDir && !fullPaths)
//          continue;
//        len = SzArEx_GetFileNameUtf16(&db, i, NULL);
//
//        if (len > tempSize)
//        {
//          SzFree(NULL, temp);
//          tempSize = len;
//          temp = (UInt16 *)SzAlloc(NULL, tempSize * sizeof(temp[0]));
//          if (temp == 0)
//          {
//            res = SZ_ERROR_MEM;
//            break;
//          }
//        }
//
//        SzArEx_GetFileNameUtf16(&db, i, temp);
//        if (listCommand)
//        {
//          char attr[8], s[32], t[32];
//
//          GetAttribString(f->AttribDefined ? f->Attrib : 0, f->IsDir, attr);
//
//          UInt64ToStr(f->Size, s);
//          if (f->MTimeDefined)
//            ConvertFileTimeToString(&f->MTime, t);
//          else
//          {
//            size_t j;
//            for (j = 0; j < 19; j++)
//              t[j] = ' ';
//            t[j] = '\0';
//          }
//          
//          printf("%s %s %10s  ", t, attr, s);
//          PrintString(temp);
//          if (f->IsDir)
//            printf("/");
//          printf("\n");
//          continue;
//        }
//        printf(testCommand ?
//            "Testing    ":
//            "Extracting ");
//        PrintString(temp);
//        if (f->IsDir)
//          printf("/");
//        else
//        {
//          res = SzArEx_Extract(&db, &lookStream.s, i,
//              &blockIndex, &outBuffer, &outBufferSize,
//              &offset, &outSizeProcessed,
//              &allocImp, &allocTempImp);
//          if (res != SZ_OK)
//            break;
//        }
//        if (!testCommand)
//        {
//          CSzFile outFile;
//          size_t processedSize;
//          size_t j;
//          UInt16 *name = (UInt16 *)temp;
//          const UInt16 *destPath = (const UInt16 *)name;
//          for (j = 0; (name != NULL) && (name[j] != 0); j++)
//            if (name[j] == '/')
//            {
//              if (fullPaths)
//              {
//                name[j] = 0;
//                MyCreateDir(name);
//                name[j] = CHAR_PATH_SEPARATOR;
//              }
//              else
//                destPath = name + j + 1;
//            }
//    
//          if (f->IsDir)
//          {
//            MyCreateDir(destPath);
//            printf("\n");
//            continue;
//          }
//          else if (OutFile_OpenUtf16(&outFile, destPath))
//          {
//            PrintError("can not open output file");
//            res = SZ_ERROR_FAIL;
//            break;
//          }
//          processedSize = outSizeProcessed;
//          if (File_Write(&outFile, outBuffer + offset, &processedSize) != 0 || processedSize != outSizeProcessed)
//          {
//            PrintError("can not write output file");
//            res = SZ_ERROR_FAIL;
//            break;
//          }
//          if (File_Close(&outFile))
//          {
//            PrintError("can not close output file");
//            res = SZ_ERROR_FAIL;
//            break;
//          }
//          #ifdef USE_WINDOWS_FILE
//          if (f->AttribDefined)
//            SetFileAttributesW(destPath, f->Attrib);
//          #endif
//        }
//        printf("\n");
//      }
//      IAlloc_Free(&allocImp, outBuffer);
//    }
//  }
//  SzArEx_Free(&db, &allocImp);
//  SzFree(NULL, temp);
//
//  File_Close(&archiveStream.file);
//  if (res == SZ_OK)
//  {
//    printf("\nEverything is Ok\n");
//    return 0;
//  }
//  if (res == SZ_ERROR_UNSUPPORTED)
//    PrintError("decoder doesn't support this archive");
//  else if (res == SZ_ERROR_MEM)
//    PrintError("can not allocate memory");
//  else if (res == SZ_ERROR_CRC)
//    PrintError("CRC error");
//  else
//    printf("\nERROR #%d\n", res);
//  return 1;
//}

// This entry point will extract all the contents of a .7z file
// into the current directory when entryName is NULL. If
// entryName is not NULL, then this method will extract a single
// entry that has the name indicated in entryName. When extracting
// all files, the files are created in the current directory. If
// a single file is extracted by passing a non-NULL entryName,
// then the file data is written to the path indicated by entryPath.

//#define DEBUG_OUTPUT

int do7z_extract_entry(char *archivePath, char *archiveCachePath, char *entryName, char *entryPath, int fullPaths)
{
  CFileInStream archiveStream;
  CLookToRead lookStream;
  CSzArEx db;
  SRes res;
  ISzAlloc allocImp;
  ISzAlloc allocTempImp;
  UInt16 *temp = NULL;
  size_t tempSize = 0;
  int foundMatchingEntryName = 0;
  int extractAllFiles = 0;

/*
  printf("\n7z ANSI-C Decoder " MY_VERSION_COPYRIGHT_DATE "\n\n");
  if (numargs == 1)
  {
    printf(
           "Usage: 7zDec <command> <archive_name>\n\n"
           "<Commands>\n"
           "  e: Extract files from archive (without using directory names)\n"
           "  l: List contents of archive\n"
           "  t: Test integrity of archive\n"
           "  x: eXtract files with full paths\n");
    return 0;
  }
  if (numargs < 3)
  {
    PrintError("incorrect command");
    return 1;
  }
*/
  
  allocImp.Alloc = SzAlloc;
  allocImp.Free = SzFree;
  
  allocTempImp.Alloc = SzAllocTemp;
  allocTempImp.Free = SzFreeTemp;
  
  if (InFile_Open(&archiveStream.file, archivePath))
  {
    PrintError("can not open input file");
    return 1;
  }
  
  FileInStream_CreateVTable(&archiveStream);
  LookToRead_CreateVTable(&lookStream, False);
  
  lookStream.realStream = &archiveStream.s;
  LookToRead_Init(&lookStream);
  
#ifdef _7ZIP_CRC_SUPPORT
  CrcGenerateTable();
#else
  //CPU_Is_InOrder(); // Not needed currently
#endif
  
  SzArEx_Init(&db);
  res = SzArEx_Open(&db, &lookStream.s, &allocImp, &allocTempImp);
  if (res == SZ_OK)
  {
    const int extractCommand = 1;
    
    assert(archiveCachePath);
    
    if (entryName == NULL) {
      extractAllFiles = 1;
    } else {
      assert(strlen(entryName) > 0);
      assert(entryPath != NULL);
      assert(strlen(entryPath) > 0);
    }
    
    if (extractCommand)
    {
      UInt32 i;
      
      // The dictionary cache contains data decompressed from the archive. It is managed by
      // the library and must be freed when done with processing of a specific archive.
      // Note that the cache cannot be saved from one execution to the next, it must
      // not exist after this function is done executing.
      
      SzArEx_DictCache dictCache;
      SzArEx_DictCache_init(&dictCache, &allocImp);

      // Enable mmap to file if the archive would be larger than 1/2 meg
      dictCache.mapFilename = archiveCachePath;
      
      for (i = 0; i < db.db.NumFiles; i++)
      {
        const CSzFileItem *f = db.db.Files + i;
        size_t len;
        if (f->IsDir && !fullPaths)
          continue;
        len = SzArEx_GetFileNameUtf16(&db, i, NULL);
        
        if (len > tempSize)
        {
          SzFree(NULL, temp);
          tempSize = len;
          temp = (UInt16 *)SzAlloc(NULL, tempSize * sizeof(temp[0]));
          if (temp == 0)
          {
            res = SZ_ERROR_MEM;
            break;
          }
        }
        
        SzArEx_GetFileNameUtf16(&db, i, temp);

#ifdef DEBUG_OUTPUT
        printf(testCommand ?
               "Testing    ":
               "Extracting ");
        PrintString(temp);
#endif
        if (f->IsDir) {
#ifdef DEBUG_OUTPUT
          printf("/");
#endif
        }
        else
        {
          // When extracting a specific entry, skip extraction if the
          // entry name does not match exatly.
          
          if (!extractAllFiles) {
            CBuf buf;
            Buf_Init(&buf);
            if (temp && (Utf16_To_Char(&buf, temp, 0) == 0))
            {
              if (strcmp((char*)buf.data, entryName) != 0) {
                // This is not the entry we are interested in extracting
                Buf_Free(&buf, &g_Alloc);
                continue;
              }
            }
            Buf_Free(&buf, &g_Alloc);
          }
          
//          if (0) {
//            printf("Extracting ");
//            PrintString(temp);
//            printf("\n");
//          }          
          
          foundMatchingEntryName = 1;
          
          res = SzArEx_Extract(&db,
                               &lookStream.s,
                               i, // archive entry offset
                               &dictCache,
                               &allocImp, &allocTempImp);
          if (res != SZ_OK)
            break;
        }
        
        {
          CSzFile outFile;
          size_t processedSize;
          size_t j;
          UInt16 *name = (UInt16 *)temp;
          const UInt16 *destPath;
          
          if (extractAllFiles) {
            // Extract to current dir, path is based on the entry path
            
            destPath = (const UInt16 *)name;
          
            for (j = 0; name[j] != 0; j++)
            {
              if (name[j] == '/')
              {
                if (fullPaths)
                {
                  name[j] = 0;
                  MyCreateDir(name);
                  name[j] = CHAR_PATH_SEPARATOR;
                }
                else {
                  destPath = name + j + 1;
                }
              }
            }
          } else {
            // Extract to specific fully qualified path
            
            SzFree(NULL, temp);
            temp = (UInt16 *)SzAlloc(NULL, (strlen(entryPath) + 1) * sizeof(UInt16));
            int i = 0;
            for (i = 0; i < strlen(entryPath); i++) {
              temp[i] = entryPath[i];
            }
            temp[i] = '\0';
            destPath = (const UInt16 *) temp;
          }
          
          if (f->IsDir)
          {
            MyCreateDir(destPath);
#ifdef DEBUG_OUTPUT
            printf("\n");
#endif
            continue;
          }
          else if (OutFile_OpenUtf16(&outFile, destPath))
          {
            PrintError("can not open output file");
            res = SZ_ERROR_FAIL;
            break;
          }
          processedSize = dictCache.outSizeProcessed;
          void *entryPtr = dictCache.outBuffer + dictCache.entryOffset;
          if (File_Write(&outFile, entryPtr, &processedSize) != 0 || processedSize != dictCache.outSizeProcessed)
          {
            PrintError("can not write output file");
            res = SZ_ERROR_FAIL;
            break;
          }
          if (File_Close(&outFile))
          {
            PrintError("can not close output file");
            res = SZ_ERROR_FAIL;
            break;
          }
        }
#ifdef DEBUG_OUTPUT
        printf("\n");
#endif
      }
      SzArEx_DictCache_free(&dictCache);
    }
  }
  SzArEx_Free(&db, &allocImp);
  SzFree(NULL, temp);
  
  File_Close(&archiveStream.file);
  if (!extractAllFiles && (foundMatchingEntryName == 0)) {
    // Did not find a matching entry in the archive
#ifdef DEBUG_OUTPUT
    printf("\nCould not find matching entry in archive\n");
#endif
    return 1;    
  }
  
  if (archiveCachePath) {
    // remove cache file if it exists
    unlink(archiveCachePath);
  }
  
  if (res == SZ_OK)
  {
#ifdef DEBUG_OUTPUT
    printf("\nEverything is Ok\n");
#endif
    return 0;
  }
  if (res == SZ_ERROR_UNSUPPORTED)
    PrintError("decoder doesn't support this archive");
  else if (res == SZ_ERROR_MEM)
    PrintError("can not allocate memory");
  else if (res == SZ_ERROR_CRC)
    PrintError("CRC error");
  else
    printf("\nERROR #%d\n", res);
  return 1;
}
