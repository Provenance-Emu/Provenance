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

#include <mednafen/mednafen.h>
#include <mednafen/memory.h>

#include "IPSPatcher.h"

uint32 IPSPatcher::Apply(Stream* ips, Stream* targ)
{
 std::unique_ptr<uint8[]> tmpbuf(new uint8[65536]);
 uint8 file_header[5];
 uint32 count = 0;
 
 if(ips->read(file_header, 5, false) < 5 || memcmp(file_header, "PATCH", 5))
  throw MDFN_Error(0, _("IPS file header is invalid."));

 for(;;)
 {
  uint8 header[3];
  uint32 offset;
  uint32 patch_size;	// Max value: 65536
  bool rle = false;

  ips->read(header, 3);
  offset = MDFN_de24msb(&header[0]);

  if(offset == 0x454f46)	// EOF
   return(count);

  patch_size = ips->get_BE<uint16>();

  if(!patch_size)	/* RLE */
  {
   patch_size = ips->get_BE<uint16>();

   // Is this right?
   if(!patch_size)
    patch_size = 65536;

   rle = true;
   //MDFN_printf(_("Offset: %8u  Size: %5u RLE\n"), offset, patch_size);
  }

  targ->seek(offset, SEEK_SET);

  if(rle)	// RLE patch.
  {
   const uint8 b = ips->get_u8();

   memset(&tmpbuf[0], b, patch_size);
   targ->write(&tmpbuf[0], patch_size);
  }
  else		// Normal patch
  {
   //MDFN_printf(_("Offset: %8u  Size: %5u\n"), offset, patch_size);
   ips->read(&tmpbuf[0], patch_size);
   targ->write(&tmpbuf[0], patch_size);
  }
  count++;
 }
}
