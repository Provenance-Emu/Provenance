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

#include <trio/trio.h>

#include "png.h"

static unsigned GetIncSnapIndex(void)
{
 FileStream pp(MDFN_MakeFName(MDFNMKF_SNAP_DAT, 0, NULL), FileStream::MODE_READ_WRITE, true);
 std::string linebuf;
 unsigned ret = 0;

 if(pp.get_line(linebuf) >= 0)
  if(trio_sscanf(linebuf.c_str(), "%u", &ret) != 1)
   ret = 0;

 pp.rewind();
 pp.print_format("%u\n", ret + 1);
 pp.truncate(pp.tell());
 pp.close();

 return ret;
}

void MDFNI_SaveSnapshot(const MDFN_Surface *src, const MDFN_Rect *rect, const int32 *LineWidths)
{
 try
 {
  const unsigned u = GetIncSnapIndex();

  PNGWrite(MDFN_MakeFName(MDFNMKF_SNAP, u, "png"), src, *rect, LineWidths);

  MDFN_Notify(MDFN_NOTICE_STATUS, _("Screen snapshot %u saved."), u);
 }
 catch(std::exception &e)
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, _("Error saving screen snapshot: %s"), e.what());
 }
}
