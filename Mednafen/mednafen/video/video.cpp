/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "video-common.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdarg.h>

#include <trio/trio.h>

#include <vector>

#include "png.h"

void MDFNI_SaveSnapshot(const MDFN_Surface *src, const MDFN_Rect *rect, const int32 *LineWidths)
{
 try
 {
  unsigned u = 0;

  try
  {
   FileStream pp(MDFN_MakeFName(MDFNMKF_SNAP_DAT, 0, NULL), FileStream::MODE_READ);
   std::string linebuf;

   if(pp.get_line(linebuf) >= 0)
    if(trio_sscanf(linebuf.c_str(), "%u", &u) != 1)
     u = 0;
  }
  catch(std::exception &e)
  {

  }

  {
   FileStream pp(MDFN_MakeFName(MDFNMKF_SNAP_DAT, 0, NULL), FileStream::MODE_WRITE);

   pp.print_format("%u\n", u + 1);
  }

  std::string fn = MDFN_MakeFName(MDFNMKF_SNAP, u, "png");

  PNGWrite(fn, src, *rect, LineWidths);

  MDFN_DispMessage(_("Screen snapshot %u saved."), u);
 }
 catch(std::exception &e)
 {
  MDFN_PrintError(_("Error saving screen snapshot: %s"), e.what());
  MDFN_DispMessage(_("Error saving screen snapshot: %s"), e.what());
 }
}

void MDFN_DispMessage(const char *format, ...) noexcept
{
 va_list ap;
 va_start(ap,format);
 char *msg = NULL;

 trio_vasprintf(&msg, format,ap);
 va_end(ap);

 MDFND_DispMessage(msg);
}

void MDFN_ResetMessages(void)
{
 MDFND_DispMessage(NULL);
}


