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

namespace MDFN_IEN_WSWAN
{

void Comm_Init(const char *wfence_path);
void Comm_Kill(void);
void Comm_Reset(void);
void Comm_StateAction(StateMem *sm, const unsigned load, const bool data_only);

void Comm_Process(void);
uint8 Comm_Read(uint8 A);
void Comm_Write(uint8 A, uint8 V);

}
