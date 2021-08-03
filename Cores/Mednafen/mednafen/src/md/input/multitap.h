/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* multitap.h:
**  Copyright (C) 2014-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

namespace MDFN_IEN_MD
{

class MD_Multitap final : public MD_Input_Device
{
        public:
        MD_Multitap();
        virtual ~MD_Multitap() override;
	virtual void UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted) override;
	virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix) override;
	virtual void Power(void) override;
        virtual void BeginTimePeriod(const int32 timestamp_base) override;
        virtual void EndTimePeriod(const int32 master_timestamp) override;

	void SetSubPort(unsigned n, MD_Input_Device* d);

	private:
	MD_Input_Device* SubPort[4] = { nullptr, nullptr, nullptr, nullptr };

	unsigned phase;
	bool prev_th, prev_tr;

	uint8 bb[4][5];
	uint64 data_out;
	unsigned data_out_offs;
	uint8 nyb;
};

}
