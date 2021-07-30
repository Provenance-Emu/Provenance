/*
 * PicoDrive
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "pico_int.h"
#include "../cpu/debug.h"
#include "../unzip/unzip.h"
#include <zlib.h>


static int rom_alloc_size;
static const char *rom_exts[] = { "bin", "gen", "smd", "iso", "sms", "gg", "sg" };

void (*PicoCartUnloadHook)(void);
void (*PicoCartMemSetup)(void);

void (*PicoCartLoadProgressCB)(int percent) = NULL;
void (*PicoCDLoadProgressCB)(const char *fname, int percent) = NULL; // handled in Pico/cd/cd_file.c

int PicoGameLoaded;

static void PicoCartDetect(const char *carthw_cfg);

/* cso struct */
typedef struct _cso_struct
{
  unsigned char in_buff[2*2048];
  unsigned char out_buff[2048];
  struct {
    char          magic[4];
    unsigned int  unused;
    unsigned int  total_bytes;
    unsigned int  total_bytes_high; // ignored here
    unsigned int  block_size;  // 10h
    unsigned char ver;
    unsigned char align;
    unsigned char reserved[2];
  } header;
  unsigned int  fpos_in;  // input file read pointer
  unsigned int  fpos_out; // pos in virtual decompressed file
  int block_in_buff;      // block which we have read in in_buff
  int pad;
  int index[0];
}
cso_struct;

static int uncompress_buf(void *dest, int destLen, void *source, int sourceLen)
{
    z_stream stream;
    int err;

    stream.next_in = (Bytef*)source;
    stream.avail_in = (uInt)sourceLen;
    stream.next_out = dest;
    stream.avail_out = (uInt)destLen;

    stream.zalloc = NULL;
    stream.zfree = NULL;

    err = inflateInit2(&stream, -15);
    if (err != Z_OK) return err;

    err = inflate(&stream, Z_FINISH);
    if (err != Z_STREAM_END) {
        inflateEnd(&stream);
        return err;
    }
    //*destLen = stream.total_out;

    return inflateEnd(&stream);
}

static const char *get_ext(const char *path)
{
  const char *ext;
  if (strlen(path) < 4)
    return ""; // no ext

  // allow 2 or 3 char extensions for now
  ext = path + strlen(path) - 2;
  if (ext[-1] != '.') ext--;
  if (ext[-1] != '.')
    return "";
  return ext;
}

struct zip_file {
  pm_file file;
  ZIP *zip;
  struct zipent *entry;
  z_stream stream;
  unsigned char inbuf[16384];
  long start;
  unsigned int pos;
};

pm_file *pm_open(const char *path)
{
  pm_file *file = NULL;
  const char *ext;
  FILE *f;

  if (path == NULL)
    return NULL;

  ext = get_ext(path);
  if (strcasecmp(ext, "zip") == 0)
  {
    struct zip_file *zfile = NULL;
    struct zipent *zipentry;
    ZIP *zipfile;
    int i, ret;

    zipfile = openzip(path);
    if (zipfile != NULL)
    {
      /* search for suitable file (right extension or large enough file) */
      while ((zipentry = readzip(zipfile)) != NULL)
      {
        ext = get_ext(zipentry->name);

        if (zipentry->uncompressed_size >= 32*1024)
          goto found_rom_zip;

        for (i = 0; i < sizeof(rom_exts)/sizeof(rom_exts[0]); i++)
          if (strcasecmp(ext, rom_exts[i]) == 0)
            goto found_rom_zip;
      }

      /* zipfile given, but nothing found suitable for us inside */
      goto zip_failed;

found_rom_zip:
      zfile = calloc(1, sizeof(*zfile));
      if (zfile == NULL)
        goto zip_failed;
      ret = seekcompresszip(zipfile, zipentry);
      if (ret != 0)
        goto zip_failed;
      ret = inflateInit2(&zfile->stream, -15);
      if (ret != Z_OK) {
        elprintf(EL_STATUS, "zip: inflateInit2 %d", ret);
        goto zip_failed;
      }
      zfile->zip = zipfile;
      zfile->entry = zipentry;
      zfile->start = ftell(zipfile->fp);
      zfile->file.file = zfile;
      zfile->file.size = zipentry->uncompressed_size;
      zfile->file.type = PMT_ZIP;
      strncpy(zfile->file.ext, ext, sizeof(zfile->file.ext) - 1);
      return &zfile->file;

zip_failed:
      closezip(zipfile);
      free(zfile);
      return NULL;
    }
  }
  else if (strcasecmp(ext, "cso") == 0)
  {
    cso_struct *cso = NULL, *tmp = NULL;
    int size;
    f = fopen(path, "rb");
    if (f == NULL)
      goto cso_failed;

#ifdef __GP2X__
    /* we use our own buffering */
    setvbuf(f, NULL, _IONBF, 0);
#endif

    cso = malloc(sizeof(*cso));
    if (cso == NULL)
      goto cso_failed;

    if (fread(&cso->header, 1, sizeof(cso->header), f) != sizeof(cso->header))
      goto cso_failed;

    if (strncmp(cso->header.magic, "CISO", 4) != 0) {
      elprintf(EL_STATUS, "cso: bad header");
      goto cso_failed;
    }

    if (cso->header.block_size != 2048) {
      elprintf(EL_STATUS, "cso: bad block size (%u)", cso->header.block_size);
      goto cso_failed;
    }

    size = ((cso->header.total_bytes >> 11) + 1)*4 + sizeof(*cso);
    tmp = realloc(cso, size);
    if (tmp == NULL)
      goto cso_failed;
    cso = tmp;
    elprintf(EL_STATUS, "allocated %i bytes for CSO struct", size);

    size -= sizeof(*cso); // index size
    if (fread(cso->index, 1, size, f) != size) {
      elprintf(EL_STATUS, "cso: premature EOF");
      goto cso_failed;
    }

    // all ok
    cso->fpos_in = ftell(f);
    cso->fpos_out = 0;
    cso->block_in_buff = -1;
    file = calloc(1, sizeof(*file));
    if (file == NULL) goto cso_failed;
    file->file  = f;
    file->param = cso;
    file->size  = cso->header.total_bytes;
    file->type  = PMT_CSO;
    return file;

cso_failed:
    if (cso != NULL) free(cso);
    if (f != NULL) fclose(f);
    return NULL;
  }

  /* not a zip, treat as uncompressed file */
  f = fopen(path, "rb");
  if (f == NULL) return NULL;

  file = calloc(1, sizeof(*file));
  if (file == NULL) {
    fclose(f);
    return NULL;
  }
  fseek(f, 0, SEEK_END);
  file->file  = f;
  file->param = NULL;
  file->size  = ftell(f);
  file->type  = PMT_UNCOMPRESSED;
  strncpy(file->ext, ext, sizeof(file->ext) - 1);
  fseek(f, 0, SEEK_SET);

#ifdef __GP2X__
  if (file->size > 0x400000)
    /* we use our own buffering */
    setvbuf(f, NULL, _IONBF, 0);
#endif

  return file;
}

size_t pm_read(void *ptr, size_t bytes, pm_file *stream)
{
  int ret;

  if (stream->type == PMT_UNCOMPRESSED)
  {
    ret = fread(ptr, 1, bytes, stream->file);
  }
  else if (stream->type == PMT_ZIP)
  {
    struct zip_file *z = stream->file;

    if (z->entry->compression_method == 0) {
      int ret = fread(ptr, 1, bytes, z->zip->fp);
      z->pos += ret;
      return ret;
    }

    z->stream.next_out = ptr;
    z->stream.avail_out = bytes;
    while (z->stream.avail_out != 0) {
      if (z->stream.avail_in == 0) {
        z->stream.avail_in = fread(z->inbuf, 1, sizeof(z->inbuf), z->zip->fp);
        if (z->stream.avail_in == 0)
          break;
        z->stream.next_in = z->inbuf;
      }
      ret = inflate(&z->stream, Z_NO_FLUSH);
      if (ret == Z_STREAM_END)
        break;
      if (ret != Z_OK) {
        elprintf(EL_STATUS, "zip: inflate: %d", ret);
        return 0;
      }
    }
    z->pos += bytes - z->stream.avail_out;
    return bytes - z->stream.avail_out;
  }
  else if (stream->type == PMT_CSO)
  {
    cso_struct *cso = stream->param;
    int read_pos, read_len, out_offs, rret;
    int block = cso->fpos_out >> 11;
    int index = cso->index[block];
    int index_end = cso->index[block+1];
    unsigned char *out = ptr, *tmp_dst;

    ret = 0;
    while (bytes != 0)
    {
      out_offs = cso->fpos_out&0x7ff;
      if (out_offs == 0 && bytes >= 2048)
           tmp_dst = out;
      else tmp_dst = cso->out_buff;

      read_pos = (index&0x7fffffff) << cso->header.align;

      if (index < 0) {
        if (read_pos != cso->fpos_in)
          fseek(stream->file, read_pos, SEEK_SET);
        rret = fread(tmp_dst, 1, 2048, stream->file);
        cso->fpos_in = read_pos + rret;
        if (rret != 2048) break;
      } else {
        read_len = (((index_end&0x7fffffff) << cso->header.align) - read_pos) & 0xfff;
        if (block != cso->block_in_buff)
        {
          if (read_pos != cso->fpos_in)
            fseek(stream->file, read_pos, SEEK_SET);
          rret = fread(cso->in_buff, 1, read_len, stream->file);
          cso->fpos_in = read_pos + rret;
          if (rret != read_len) {
            elprintf(EL_STATUS, "cso: read failed @ %08x", read_pos);
            break;
          }
          cso->block_in_buff = block;
        }
        rret = uncompress_buf(tmp_dst, 2048, cso->in_buff, read_len);
        if (rret != 0) {
          elprintf(EL_STATUS, "cso: uncompress failed @ %08x with %i", read_pos, rret);
          break;
        }
      }

      rret = 2048;
      if (out_offs != 0 || bytes < 2048) {
        //elprintf(EL_STATUS, "cso: unaligned/nonfull @ %08x, offs=%i, len=%u", cso->fpos_out, out_offs, bytes);
        if (bytes < rret) rret = bytes;
        if (2048 - out_offs < rret) rret = 2048 - out_offs;
        memcpy(out, tmp_dst + out_offs, rret);
      }
      ret += rret;
      out += rret;
      cso->fpos_out += rret;
      bytes -= rret;
      block++;
      index = index_end;
      index_end = cso->index[block+1];
    }
  }
  else
    ret = 0;

  return ret;
}

int pm_seek(pm_file *stream, long offset, int whence)
{
  if (stream->type == PMT_UNCOMPRESSED)
  {
    fseek(stream->file, offset, whence);
    return ftell(stream->file);
  }
  else if (stream->type == PMT_ZIP)
  {
    struct zip_file *z = stream->file;
    unsigned int pos = z->pos;
    int ret;

    switch (whence)
    {
      case SEEK_CUR: pos += offset; break;
      case SEEK_SET: pos  = offset; break;
      case SEEK_END: pos  = stream->size - offset; break;
    }
    if (z->entry->compression_method == 0) {
      ret = fseek(z->zip->fp, z->start + pos, SEEK_SET);
      if (ret == 0)
        return (z->pos = pos);
      return -1;
    }
    offset = pos - z->pos;
    if (pos < z->pos) {
      // full decompress from the start
      fseek(z->zip->fp, z->start, SEEK_SET);
      z->stream.avail_in = 0;
      z->stream.next_in = z->inbuf;
      inflateReset(&z->stream);
      z->pos = 0;
      offset = pos;
    }

    if (PicoIn.osdMessage != NULL && offset > 4 * 1024 * 1024)
      PicoIn.osdMessage("Decompressing data...");

    while (offset > 0) {
      char buf[16 * 1024];
      size_t l = offset > sizeof(buf) ? sizeof(buf) : offset;
      ret = pm_read(buf, l, stream);
      if (ret != l)
        break;
      offset -= l;
    }
    return z->pos;
  }
  else if (stream->type == PMT_CSO)
  {
    cso_struct *cso = stream->param;
    switch (whence)
    {
      case SEEK_CUR: cso->fpos_out += offset; break;
      case SEEK_SET: cso->fpos_out  = offset; break;
      case SEEK_END: cso->fpos_out  = cso->header.total_bytes - offset; break;
    }
    return cso->fpos_out;
  }
  else
    return -1;
}

int pm_close(pm_file *fp)
{
  int ret = 0;

  if (fp == NULL) return EOF;

  if (fp->type == PMT_UNCOMPRESSED)
  {
    fclose(fp->file);
  }
  else if (fp->type == PMT_ZIP)
  {
    struct zip_file *z = fp->file;
    inflateEnd(&z->stream);
    closezip(z->zip);
  }
  else if (fp->type == PMT_CSO)
  {
    free(fp->param);
    fclose(fp->file);
  }
  else
    ret = EOF;

  free(fp);
  return ret;
}

// byteswap, data needs to be int aligned, src can match dst
void Byteswap(void *dst, const void *src, int len)
{
  const unsigned int *ps = src;
  unsigned int *pd = dst;
  int i, m;

  if (len < 2)
    return;

  m = 0x00ff00ff;
  for (i = 0; i < len / 4; i++) {
    unsigned int t = ps[i];
    pd[i] = ((t & m) << 8) | ((t & ~m) >> 8);
  }
}

// Interleve a 16k block and byteswap
static int InterleveBlock(unsigned char *dest,unsigned char *src)
{
  int i=0;
  for (i=0;i<0x2000;i++) dest[(i<<1)  ]=src[       i]; // Odd
  for (i=0;i<0x2000;i++) dest[(i<<1)+1]=src[0x2000+i]; // Even
  return 0;
}

// Decode a SMD file
static int DecodeSmd(unsigned char *data,int len)
{
  unsigned char *temp=NULL;
  int i=0;

  temp=(unsigned char *)malloc(0x4000);
  if (temp==NULL) return 1;
  memset(temp,0,0x4000);

  // Interleve each 16k block and shift down by 0x200:
  for (i=0; i+0x4200<=len; i+=0x4000)
  {
    InterleveBlock(temp,data+0x200+i); // Interleve 16k to temporary buffer
    memcpy(data+i,temp,0x4000); // Copy back in
  }

  free(temp);
  return 0;
}

static unsigned char *PicoCartAlloc(int filesize, int is_sms)
{
  unsigned char *rom;

  if (is_sms) {
    // make size power of 2 for easier banking handling
    int s = 0, tmp = filesize;
    while ((tmp >>= 1) != 0)
      s++;
    if (filesize > (1 << s))
      s++;
    rom_alloc_size = 1 << s;
    // be sure we can cover all address space
    if (rom_alloc_size < 0x10000)
      rom_alloc_size = 0x10000;
  }
  else {
    // make alloc size at least sizeof(mcd_state),
    // in case we want to switch to CD mode
    if (filesize < sizeof(mcd_state))
      filesize = sizeof(mcd_state);

    // align to 512K for memhandlers
    rom_alloc_size = (filesize + 0x7ffff) & ~0x7ffff;
  }

  if (rom_alloc_size - filesize < 4)
    rom_alloc_size += 4; // padding for out-of-bound exec protection

  // Allocate space for the rom plus padding
  // use special address for 32x dynarec
  rom = plat_mmap(0x02000000, rom_alloc_size, 0, 0);
  return rom;
}

int PicoCartLoad(pm_file *f,unsigned char **prom,unsigned int *psize,int is_sms)
{
  unsigned char *rom;
  int size, bytes_read;

  if (f == NULL)
    return 1;

  size = f->size;
  if (size <= 0) return 1;
  size = (size+3)&~3; // Round up to a multiple of 4

  // Allocate space for the rom plus padding
  rom = PicoCartAlloc(size, is_sms);
  if (rom == NULL) {
    elprintf(EL_STATUS, "out of memory (wanted %i)", size);
    return 2;
  }

  if (PicoCartLoadProgressCB != NULL)
  {
    // read ROM in blocks, just for fun
    int ret;
    unsigned char *p = rom;
    bytes_read=0;
    do
    {
      int todo = size - bytes_read;
      if (todo > 256*1024) todo = 256*1024;
      ret = pm_read(p,todo,f);
      bytes_read += ret;
      p += ret;
      PicoCartLoadProgressCB(bytes_read * 100 / size);
    }
    while (ret > 0);
  }
  else
    bytes_read = pm_read(rom,size,f); // Load up the rom
  if (bytes_read <= 0) {
    elprintf(EL_STATUS, "read failed");
    plat_munmap(rom, rom_alloc_size);
    return 3;
  }

  if (!is_sms)
  {
    // maybe we are loading MegaCD BIOS?
    if (!(PicoIn.AHW & PAHW_MCD) && size == 0x20000 && (!strncmp((char *)rom+0x124, "BOOT", 4) ||
         !strncmp((char *)rom+0x128, "BOOT", 4))) {
      PicoIn.AHW |= PAHW_MCD;
    }

    // Check for SMD:
    if (size >= 0x4200 && (size&0x3fff) == 0x200 &&
        ((rom[0x2280] == 'S' && rom[0x280] == 'E') || (rom[0x280] == 'S' && rom[0x2281] == 'E'))) {
      elprintf(EL_STATUS, "SMD format detected.");
      DecodeSmd(rom,size); size-=0x200; // Decode and byteswap SMD
    }
    else Byteswap(rom, rom, size); // Just byteswap
  }
  else
  {
    if (size >= 0x4200 && (size&0x3fff) == 0x200) {
      elprintf(EL_STATUS, "SMD format detected.");
      // at least here it's not interleaved
      size -= 0x200;
      memmove(rom, rom + 0x200, size);
    }
  }

  if (prom)  *prom = rom;
  if (psize) *psize = size;

  return 0;
}

// Insert a cartridge:
int PicoCartInsert(unsigned char *rom, unsigned int romsize, const char *carthw_cfg)
{
  // notaz: add a 68k "jump one op back" opcode to the end of ROM.
  // This will hang the emu, but will prevent nasty crashes.
  // note: 4 bytes are padded to every ROM
  if (rom != NULL)
    *(unsigned long *)(rom+romsize) = 0xFFFE4EFA; // 4EFA FFFE byteswapped

  Pico.rom=rom;
  Pico.romsize=romsize;

  if (Pico.sv.data) {
    free(Pico.sv.data);
    Pico.sv.data = NULL;
  }

  if (PicoCartUnloadHook != NULL) {
    PicoCartUnloadHook();
    PicoCartUnloadHook = NULL;
  }
  pdb_cleanup();

  PicoIn.AHW &= PAHW_MCD|PAHW_SMS;

  PicoCartMemSetup = NULL;
  PicoDmaHook = NULL;
  PicoResetHook = NULL;
  PicoLineHook = NULL;
  PicoLoadStateHook = NULL;
  carthw_chunks = NULL;

  if (!(PicoIn.AHW & (PAHW_MCD|PAHW_SMS)))
    PicoCartDetect(carthw_cfg);

  // setup correct memory map for loaded ROM
  switch (PicoIn.AHW) {
    default:
      elprintf(EL_STATUS|EL_ANOMALY, "starting in unknown hw configuration: %x", PicoIn.AHW);
    case 0:
    case PAHW_SVP:  PicoMemSetup(); break;
    case PAHW_MCD:  PicoMemSetupCD(); break;
    case PAHW_PICO: PicoMemSetupPico(); break;
    case PAHW_SMS:  PicoMemSetupMS(); break;
  }

  if (PicoCartMemSetup != NULL)
    PicoCartMemSetup();

  if (PicoIn.AHW & PAHW_SMS)
    PicoPowerMS();
  else
    PicoPower();

  PicoGameLoaded = 1;
  return 0;
}

int PicoCartResize(int newsize)
{
  void *tmp = plat_mremap(Pico.rom, rom_alloc_size, newsize);
  if (tmp == NULL)
    return -1;

  Pico.rom = tmp;
  rom_alloc_size = newsize;
  return 0;
}

void PicoCartUnload(void)
{
  if (PicoCartUnloadHook != NULL) {
    PicoCartUnloadHook();
    PicoCartUnloadHook = NULL;
  }

  if (PicoIn.AHW & PAHW_32X)
    PicoUnload32x();

  if (Pico.rom != NULL) {
    SekFinishIdleDet();
    plat_munmap(Pico.rom, rom_alloc_size);
    Pico.rom = NULL;
  }
  PicoGameLoaded = 0;
}

static unsigned int rom_crc32(void)
{
  unsigned int crc;
  elprintf(EL_STATUS, "caclulating CRC32..");

  // have to unbyteswap for calculation..
  Byteswap(Pico.rom, Pico.rom, Pico.romsize);
  crc = crc32(0, Pico.rom, Pico.romsize);
  Byteswap(Pico.rom, Pico.rom, Pico.romsize);
  return crc;
}

static int rom_strcmp(int rom_offset, const char *s1)
{
  int i, len = strlen(s1);
  const char *s_rom = (const char *)Pico.rom;
  if (rom_offset + len > Pico.romsize)
    return 0;
  for (i = 0; i < len; i++)
    if (s1[i] != s_rom[(i + rom_offset) ^ 1])
      return 1;
  return 0;
}

static unsigned int rom_read32(int addr)
{
  unsigned short *m = (unsigned short *)(Pico.rom + addr);
  return (m[0] << 16) | m[1];
}

static char *sskip(char *s)
{
  while (*s && isspace_(*s))
    s++;
  return s;
}

static void rstrip(char *s)
{
  char *p;
  for (p = s + strlen(s) - 1; p >= s; p--)
    if (isspace_(*p))
      *p = 0;
}

static int parse_3_vals(char *p, int *val0, int *val1, int *val2)
{
  char *r;
  *val0 = strtoul(p, &r, 0);
  if (r == p)
    goto bad;
  p = sskip(r);
  if (*p++ != ',')
    goto bad;
  *val1 = strtoul(p, &r, 0);
  if (r == p)
    goto bad;
  p = sskip(r);
  if (*p++ != ',')
    goto bad;
  *val2 = strtoul(p, &r, 0);
  if (r == p)
    goto bad;

  return 1;
bad:
  return 0;
}

static int is_expr(const char *expr, char **pr)
{
  int len = strlen(expr);
  char *p = *pr;

  if (strncmp(expr, p, len) != 0)
    return 0;
  p = sskip(p + len);
  if (*p != '=')
    return 0; // wrong or malformed

  *pr = sskip(p + 1);
  return 1;
}

#include "carthw_cfg.c"

static void parse_carthw(const char *carthw_cfg, int *fill_sram,
  int *hw_detected)
{
  int line = 0, any_checks_passed = 0, skip_sect = 0;
  const char *s, *builtin = builtin_carthw_cfg;
  int tmp, rom_crc = 0;
  char buff[256], *p, *r;
  FILE *f;

  f = fopen(carthw_cfg, "r");
  if (f == NULL)
    f = fopen("pico/carthw.cfg", "r");
  if (f == NULL)
    elprintf(EL_STATUS, "couldn't open carthw.cfg!");

  for (;;)
  {
    if (f != NULL) {
      p = fgets(buff, sizeof(buff), f);
      if (p == NULL)
        break;
    }
    else {
      if (*builtin == 0)
        break;
      for (s = builtin; *s != 0 && *s != '\n'; s++)
        ;
      while (*s == '\n')
        s++;
      tmp = s - builtin;
      if (tmp > sizeof(buff) - 1)
        tmp = sizeof(buff) - 1;
      memcpy(buff, builtin, tmp);
      buff[tmp] = 0;
      p = buff;
      builtin = s;
    }

    line++;
    p = sskip(p);
    if (*p == 0 || *p == '#')
      continue;

    if (*p == '[') {
      any_checks_passed = 0;
      skip_sect = 0;
      continue;
    }
    
    if (skip_sect)
      continue;

    /* look for checks */
    if (is_expr("check_str", &p))
    {
      int offs;
      offs = strtoul(p, &r, 0);
      if (offs < 0 || offs > Pico.romsize) {
        elprintf(EL_STATUS, "carthw:%d: check_str offs out of range: %d\n", line, offs);
	goto bad;
      }
      p = sskip(r);
      if (*p != ',')
        goto bad;
      p = sskip(p + 1);
      if (*p != '"')
        goto bad;
      p++;
      r = strchr(p, '"');
      if (r == NULL)
        goto bad;
      *r = 0;

      if (rom_strcmp(offs, p) == 0)
        any_checks_passed = 1;
      else
        skip_sect = 1;
      continue;
    }
    else if (is_expr("check_size_gt", &p))
    {
      int size;
      size = strtoul(p, &r, 0);
      if (r == p || size < 0)
        goto bad;

      if (Pico.romsize > size)
        any_checks_passed = 1;
      else
        skip_sect = 1;
      continue;
    }
    else if (is_expr("check_csum", &p))
    {
      int csum;
      csum = strtoul(p, &r, 0);
      if (r == p || (csum & 0xffff0000))
        goto bad;

      if (csum == (rom_read32(0x18c) & 0xffff))
        any_checks_passed = 1;
      else
        skip_sect = 1;
      continue;
    }
    else if (is_expr("check_crc32", &p))
    {
      unsigned int crc;
      crc = strtoul(p, &r, 0);
      if (r == p)
        goto bad;

      if (rom_crc == 0)
        rom_crc = rom_crc32();
      if (crc == rom_crc)
        any_checks_passed = 1;
      else
        skip_sect = 1;
      continue;
    }

    /* now time for actions */
    if (is_expr("hw", &p)) {
      if (!any_checks_passed)
        goto no_checks;
      *hw_detected = 1;
      rstrip(p);

      if      (strcmp(p, "svp") == 0)
        PicoSVPStartup();
      else if (strcmp(p, "pico") == 0)
        PicoInitPico();
      else if (strcmp(p, "prot") == 0)
        carthw_sprot_startup();
      else if (strcmp(p, "ssf2_mapper") == 0)
        carthw_ssf2_startup();
      else if (strcmp(p, "x_in_1_mapper") == 0)
        carthw_Xin1_startup();
      else if (strcmp(p, "realtec_mapper") == 0)
        carthw_realtec_startup();
      else if (strcmp(p, "radica_mapper") == 0)
        carthw_radica_startup();
      else if (strcmp(p, "piersolar_mapper") == 0)
        carthw_pier_startup();
      else if (strcmp(p, "prot_lk3") == 0)
        carthw_prot_lk3_startup();
      else {
        elprintf(EL_STATUS, "carthw:%d: unsupported mapper: %s", line, p);
        skip_sect = 1;
        *hw_detected = 0;
      }
      continue;
    }
    if (is_expr("sram_range", &p)) {
      int start, end;

      if (!any_checks_passed)
        goto no_checks;
      rstrip(p);

      start = strtoul(p, &r, 0);
      if (r == p)
        goto bad;
      p = sskip(r);
      if (*p != ',')
        goto bad;
      p = sskip(p + 1);
      end = strtoul(p, &r, 0);
      if (r == p)
        goto bad;
      if (((start | end) & 0xff000000) || start > end) {
        elprintf(EL_STATUS, "carthw:%d: bad sram_range: %08x - %08x", line, start, end);
        goto bad_nomsg;
      }
      Pico.sv.start = start;
      Pico.sv.end = end;
      continue;
    }
    else if (is_expr("prop", &p)) {
      if (!any_checks_passed)
        goto no_checks;
      rstrip(p);

      if      (strcmp(p, "no_sram") == 0)
        Pico.sv.flags &= ~SRF_ENABLED;
      else if (strcmp(p, "no_eeprom") == 0)
        Pico.sv.flags &= ~SRF_EEPROM;
      else if (strcmp(p, "filled_sram") == 0)
        *fill_sram = 1;
      else if (strcmp(p, "force_6btn") == 0)
        PicoIn.quirks |= PQUIRK_FORCE_6BTN;
      else {
        elprintf(EL_STATUS, "carthw:%d: unsupported prop: %s", line, p);
        goto bad_nomsg;
      }
      elprintf(EL_STATUS, "game prop: %s", p);
      continue;
    }
    else if (is_expr("eeprom_type", &p)) {
      int type;
      if (!any_checks_passed)
        goto no_checks;
      rstrip(p);

      type = strtoul(p, &r, 0);
      if (r == p || type < 0)
        goto bad;
      Pico.sv.eeprom_type = type;
      Pico.sv.flags |= SRF_EEPROM;
      continue;
    }
    else if (is_expr("eeprom_lines", &p)) {
      int scl, sda_in, sda_out;
      if (!any_checks_passed)
        goto no_checks;
      rstrip(p);

      if (!parse_3_vals(p, &scl, &sda_in, &sda_out))
        goto bad;
      if (scl < 0 || scl > 15 || sda_in < 0 || sda_in > 15 ||
          sda_out < 0 || sda_out > 15)
        goto bad;

      Pico.sv.eeprom_bit_cl = scl;
      Pico.sv.eeprom_bit_in = sda_in;
      Pico.sv.eeprom_bit_out= sda_out;
      continue;
    }
    else if ((tmp = is_expr("prot_ro_value16", &p)) || is_expr("prot_rw_value16", &p)) {
      int addr, mask, val;
      if (!any_checks_passed)
        goto no_checks;
      rstrip(p);

      if (!parse_3_vals(p, &addr, &mask, &val))
        goto bad;

      carthw_sprot_new_location(addr, mask, val, tmp ? 1 : 0);
      continue;
    }


bad:
    elprintf(EL_STATUS, "carthw:%d: unrecognized expression: %s", line, buff);
bad_nomsg:
    skip_sect = 1;
    continue;

no_checks:
    elprintf(EL_STATUS, "carthw:%d: command without any checks before it: %s", line, buff);
    skip_sect = 1;
    continue;
  }

  if (f != NULL)
    fclose(f);
}

/*
 * various cart-specific things, which can't be handled by generic code
 */
static void PicoCartDetect(const char *carthw_cfg)
{
  int carthw_detected = 0;
  int fill_sram = 0;

  memset(&Pico.sv, 0, sizeof(Pico.sv));
  if (Pico.rom[0x1B1] == 'R' && Pico.rom[0x1B0] == 'A')
  {
    Pico.sv.start =  rom_read32(0x1B4) & ~0xff000001; // align
    Pico.sv.end   = (rom_read32(0x1B8) & ~0xff000000) | 1;
    if (Pico.rom[0x1B2] & 0x40)
      // EEPROM
      Pico.sv.flags |= SRF_EEPROM;
    Pico.sv.flags |= SRF_ENABLED;
  }
  if (Pico.sv.end == 0 || Pico.sv.start > Pico.sv.end)
  {
    // some games may have bad headers, like S&K and Sonic3
    // note: majority games use 0x200000 as starting address, but there are some which
    // use something else (0x300000 by HardBall '95). Luckily they have good headers.
    Pico.sv.start = 0x200000;
    Pico.sv.end   = 0x203FFF;
    Pico.sv.flags |= SRF_ENABLED;
  }

  // set EEPROM defaults, in case it gets detected
  Pico.sv.eeprom_type   = 0; // 7bit (24C01)
  Pico.sv.eeprom_bit_cl = 1;
  Pico.sv.eeprom_bit_in = 0;
  Pico.sv.eeprom_bit_out= 0;

  if (carthw_cfg != NULL)
    parse_carthw(carthw_cfg, &fill_sram, &carthw_detected);

  // assume the standard mapper for large roms
  if (!carthw_detected && Pico.romsize > 0x400000)
    carthw_ssf2_startup();

  if (Pico.sv.flags & SRF_ENABLED)
  {
    if (Pico.sv.flags & SRF_EEPROM)
      Pico.sv.size = 0x2000;
    else
      Pico.sv.size = Pico.sv.end - Pico.sv.start + 1;

    Pico.sv.data = calloc(Pico.sv.size, 1);
    if (Pico.sv.data == NULL)
      Pico.sv.flags &= ~SRF_ENABLED;

    if (Pico.sv.eeprom_type == 1)	// 1 == 0 in PD EEPROM code
      Pico.sv.eeprom_type = 0;
  }

  if ((Pico.sv.flags & SRF_ENABLED) && fill_sram)
  {
    elprintf(EL_STATUS, "SRAM fill");
    memset(Pico.sv.data, 0xff, Pico.sv.size);
  }

  // Unusual region 'code'
  if (rom_strcmp(0x1f0, "EUROPE") == 0 || rom_strcmp(0x1f0, "Europe") == 0)
    *(int *) (Pico.rom + 0x1f0) = 0x20204520;
}

// vim:shiftwidth=2:expandtab
