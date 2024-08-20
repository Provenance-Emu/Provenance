/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* 4way.h:
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

class MD_4Way;

class MD_4Way_Shim final : public MD_Input_Device
{
	public:
	MD_4Way_Shim(unsigned nin, MD_4Way* p4w);
	virtual ~MD_4Way_Shim() override;
	virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix) override;
	virtual void Power(void) override;
	virtual void BeginTimePeriod(const int32 timestamp_base) override;
	virtual void EndTimePeriod(const int32 master_timestamp) override;
	virtual void UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted) override;

	private:
	unsigned n;
	MD_4Way* parent;
};

class MD_4Way
{
        public:
        MD_4Way();
        ~MD_4Way();

	void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix);
	void Power(void);
        void BeginTimePeriod(const int32 timestamp_base);
        void EndTimePeriod(const int32 master_timestamp);

	INLINE MD_Input_Device* GetShim(unsigned n) { return &Shams[n]; }

	void UpdateBus(unsigned n, const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted);
	void SetSubPort(unsigned n, MD_Input_Device* d);

	private:
	MD_Input_Device* SubPort[4] = { nullptr, nullptr, nullptr, nullptr };
	MD_4Way_Shim Shams[2] = { { 0, this}, {1, this } };
	uint8 index;
};

}
