/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* disk2.inc:
**  Copyright (C) 2018-2020 Mednafen Team
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

//#define MDFN_APPLE2_DISK2SEQ_HLE 1

/*
 Avoid seeking when loading disk images, since they may be stored compressed in a ZIP file, and seeking will be slow.

 An earlier implementation used 1431818 1-bit samples per track representing idealized magnetic flux,
 but this posed practical usability issues due to memory usage, and probably needed something like 4-bit samples to handle flux properly in the case of WOZ
 images with odd track data parity, which would have made these issues even worse...

 TODO:
	Fix track stepping speeds.

	Make FloppyDisk opaque to outside code.
*/

namespace Disk2
{

enum : unsigned { num_tracks = 160 };
//enum : unsigned { samples_per_track = 1431818 };
enum : unsigned { min_bits_per_track = 46000 };
enum : unsigned { max_bits_per_track = 56048 };

static uint8 BootROM[256];
static uint8 SequencerROM[256];

static uint8 Latch_Stepper;
static bool Latch_MotorOn;	// Q4
static bool Latch_DriveSelect;	// Q5
static unsigned Latch_Mode;	// Q6 and Q7, stored in bits 4 and 5 of Latch_Mode

static uint32 lcg_state;

static unsigned motoroff_delay_counter;
static uint8 data_reg;
static unsigned sequence;

static int16 StepperLUT[16][128];

#if defined(MDFN_APPLE2_DISK2SEQ_HLE)
static struct
{
 uint32 fc_counter;

 uint32 pending_bits;
 uint32 pending_bits_count;
 uint32 qa_delay;
} SeqHLE;
#endif

struct FloppyDisk
{
 bool write_protect = false;

 struct Track
 {
  SimpleBitset<65536> data;
  uint32 length = 51024;
  bool flux_fudge = false;
 } tracks[num_tracks];

 uint32 angle = 0;	// when disk is inserted into a drive, >>3 for index into tracks[track].data; otherwise, full 32-bit representation of angle
 bool dirty = false;	// Disk has been modified(change of write protect, or track data) since last save.
 bool ever_modified = false;	// Disk has ever been modified(as compared to source disk image).
};

static FloppyDisk DummyDisk; 	// TODO: Check disk absence write protect signal
static FloppyDisk StateHelperDisk;

static struct FloppyDrive
{
 FloppyDisk* inserted_disk;
 uint64 m_history;

 uint8 delay_flux_change;

 // stepper_position:
 //  0x00800000 = Internal track 0, Apple II track 0.000, stepper angle   0
 //  0x00FFFFFF = Internal track 0, Apple II track 0.124999... ;)
 //
 //  0x01000000 = Internal track 1, Apple II track 0.125
 //  0x01800000 = Internal track 1, Apple II track 0.250, stepper angle  45
 //  0x01FFFFFF = Internal track 1
 //
 //  0x02000000 = Internal track 2, Apple II track 0.375
 //  0x02800000 = Internal track 2, Apple II track 0.500, stepper angle  90
 //  0x02FFFFFF = Internal track 2
 //
 //  0x03800000 = Internal track 3, Apple II track 0.625
 //  0x03800000 = Internal track 3, Apple II track 0.750, stepper angle 135
 //  0x03FFFFFF = Internal track 3
 //
 //
 //  0x04800000 = Internal track 4, Apple II track 1.000, stepper angle 180
 //
 //
 //
 //  0x05800000 = Internal track 5, Apple II track 1.250, stepper angle 225
 //
 //
 //
 //  0x06800000 = Internal track 6, Apple II track 1.500, stepper angle 270
 //
 //
 //
 //  0x07800000 = Internal track 7, Apple II track 1.750, stepper angle 315
 //
 //
 //
 //  0x08800000 = Internal track 8, Apple II track 2.000, stepper angle   0
 //
 // Clamp to: [0x00800000, ((num_tracks - 1) << 24) | 0x00800000]
 //
 uint32 stepper_position;
 //uint32 motor_speed;
} Drives[2];

static INLINE void ClampStepperPosition(FloppyDrive* drive)
{
 if(MDFN_UNLIKELY(drive->stepper_position < 0x00800000))
  drive->stepper_position = 0x00800000;

 if(MDFN_UNLIKELY(drive->stepper_position > (((num_tracks - 1) << 24) | 0x00800000)))
  drive->stepper_position = ((num_tracks - 1) << 24) | 0x00800000;
}

static NO_INLINE void Tick2M(void)
{
 unsigned flux_change = 0x40;	// 0x40 = no flux change, 0x00 = flux change
 FloppyDrive* drive = &Drives[Latch_DriveSelect];
 FloppyDisk* disk = drive->inserted_disk;
 const bool write_mode = !disk->write_protect && !(Latch_Stepper & 0x2) && (Latch_Mode & 0x20);
 //
 lcg_state = lcg_state * 1103515245 + 12345;

 if(Latch_MotorOn)
  motoroff_delay_counter = 2040968;	// FIXME: exact(ish) time?

 if(motoroff_delay_counter)
 {
  const size_t tri = drive->stepper_position >> 24;
  FloppyDisk::Track* tr = &disk->tracks[tri];
  const size_t td_index = disk->angle >> 3;

  if(write_mode)
  {
   const bool m = (bool)(sequence & 0x08);

   //printf("Bit written: %d\n", m);
   //printf("%08x %02x %d\n", drive->m_history, data_reg, m);

   if(MDFN_LIKELY(disk != &DummyDisk))
   {
    if(tri > 0)
     disk->tracks[tri - 1].data.set(td_index, m);
    tr->data.set(td_index, m);
    if(tri < (num_tracks - 1))
     disk->tracks[tri + 1].data.set(td_index, m);

    disk->dirty = true;
    disk->ever_modified = true;
   }

   drive->m_history <<= 1;
   drive->m_history |= m;
  }
  else
  {
   const bool m = tr->data[td_index];
   bool mchange;

   drive->m_history <<= 1;
   drive->m_history |= m;

   mchange = (drive->m_history ^ (drive->m_history >> 1)) & 1;

   if(MDFN_UNLIKELY((drive->m_history & 0xFFFFFFFFFFFFFULL) == 0 || ((~drive->m_history) & 0xFFFFFFFFFFFFFULL) == 0))
   {
    mchange = !((lcg_state >> 28) & 0xF);
    //printf("MWA: %zu %d\n", tri, mchange);
   }

   flux_change &= drive->delay_flux_change;
   drive->delay_flux_change = 0xFF;

   if(mchange)
   {
    if(lcg_state & 0x40000000)
     drive->delay_flux_change = 0;
    else
     flux_change = 0;
   }
  }

  //
  //
  //
  disk->angle++;
  if(MDFN_UNLIKELY(disk->angle >= (tr->length << 3)))
  {
   if(MDFN_UNLIKELY(disk->angle > (tr->length << 3)))
   {
    // Expected to happen if a bad save state is loaded, but shouldn't happen otherwise.
    APPLE2_DBG(APPLE2_DBG_ERROR, "[ERROR] disk->angle > (tr->length << 3)\n");
   }
   //
   disk->angle = 0;

   // Baaaah
   if(tr->flux_fudge)
   {
    if(write_mode)
    {
     //printf("HiWr: %zu %d %016llx\n", tri, disk->angle, (unsigned long long)drive->m_history);
     tr->flux_fudge = false;
    }
    else
    {
     //printf("Hi: %zu %d %016llx\n", tri, disk->angle, (unsigned long long)drive->m_history);
     drive->m_history = ~drive->m_history;
    }
   }
  }
  //
  // TODO: Output GRGRGRKRGKRGRKGRKRG sound. ;)
  //
  {
   const unsigned old_track = drive->stepper_position >> 24;
   unsigned new_track;
   //
   drive->stepper_position += StepperLUT[Latch_Stepper][(drive->stepper_position >> 20) & 0x7F];
   ClampStepperPosition(drive);
   //
   new_track = drive->stepper_position >> 24;
   if(old_track != new_track)
   {
    APPLE2_DBG(APPLE2_DBG_DISK2, "[DISK2] Disk II virtual track changed: %08x\n", drive->stepper_position);
    disk->angle = (uint64)disk->angle * disk->tracks[new_track].length / disk->tracks[old_track].length;
   }
  }
 }

 if(motoroff_delay_counter)
 {
#if defined(MDFN_APPLE2_DISK2SEQ_HLE)
  /*
   Refer to:
     Understanding the Apple IIe

       Figure 9.14, page 9-24
       Figure 9.16, page 9-31
  */
  const bool fc_occurred = !flux_change;

  if(Latch_Mode & 0x30)
  {
   //printf("%02x\n", Latch_Mode);
   SeqHLE.fc_counter = 0;
   SeqHLE.qa_delay = 0;
   SeqHLE.pending_bits = 0;
   SeqHLE.pending_bits_count = 0;
  }

  switch(Latch_Mode & 0x30)
  {
   // Read
   case 0x00:
	if(fc_occurred && SeqHLE.fc_counter >= 4 && SeqHLE.fc_counter <= 11)
	{
	 SeqHLE.pending_bits |= 1 << SeqHLE.pending_bits_count;
	 SeqHLE.pending_bits_count += 1;
	 SeqHLE.fc_counter = 0;
	}
	else if(SeqHLE.fc_counter >= 12)
	{
	 SeqHLE.pending_bits_count += 1;
	 SeqHLE.fc_counter -= 8;
	}
	else
	{
	 if((data_reg & 0x80) && !SeqHLE.qa_delay)
	  SeqHLE.qa_delay = 16; //moomoo; //20;
	 else if(SeqHLE.qa_delay > 1)
	  SeqHLE.qa_delay--;
	 else if(SeqHLE.pending_bits_count)
	 {
	  if(SeqHLE.qa_delay && (SeqHLE.pending_bits & 1))
	  {
	   //if((drive->stepper_position >> 24) == 0x6C)
	   // printf("QA Delay finish: %02x, %d --- %08x\n", data_reg, pending_bits, drive->stepper_position >> 24);
	   data_reg = 0x00;
	   SeqHLE.qa_delay = 0;
	  }
	  else
	  {
	   if(!SeqHLE.qa_delay)
	    data_reg = (data_reg << 1) | (SeqHLE.pending_bits & 1);

	   SeqHLE.pending_bits >>= 1;
	   SeqHLE.pending_bits_count--;
	  }
	 }

	 SeqHLE.fc_counter++;
	}
	break;

   // Check write protect
   case 0x10:
	data_reg = (data_reg >> 1) | (disk->write_protect << 7);
	sequence = 0;
	break;

   // Write, data register shift every 8 2M cycles
   case 0x20:
	if((sequence & 0x7) == 0x2)
	{
	 data_reg = data_reg << 1;
	 //printf("Data Reg Shift, ->0x%02x\n", data_reg);
	}

	sequence = ((sequence + 1) & 0x7) | (sequence & 0x8);
	if(!(sequence & 0x7))
	 sequence ^= ((data_reg >> 4) & 0x8);
	break;

   // Write, data register load every 8 2M cycles.
   case 0x30:
	if((sequence & 0x7) == 0x2)
	{
	 data_reg = DB;
	 //printf("Data Reg Load, 0x%02x\n", data_reg);
	}

	sequence = ((sequence + 1) & 0x7) | (sequence & 0x8);
	if(!(sequence & 0x7))
	 sequence ^= ((data_reg >> 4) & 0x8);
	break;
  }
#else
  const uint8 srb = SequencerROM[(data_reg & 0x80) | flux_change | Latch_Mode | sequence];

  //if(!Latch_Mode)
  // printf("QA: %d, flux_change: %d, %02x:%02x\n", (bool)(data_reg & 0x80), flux_change, sridx, srb);

  switch(srb & 0xF)
  {
   case 0x0: case 0x1: case 0x2: case 0x3: case 0x4: case 0x5: case 0x6: case 0x7:
	data_reg = 0;
	break;

   case 0x8:
   case 0xC:
	break;

   case 0x9:
	data_reg = (data_reg << 1);
	break;

   case 0xA:
   case 0xE:
	data_reg = (data_reg >> 1) | (disk->write_protect << 7);
	break;

   case 0xB:
   case 0xF:
	//printf("data_reg=DB=%02x @ %u\n", DB, timestamp);
	data_reg = DB;
	break;

   case 0xD:
	data_reg = (data_reg << 1) | 1;
	break;
  }

  sequence = srb >> 4;
#endif
  //
  motoroff_delay_counter--;
 }
}

static INLINE void EndTimePeriod(void)
{
 //printf("%d %d\n", lastts, timestamp);
 // lastts -= timestamp;
}

void Power(void)
{
 Latch_Stepper = 0x00;
 Latch_MotorOn = false;
 Latch_DriveSelect = false;
 Latch_Mode = 0x00;

 motoroff_delay_counter = 0;
 data_reg = 0x00;
 sequence = 0x00;

#if defined(MDFN_APPLE2_DISK2SEQ_HLE)
 SeqHLE.fc_counter = 0;
 SeqHLE.pending_bits = 0;
 SeqHLE.pending_bits_count = 0;
 SeqHLE.qa_delay = 0;
#endif

 for(unsigned drive_index = 0; drive_index < 2; drive_index++)
 {
  FloppyDrive* drive = &Drives[drive_index];

  drive->m_history = 0;
 }
}

/*
 Beneath DOS, 6-1:

 6502 read or write:

 C080: Stepper motor phase 0 off
 C081: Stepper motor phase 1 on
 [...]
 C086: Stepper motor phase 3 off
 C087: Stepper motor phase 3 on
 C088: Motor off
 C089: Motor on
 C08A: Engage drive A
 C08B: Engage drive B

 C08C: Strobe data latch
 C08D: Load data latch

 C08E: Prepare latch for input
 C08F: Prepare latch for output
*/

template<unsigned TA>
static DEFRW(RW)
{
 //if(TA == 0xD || TA == 0xF)
 // printf("Write: %02x: %02x\n", TA, DB);

 if(!InHLPeek)
 {
  switch(TA)
  {
   // Stepper phases off/on control
   case 0x0: case 0x1: case 0x2: case 0x3: case 0x4: case 0x5: case 0x6: case 0x7:
	Latch_Stepper &=     ~(1U << ((TA & 0x7) >> 1));
	Latch_Stepper |= (TA & 1) << ((TA & 0x7) >> 1);
	//printf("Stepper: %02x, %02x, %08x @ %u\n", TA, Latch_Stepper, Drives[0].stepper_position, timestamp);
	break;

   // Motor off/on control
   case 0x8: Latch_MotorOn = false; break;
   case 0x9: Latch_MotorOn = true; break;

   // Drive select
   case 0xA: Latch_DriveSelect = false; break;
   case 0xB: Latch_DriveSelect = true; break;

   // Q6
   case 0xC: Latch_Mode &= ~0x10; break;
   case 0xD: Latch_Mode |=  0x10; break;

   // Q7
   case 0xE: Latch_Mode &= ~0x20; break;
   case 0xF: Latch_Mode |=  0x20; break;
  }
  //
  CPUTick1();
 }
 //
 if(!(TA & 1))
 {
  DB = data_reg;

  //if((data_reg & 0x80) && ((Drives[Latch_DriveSelect].stepper_position) >> 24) == 0x6C)
  // printf("Yeah: 0x%02x\n", data_reg); // --- %d, %08x\n", data_reg, timestamp, Drives[Latch_DriveSelect].stepper_position, data_reg);
 }
}

static DEFREAD(ReadBootROM)
{
 DB = BootROM[(uint8)A];
 //
 if(!InHLPeek)
  CPUTick1();
}

class apple2_track_encoder
{
 public:

 apple2_track_encoder(FloppyDisk::Track* tr_, int src_num_bits = 51024) : tr(tr_), angle(0), cur_mflux(false)
 {
  assert((unsigned)src_num_bits >= min_bits_per_track);
  assert((unsigned)src_num_bits <= max_bits_per_track);
  tr->length = src_num_bits;
 }

 ~apple2_track_encoder()
 {
  assert(!tr);
 }

 INLINE void finish(void)
 {
  //printf("track end angle: %u\n", angle);

  assert(tr);
  assert(!angle);

  tr->flux_fudge = cur_mflux;
  cur_mflux = false;
  tr = nullptr;
 }

 void encode_bit(bool b);

 void encode_byte(uint8 v);
 void encode_oddeven(uint8 v);

 //void encode_dos32_selfsync(void);
 //void encode_dos32_sector(void);

 template<bool dos33> void encode_selfsync(void);
 template<bool dos33> void encode_gap1(unsigned count);
 template<bool dos33> void encode_address_field(const uint8 volnum, const uint8 tracknum, const uint8 secnum);
 template<bool dos33> void encode_data_field(const uint8* user_data);
 template<bool dos33> void encode_sector(const uint8 volnum, const uint8 tracknum, const uint8 secnum, const uint8* user_data);

 void encode_user_data_53(const uint8* user_data);
 void encode_user_data_62(const uint8* user_data);

 private:
 FloppyDisk::Track* tr;
 unsigned angle;
 bool cur_mflux;
};

void apple2_track_encoder::encode_bit(bool b)
{
 if(b)
  cur_mflux = !cur_mflux;

 tr->data.set(angle, cur_mflux);
 angle++;
 if(MDFN_UNLIKELY(angle == tr->length))
  angle = 0;
}

void apple2_track_encoder::encode_byte(uint8 v)
{
 for(int i = 7; i >= 0; i--)
  encode_bit((v >> i) & 1);
}

template<bool dos33>
void apple2_track_encoder::encode_selfsync(void)
{
 for(unsigned i = 0; i < (dos33 ? 10 : 9); i++)
  encode_bit(i < 8);
}

void apple2_track_encoder::encode_user_data_53(const uint8* ud)
{
 static const uint8 tab[0x20] =
 {
  0xAB, 0xAD, 0xAE, 0xAF, 0xB5, 0xB6, 0xB7, 0xBA, 0xBB, 0xBD, 0xBE, 0xBF, 0xD6, 0xD7, 0xDA, 0xDB,
  0xDD, 0xDE, 0xDF, 0xEA, 0xEB, 0xED, 0xEE, 0xEF, 0xF5, 0xF6, 0xF7, 0xFA, 0xFB, 0xFD, 0xFE, 0xFF
 };
 uint8 buf[410];

 // Encode 256 bytes using 5-and-3 coding
 for(unsigned group = 0; group < 0x33; group++)
 {
  buf[0x0CC - group/*0x0CC ... 0x09A*/] = ud[group * 5 + 0] >> 3;
  buf[0x0FF - group/*0x0FF ... 0x0CD*/] = ud[group * 5 + 1] >> 3;
  buf[0x132 - group/*0x132 ... 0x100*/] = ud[group * 5 + 2] >> 3;
  buf[0x165 - group/*0x165 ... 0x133*/] = ud[group * 5 + 3] >> 3;
  buf[0x198 - group/*0x198 ... 0x166*/] = ud[group * 5 + 4] >> 3;

  buf[0x67 + group] = ((ud[group * 5 + 0] & 0x7) << 2) | ((ud[group * 5 + 3] & 0x04) >> 1) | ((ud[group * 5 + 4] & 0x04) >> 2);
  buf[0x34 + group] = ((ud[group * 5 + 1] & 0x7) << 2) | ((ud[group * 5 + 3] & 0x02) >> 0) | ((ud[group * 5 + 4] & 0x02) >> 1);
  buf[0x01 + group] = ((ud[group * 5 + 2] & 0x7) << 2) | ((ud[group * 5 + 3] & 0x01) << 1) | ((ud[group * 5 + 4] & 0x01) >> 0);

  //  ud[group * 5 + 3] |= ((tbuf[0x67 + group] & 0x2) << 1) | ((tbuf[0x34 + group] & 0x2) << 0) | ((tbuf[0x01 + group] & 0x2) >> 1);
  //  ud[group * 5 + 4] |= ((tbuf[0x67 + group] & 0x1) << 2) | ((tbuf[0x34 + group] & 0x1) << 1) | ((tbuf[0x01 + group] & 0x1) << 0);
 }
 buf[0x000] = ud[0xFF] & 0x7;
 buf[0x199] = ud[0xFF] >> 3;

 uint8 prev = 0;
 for(unsigned i = 0; i < 410; i++)
 {
  encode_byte(tab[prev ^ buf[i]]);
  prev = buf[i];
 }
 encode_byte(tab[prev]);
}

void apple2_track_encoder::encode_user_data_62(const uint8* user_data)
{
 static const uint8 tab[0x40] =
 {
  0x96, 0x97, 0x9a, 0x9b, 0x9d, 0x9e, 0x9f, 0xa6, 0xa7, 0xab, 0xac, 0xad, 0xae, 0xaf, 0xb2, 0xb3, 
  0xb4, 0xb5, 0xb6, 0xb7, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbe, 0xbf, 0xcb, 0xcd, 0xce, 0xcf, 0xd3, 
  0xd6, 0xd7, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde, 0xdf, 0xe5, 0xe6, 0xe7, 0xe9, 0xea, 0xeb, 0xec, 
  0xed, 0xee, 0xef, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff
 };
 uint8 buf[342] = { 0 };

 // Encode 256 bytes to 86+256+1 bytes using 6-and-2 coding
 for(unsigned i = 0; i < 256; i++)
 {
  unsigned lb;

  lb = user_data[i] & 0x3;
  lb = ((lb << 1) | (lb >> 1)) & 0x3;

  buf[i % 86] |= lb << ((i / 86) * 2);
  buf[86 + i] = user_data[i] >> 2;
 }

 uint8 prev = 0;
 for(unsigned i = 0; i < 342; i++)
 {
  encode_byte(tab[prev ^ buf[i]]);
  prev = buf[i];
 }
 encode_byte(tab[prev]);
}

void apple2_track_encoder::encode_oddeven(uint8 v)
{
 encode_byte(0xAA | ((v >> 1) & 0x55));
 encode_byte(0xAA | ((v >> 0) & 0x55));
}

template<bool dos33>
void apple2_track_encoder::encode_gap1(unsigned count)
{
 while(count--)
  encode_selfsync<dos33>();

 //printf("gap1 end angle: %u\n", angle);
}

template<bool dos33>
void apple2_track_encoder::encode_address_field(const uint8 volnum, const uint8 tracknum, const uint8 secnum)
{
 // Prologue
 encode_byte(0xFF); // DOS 3.3, check DOS 3.2.
 encode_byte(0xD5);
 encode_byte(0xAA);
 encode_byte(dos33 ? 0x96 : 0xB5);

 // Volume
 encode_oddeven(volnum);

 // Track
 encode_oddeven(tracknum);

 // Sector
 encode_oddeven(secnum);

 // Checksum
 encode_oddeven(volnum ^ tracknum ^ secnum);

 // Epilogue
 encode_byte(0xDE);
 encode_byte(0xAA);
 encode_byte(0xEB);	// DOS 3.3 doesn't seem to correctly write lower bits...
}

template<bool dos33>
void apple2_track_encoder::encode_data_field(const uint8* user_data)
 // Prologue
{
 encode_byte(0xD5);
 encode_byte(0xAA);
 encode_byte(0xAD);

 // DOS 3.3, check DOS 3.2.
 if(dos33)
  encode_bit(0);

 // User data
 if(dos33)
  encode_user_data_62(user_data);
 else
  encode_user_data_53(user_data);

 // Epilogue
 encode_byte(0xDE);
 encode_byte(0xAA);
 encode_byte(0xEB);
}

template<bool dos33>
void apple2_track_encoder::encode_sector(const uint8 volnum, const uint8 tracknum, const uint8 secnum, const uint8* user_data)
{
 if(dos33)
 {
  encode_address_field<true>(volnum, tracknum, secnum);

  // Gap 2
  for(unsigned i = 0; i < 6; i++)
   encode_selfsync<true>();

  encode_byte(0xFF);
  encode_bit(0);

  encode_data_field<true>(user_data);

  // Gap 3
  for(unsigned i = 0; i < 18; i++)
   encode_selfsync<dos33>();
 }
 else
 {
  encode_address_field<false>(volnum, tracknum, secnum);

  // Gap 2
  for(unsigned i = 0; i < 14; i++)
   encode_selfsync<false>();

  encode_data_field<false>(user_data);

  // Gap 3
  for(unsigned i = 0; i < 28; i++)
   encode_selfsync<dos33>();
 }
}

/*
 Patent:
 Address lines(60-67):
 A0: Latch bit(C08C, C08D)
 A1: Latch bit(C08E, C08F)
 A2: edge detector(flux change?)
 A3: serial output from register 40
 A4:
 A5:
 A6:
 A7:
*/

void SetSeqROM(const uint8* src)
{
 //
 // Rearrange address bits to be a bit more efficient.
 //
 // A0...A3 should be sequence
 // A4 and A5 should be C08C,C08D and C08E,C08F latch bits
 // A6 should be active-low flux change pulse
 // A7 should be D7 of the shift/data register
 //
 for(unsigned A = 0; A < 256; A++)
 {
  const unsigned seq = A & 0x0F;
  const unsigned lm = (A >> 4) & 0x3;
  const bool fc = (A >> 6) & 0x1;
  const bool dr7 = (A >> 7) & 1;

/*
  const bool A0 = (sequence & 0x20);
  const bool A1 = (data_reg & 0x80);
  const bool A2 = (Latch_Mode & 0x01);
  const bool A3 = (Latch_Mode & 0x02);
  const bool A4 = !flux_change;
  const bool A5 = (sequence & 0x10);
  const bool A6 = (sequence & 0x40);
  const bool A7 = (sequence & 0x80);
  const size_t sridx = (A0 << 0) | (A1 << 1) | (A2 << 2) | (A3 << 3) | (A4 << 4) | (A5 << 5) | (A6 << 6) | (A7 << 7); //(Latch_Mode << 2) | (!flux_change << 4) | ((data_reg & 0x80) >> 6) | ((sequence & 0x10) << 1) | ((sequence & 0x20) >> 5) | (sequence & 0xC0);
*/

  SequencerROM[A] = src[((bool)(seq & 0x2) << 0) | (dr7 << 1) | (lm << 2) | (fc << 4) | ((bool)(seq & 0x1) << 5) | ((bool)(seq & 0x4) << 6) | ((bool)(seq & 0x8) << 7)];
 }
}

void SetBootROM(const uint8* src)
{
 memcpy(BootROM, src, 256);
}

static void LoadDOPO(Stream* sp, FloppyDisk* disk, const bool ispo)
{
 std::unique_ptr<uint8[]> track_buffer(new uint8[256 * 16]);

 for(unsigned track = 0; track < num_tracks; track++)
 {
  const unsigned apple_track = track / 4;

  if(!(track & 0x3) && apple_track < 35)
  {
   sp->read(track_buffer.get(), 256 * 16);
   //
   //
   apple2_track_encoder te(&disk->tracks[track], 50992);

   te.encode_gap1<true>(40);

   for(unsigned sector = 0; sector < 16; sector++)
   {
    if(ispo)
     te.encode_sector<true>(0xFE, apple_track, sector, &track_buffer[(((sector & 1) << 3) + (sector >> 1)) * 256]);
    else
    {
     static const uint8 tab[16] = { 0x0, 0x7, 0xE, 0x6, 0xD, 0x5, 0xC, 0x4, 0xB, 0x3, 0xA, 0x2, 0x9, 0x1, 0x8, 0xF };

     te.encode_sector<true>(0xFE, apple_track, sector, &track_buffer[tab[sector] * 256]);
    }
   }
   te.finish();
   //
   //
   if(track > 0)
    disk->tracks[track - 1] = disk->tracks[track];
   if(track < (num_tracks - 1))
    disk->tracks[track + 1] = disk->tracks[track];
  }
 }
}

static void LoadD13(Stream* sp, FloppyDisk* disk)
{
 std::unique_ptr<uint8[]> track_buffer(new uint8[256 * 13]);

 for(unsigned track = 0; track < num_tracks; track++)
 {
  const unsigned apple_track = track / 4;

  if(!(track & 0x3) && apple_track < 35)
  {
   sp->read(track_buffer.get(), 256 * 13);
   //
   //
   apple2_track_encoder te(&disk->tracks[track], 50202);

   te.encode_gap1<false>(40);

   for(unsigned sector = 0; sector < 13; sector++)
   {
    const unsigned adj_sector = ((sector >> 2) + (sector & 3) * 10) % 13;

    te.encode_sector<false>(0xFE, apple_track, adj_sector, &track_buffer[adj_sector * 256]);
   }
   te.finish();
   //
   //
   if(track > 0)
    disk->tracks[track - 1] = disk->tracks[track];
   if(track < (num_tracks - 1))
    disk->tracks[track + 1] = disk->tracks[track];
  }
 }
}

static const uint8 woz_header_magic[8]  = { 0x57, 0x4F, 0x5A, 0x31, 0xFF, 0x0A, 0x0D, 0x0A };
static const uint8 woz2_header_magic[8] = { 0x57, 0x4F, 0x5A, 0x32, 0xFF, 0x0A, 0x0D, 0x0A };

static void LoadWOZ(Stream* sp, FloppyDisk* disk)
{
 uint8 header[12];

 MDFN_printf(_("Parsing WOZ-format disk image...\n"));

 if(sp->read(header, 12, false) != 12 || (memcmp(header, woz_header_magic, sizeof(woz_header_magic)) && memcmp(header, woz2_header_magic, sizeof(woz2_header_magic))))
  throw MDFN_Error(0, _("Bad or missing WOZ file header."));
 //
 const bool woz2 = !memcmp(header, woz2_header_magic, sizeof(woz2_header_magic));
 //
 uint8 disk_type;
 uint8 write_protected;
 uint8 synchronized;
 uint8 cleaned;
 uint8 optimal_bit_timing = 32;
 uint16 compat_hw = 0;
 uint16 req_ram = 0;
 //
 uint8 chunk_header[8];
 unsigned required_chunks = 0;
 uint8 tmap[160] = { 0 };
 uint8 num_src_tracks = 0;
 std::unique_ptr<FloppyDisk::Track[]> src_tracks;
 //std::map<

 static_assert(num_tracks >= sizeof(tmap), "num_tracks is too small");

 while(sp->read(chunk_header, sizeof(chunk_header), false) == sizeof(chunk_header))
 {
  const uint32 chunk_id = MDFN_de32lsb(&chunk_header[0]);
  const uint32 chunk_size = MDFN_de32lsb(&chunk_header[4]);

  if(chunk_id == 0x4F464E49)	// INFO
  {
   if(sp->tell() != 20)
    throw MDFN_Error(0, _("Required chunk \"%s\" is at the wrong offset."), "INFO");

   if(chunk_size != 60)
    throw MDFN_Error(0, _("Required chunk \"%s\" is of the wrong size."), "INFO");
   //
   uint8 info[60];
   sp->read(info, sizeof(info));
   //
   const uint8 info_version = info[0];
   char creator[0x20 + 1];

   disk_type = info[1];
   write_protected = info[2];
   synchronized = info[3];
   cleaned = info[4];

   memcpy(creator, &info[5], 0x20);
   creator[0x20] = 0;
   MDFN_zapctrlchars(creator);
   MDFN_trim(creator);

   if(woz2) 
   {
    optimal_bit_timing = info[39];
    compat_hw = MDFN_de16lsb(&info[40]);
    req_ram = MDFN_de16lsb(&info[42]);
   }

   if(disk_type == 0x02)
    throw MDFN_Error(0, _("3.5\" floppy disk images not currently supported."));

   if(disk_type != 0x01)
    throw MDFN_Error(0, _("Unknown disk type: 0x%02x"), disk_type);

   disk->write_protect = (bool)write_protected;

   MDFN_printf(_(" INFO:\n"));
   MDFN_printf(_("  Version: %u\n"), info_version);
   MDFN_printf(_("  Disk type: %u\n"), disk_type);
   MDFN_printf(_("  Write protected: %u\n"), write_protected);
   MDFN_printf(_("  Synchronized: %u\n"), synchronized);
   MDFN_printf(_("  Cleaned: %u\n"), cleaned);
   MDFN_printf(_("  Creator: %s\n"), creator);

   if(woz2)
   {
    static const char* compat_hw_tab[] = { "Apple II", "Apple II+", "Apple IIe", "Apple IIc", "Apple IIe Enhanced", "Apple IIgs", "Apple IIc Plus", "Apple III", "Apple III Plus" };
    std::string compat_hw_str;

    for(size_t i = 0; i < sizeof(compat_hw_tab) / sizeof(compat_hw_tab[0]); i++)
    {
     if(compat_hw & (1U << i))
     {
      if(compat_hw_str.size())
       compat_hw_str += ", ";

      compat_hw_str += compat_hw_tab[i];
     }
    }

    if(!compat_hw_str.size())
     compat_hw_str = _("Unknown");

    MDFN_printf(_("  Optimal bit timing: %u\n"), optimal_bit_timing);
    MDFN_printf(_("  Compatible hardware: %s\n"), compat_hw_str.c_str());
    if(!req_ram)
     MDFN_printf(_("  Required RAM: %s\n"), _("Unknown"));
    else
     MDFN_printf(_("  Required RAM: %u KiB\n"), req_ram);
   }
   //
   required_chunks |= 1;
  }
  else if(chunk_id == 0x50414D54)	// TMAP
  {
   if(sp->tell() != 88)
    throw MDFN_Error(0, _("Required chunk \"%s\" is at the wrong offset."), "TMAP");

   if(chunk_size != 160)
    throw MDFN_Error(0, _("Required chunk \"%s\" is of the wrong size."), "TMAP");
   //
   sp->read(tmap, sizeof(tmap));

   for(unsigned i = 0; i < sizeof(tmap); i++)
   {
    if(tmap[i] != 0xFF && tmap[i] >= num_src_tracks)
     num_src_tracks = tmap[i] + 1;
   }
   //
   required_chunks |= 2;
  }
  else if(chunk_id == 0x534B5254)	// TRKS
  {
   if(sp->tell() != 256)
    throw MDFN_Error(0, _("Required chunk \"%s\" is at the wrong offset."), "TRKS");

   src_tracks.reset(new FloppyDisk::Track[num_src_tracks]);

   MDFN_printf(" TRKS:\n");

   if(woz2)
   {
    std::unique_ptr<uint8[]> index(new uint8[1280]);
    std::unique_ptr<uint8[]> trk(new uint8[(max_bits_per_track + 7) >> 3]);

    sp->read(index.get(), 1280);

    for(unsigned i = 0; i < num_src_tracks; i++)
    {
     const uint16 starting_block = MDFN_de16lsb(&index[i * 8 + 0]);
     const uint16 block_count = MDFN_de16lsb(&index[i * 8 + 2]);
     const uint32 bit_count = MDFN_de32lsb(&index[i * 8 + 4]);

     if(bit_count > (block_count * 8 * 512))
      throw MDFN_Error(0, _("Bit count of TRKS chunk TRK entry %u is larger than the block count * 512 * 8!"), i);

     if(bit_count < min_bits_per_track || bit_count > max_bits_per_track)
      throw MDFN_Error(0, _("Bit count(%u) of TRKS chunk TRK entry %u is out of the acceptable range of %u through %u!"), bit_count, i, min_bits_per_track, max_bits_per_track);
     //
     //
     //
     sp->seek(starting_block * 512);
     sp->read(trk.get(), (bit_count + 7) >> 3);
     //
     MDFN_printf(_("  Source track %u:\n"), i);

     MDFN_printf(_("    Starting block: %u\n"), starting_block);
     MDFN_printf(_("    Block count: %u\n"), block_count);
     MDFN_printf(_("    Bit count: %u\n"), bit_count);
     //
     apple2_track_encoder te(&src_tracks[i], bit_count);

     for(size_t bi = 0; bi < bit_count; bi++)
     {
      te.encode_bit((trk[bi >> 3] >> (0x7 - (bi & 0x7))) & 1);
     }
     te.finish();
    }
   }
   else
   {
    if(chunk_size != num_src_tracks * 6656)
     throw MDFN_Error(0, _("Required chunk \"%s\" is of the wrong size."), "TRKS");

    for(unsigned i = 0; i < num_src_tracks; i++)
    {
     uint8 trk[6656];

     sp->read(trk, 6656);
     //
     const uint16 bytes_used = MDFN_de16lsb(&trk[6646]);
     const uint16 bit_count = MDFN_de16lsb(&trk[6648]);
     const uint16 splice_point = MDFN_de16lsb(&trk[6650]);
     const uint8 splice_nibble = trk[6652];
     const uint8 splice_bit_count = trk[6653];
     const uint16 reserved = MDFN_de16lsb(&trk[6654]);

     if(bytes_used > 6646)
      throw MDFN_Error(0, _("Bytes used of TRKS chunk TRK entry %u is larger than 6646!"), i);

     if(bit_count > bytes_used * 8)
      throw MDFN_Error(0, _("Bit count of TRKS chunk TRK entry %u is larger than the number of bytes used * 8!"), i);

     //
     // Sanity check, various assumptions to boost performance break down if the number of bits is too low or high.
     // Maybe should check if the maximum absolute difference of one track's bit count compared to another track's bit count
     // is too large too...
     //
     if(bit_count < min_bits_per_track || bit_count > max_bits_per_track)
      throw MDFN_Error(0, _("Bit count(%u) of TRKS chunk TRK entry %u is out of the acceptable range of %u through %u!"), bit_count, i, min_bits_per_track, max_bits_per_track);

     MDFN_printf(_("  Source track %u:\n"), i);

     MDFN_printf(_("    Bytes used: %u\n"), bytes_used);
     MDFN_printf(_("    Bit count: %u\n"), bit_count);
     MDFN_printf(_("    Splice point: %u\n"), splice_point);
     MDFN_printf(_("    Splice nibble: 0x%02x\n"), splice_nibble);
     MDFN_printf(_("    Splice bit count: %u\n"), splice_bit_count);
     MDFN_printf(_("    Reserved: 0x%04x\n"), reserved);
     //
     apple2_track_encoder te(&src_tracks[i], bit_count);

     for(size_t bi = 0; bi < bit_count; bi++)
     {
      te.encode_bit((trk[bi >> 3] >> (0x7 - (bi & 0x7))) & 1);
     }
     te.finish();
    }
   }

   for(unsigned i = 0; i < sizeof(tmap); i++)
   {
    if(tmap[i] != 0xFF)
    {
     //printf("%d, %d\n", i, tmap[i]);
     disk->tracks[i] = src_tracks[tmap[i]];
    }
   }
   //
   required_chunks |= 4;
  }
/*
  else if(chunk_id == 0x4154454D)	// META
  {
   for(uint32 i = 0; i < chunk_size; i++)
    printf("%c", sp->get_u8());
  }
*/
 }

 if(!(required_chunks & 1))
  throw MDFN_Error(0, _("Required chunk \"%s\" is missing."), "INFO");

 if(!(required_chunks & 2))
  throw MDFN_Error(0, _("Required chunk \"%s\" is missing."), "TMAP");

 if(!(required_chunks & 4))
  throw MDFN_Error(0, _("Required chunk \"%s\" is missing."), "TRKS");
 //
 //
 //
 //abort();
}

/*
Track 44, bo=0, ss=50360, match_count=45762, match_first=0

     Source track 11:
       Bytes used: 6296
       Bit count: 50361
       Splice point: 65535
       Splice nibble: 0xff
       Splice bit count: 255
       Reserved: 0x0000

*/

#if 0
static void HandleBD(const SimpleBitset<131072>& bd, FloppyDisk::Track* track, const unsigned track_num)
{
  const int track_min_length = 51024 - 256; //256; //1024 - 1024; //256; // 1024; //2048;
  const int track_max_length = 51024 + 256; //256; //1024 + 1024; //256; //2048;
  int max_match_count = 0;
  int max_match_ss = 0;
  int max_match_bo = 0;
  int max_match_first = 0;

  int bo = 0;
  //for(int bo = 0; bo < 256; bo += 64)
  {
   for(int ss = track_min_length; ss < track_max_length; ss++)
   {
    unsigned match_count = 0;
    unsigned match_first = 0;

    for(int ci = 0; ci < track_max_length; ci++)
    {
     bool r = (bd[ci] == bd[ss + ci]);
     match_first += r & (match_first == ci);
     match_count += r;
    }

    //if(match_count > max_match_count) // || (!max_match_first && match_first))
    if((match_first < 20 && match_first > max_match_first) || (match_first >= 20 && match_count > max_match_count))
    {
     max_match_count = match_count;
     max_match_ss = ss;
     max_match_bo = bo;
     max_match_first = match_first;
    }
   }
  }
  printf("Track %d, bo=%d, ss=%d, match_count=%d, match_first=%d\n", track_num, max_match_bo, max_match_ss, max_match_count, max_match_first);

  // 8, 12, 80, 132, 136

  //
  //
  //
  apple2_track_encoder te(track, max_match_ss);

  for(unsigned i = 0; i < max_match_ss; i++)
  {
   //if(i && bd[max_match_bo + i] == bd[max_match_bo + i - 1] && !bd[max_match_bo + i])
   // printf("BLURP\n");

   //printf("%5u: %d\n", i, bd[max_match_bo + i]);
   te.encode_bit(bd[max_match_bo + i]);
  }

  te.finish();
}

// A2R and EDD, testing and whatnot only.
static void LoadA2R(Stream* sp, FloppyDisk* disk)
{
 static const uint8 header_magic[8] = { 0x41, 0x32, 0x52, 0x32, 0xFF, 0x0A, 0x0D, 0x0A };
 uint8 header[8];

 if(sp->read(header, sizeof(header), false) != sizeof(header) || memcmp(header, header_magic, sizeof(header)))
  throw MDFN_Error(0, _("A2R disk image has missing or bad header."));

 std::vector<uint8> strm_data_buf;
 uint8 chunk_header[8];

 while(sp->read(chunk_header, sizeof(chunk_header), false) == sizeof(chunk_header))
 {
  const uint32 chunk_id = MDFN_de32lsb(&chunk_header[0]);
  const uint32 chunk_size = MDFN_de32lsb(&chunk_header[4]);

  // STRM
  if(chunk_id == 0x4D525453)
  {
   const uint64 strm_bound_pos = sp->tell() + chunk_size;

   while(sp->tell() < strm_bound_pos)
   {
    uint8 strm_header[10];
    sp->read(strm_header, sizeof(strm_header));
    const uint8 track = strm_header[0];
    const uint8 capture_type = strm_header[1];
    const uint32 strm_data_size = MDFN_de32lsb(&strm_header[2]);
    const uint32 estimated_loop = MDFN_de32lsb(&strm_header[6]);

    printf("location=%02x capture_type=%02x data_size=%08x estimated_loop=%08x\n", track, capture_type, strm_data_size, estimated_loop);
    //
    SimpleBitset<131072> bd;
    uint32 bd_count = 0;
    uint32 td = 0;

    if(strm_data_buf.size() < strm_data_size)
     strm_data_buf.resize(strm_data_size * 1.25);	// FIXME: Limit

    sp->read(&strm_data_buf[0], strm_data_size);

    for(uint32 data_i = 0; data_i < strm_data_size; data_i++)
    {
     uint8 raw_td = strm_data_buf[data_i];
     
     td += raw_td;
     if(raw_td != 0xFF)
     {
      unsigned num_bits = (raw_td + 16) / 32;

      if(num_bits > 0)
      {
       do
       {
        bool b = (num_bits == 1);

        if(bd_count < 131072)
        {
         bd.set(bd_count, b);
         bd_count++;
        }
       } while(--num_bits);
      }
     }     
    }

    if(track < 0x8B) //num_tracks)
     HandleBD(bd, &disk->tracks[track], track);
    else
     break;
   }
  }
  else
   sp->seek(chunk_size, SEEK_CUR);
 }
 //abort();
}

static void LoadEDD(Stream* sp, FloppyDisk* disk)
{
 const uint64 sp_size = sp->size();
 unsigned file_num_tracks;
 unsigned file_track_stepping;
 if(sp_size & 16383)

  throw MDFN_Error(0, _("EDD disk image size is not a multiple of 16384 bytes."));

 file_num_tracks = sp_size / 16384;

 if(!file_num_tracks)
  throw MDFN_Error(0, _("EDD disk image is empty."));

 if(file_num_tracks <= 42)
  file_track_stepping = 4;
 else if(file_num_tracks <= 84)
  file_track_stepping = 2;
 else
  file_track_stepping = 1;

 if(((file_num_tracks - 1) * file_track_stepping) >= num_tracks)
  throw MDFN_Error(0, _("EDD disk image has too many tracks."));

 printf("%d %d\n", file_num_tracks, file_track_stepping);

 for(unsigned ft = 0; ft < file_num_tracks; ft++)
 {
  unsigned track = ft * file_track_stepping;
  uint8 rd[16384];
  SimpleBitset<131072> bd;

  sp->read(rd, sizeof(rd));

  for(unsigned i = 0; i < 16384; i++)
  {
   for(unsigned b = 0; b < 8; b++)
    bd.set((i << 3) + b, (rd[i] >> (7 - b)) & 1);
  }

/*
  //unsigned l = 51098; //100;
  //continue;
*/
  if((track & 3) && track != 10)
   continue;
  //if(track & 3)
  // continue;

  HandleBD(bd, &disk->tracks[track], track);

#if 1
  if(track > 0)
   disk->tracks[track - 1] = disk->tracks[track];
  if(track < (num_tracks - 1))
   disk->tracks[track + 1] = disk->tracks[track];
#endif
 }

 //abort();
}
#endif

static void LoadAFD(Stream* sp, FloppyDisk* disk)
{
 const uint8 header_magic[7] = { 'M', 'D', 'F', 'N', 'A', 'F', 'D' };
 uint8 header[16];
 uint32 version MDFN_NOWARN_UNUSED;
 bool bigendian;

 if(sp->read(header, 16, false) != 16 || memcmp(header, header_magic, sizeof(header_magic)))
  throw MDFN_Error(0, _("Bad or missing Mednafen AFD file header."));

 bigendian = header[7];
 version = MDFN_de32lsb(&header[8]);
 disk->write_protect = header[12] & 0x01;

 for(unsigned t = 0; t < num_tracks; t++)
 {
  uint8 track_header[8] = { 0 };
  uint32 length;
  bool flux_fudge;

  sp->read(track_header, sizeof(track_header));

  length = MDFN_de32lsb(&track_header[0]);
  flux_fudge = track_header[4];

  if(length < min_bits_per_track || length > max_bits_per_track)
   throw MDFN_Error(0, _("The length of Mednafen AFD track %u, %u, is out of the supported range of %u through %u."), t, length, min_bits_per_track, max_bits_per_track);

  disk->tracks[t].flux_fudge = flux_fudge;
  disk->tracks[t].length = length;
  sp->read(disk->tracks[t].data.data, disk->tracks[t].data.data_count * sizeof(disk->tracks[t].data.data[0]));

  if(MDFN_IS_BIGENDIAN != bigendian)
  {
   for(uint32& v : disk->tracks[t].data.data)
    v = MDFN_bswap32(v);
  }
 }
}


template<typename T_RET, unsigned bw, typename T_ARG>
static INLINE T_RET sext(const T_ARG v)
{
 return (typename std::make_signed<T_RET>::type)((typename std::make_unsigned<T_RET>::type)(typename std::make_unsigned<T_ARG>::type)v << (sizeof(T_RET) * 8 - bw)) >> (sizeof(T_RET) * 8 - bw);
}

void Init(void)
{
 for(unsigned i = 0; i < 256; i++)
 {
  //printf("%08x %08x %08x %08x %08x\n", sign_x_to_s32(6, i), sext<uint32, 6>((unsigned)i), sext<uint32, 6>((signed)i), sext<int32, 6>((unsigned)i), sext<int32, 6>((signed)i));
 }
 //abort();

 for(int phase_control = 0x0; phase_control < 0x10; phase_control++)
 {
  for(int angle = 0; angle < 128; angle++)	// 0, 2.8125, 5.625, etc.
  {
   // TODO: something more accurate
   int32 delta = 0;

   for(unsigned pci = 0; pci < 4; pci++)	// 0, 90, 180, 270
   {
    int t = sext<int32, 7>((pci * 32 + 8/*22.5deg bias for rounding to nearest internal track*/) - angle);

    if((phase_control & (1U << pci)) && abs(t) <= 40)
    {
     int32 dt = (32 - abs(abs(t) - 20)) * 512;


     delta += (t <= 0) ? -dt : dt; //-8192 : 8192;
    }
   }
   assert(delta >= -32768 && delta <= 32767);
   StepperLUT[phase_control][angle] = delta;
   //printf("Phase control: %02x, angle: %02x, delta: %d\n", phase_control, angle, delta);
  }
 }
 //abort();

 for(unsigned A = 0xC600; A < 0xC700; A++)
  SetReadHandler(A, ReadBootROM);

 SetRWHandlers(0xC0E0, RW<0x0>, RW<0x0>);
 SetRWHandlers(0xC0E1, RW<0x1>, RW<0x1>);
 SetRWHandlers(0xC0E2, RW<0x2>, RW<0x2>);
 SetRWHandlers(0xC0E3, RW<0x3>, RW<0x3>);
 SetRWHandlers(0xC0E4, RW<0x4>, RW<0x4>);
 SetRWHandlers(0xC0E5, RW<0x5>, RW<0x5>);
 SetRWHandlers(0xC0E6, RW<0x6>, RW<0x6>);
 SetRWHandlers(0xC0E7, RW<0x7>, RW<0x7>);
 SetRWHandlers(0xC0E8, RW<0x8>, RW<0x8>);
 SetRWHandlers(0xC0E9, RW<0x9>, RW<0x9>);
 SetRWHandlers(0xC0EA, RW<0xA>, RW<0xA>);
 SetRWHandlers(0xC0EB, RW<0xB>, RW<0xB>);
 SetRWHandlers(0xC0EC, RW<0xC>, RW<0xC>);
 SetRWHandlers(0xC0ED, RW<0xD>, RW<0xD>);
 SetRWHandlers(0xC0EE, RW<0xE>, RW<0xE>);
 SetRWHandlers(0xC0EF, RW<0xF>, RW<0xF>);

 //
 //
 for(unsigned drive_index = 0; drive_index < 2; drive_index++)
 {
  FloppyDrive* drive = &Drives[drive_index];

  drive->inserted_disk = &DummyDisk;
  drive->m_history = 0;
  drive->stepper_position = 0x00800000;
  //drive->stepper_position = ((num_tracks - 1) << 24) | 0x00800000;
  //drive->motor_speed = 0;
 }

 //lastts = 0;
}

static void LoadDisk(Stream* sp, const std::string& ext, FloppyDisk* disk)
{
 assert(sp && disk);

 if(ext == "woz")
  LoadWOZ(sp, disk);
 else if(ext == "d13")
  LoadD13(sp, disk);
 else if(ext == "do" || ext == "dsk")
  LoadDOPO(sp, disk, false);
 else if(ext == "po")
  LoadDOPO(sp, disk, true);
 else if(ext == "afd")
  LoadAFD(sp, disk);
#if 0
 else if(ext == "a2r")
  LoadA2R(sp, disk);
 else if(ext == "edd")
  LoadEDD(sp, disk);
#endif
 else
 {
  const uint64 sp_size = sp->size();
  uint8 header[12];
  bool woz_header_detected;

  MDFN_printf("Warning: Detecting Apple II disk image format by contents and/or size(ext=%s).\n", ext.c_str());

  woz_header_detected = (sp->read(header, 12, false) == 12 && (!memcmp(header, woz_header_magic, sizeof(woz_header_magic)) || !memcmp(header, woz2_header_magic, sizeof(woz2_header_magic))));
  sp->rewind();

  if(woz_header_detected)
   LoadWOZ(sp, disk);
  else if(sp_size == 143360)
   LoadDOPO(sp, disk, false);
  else if(sp_size == 116480)
   LoadD13(sp, disk);
  else
   throw MDFN_Error(0, _("Apple II floppy disk image is in an unidentified or unsupported format."));
 }
}

static void HashDisk(sha256_hasher* h, const FloppyDisk* disk)
{
 for(auto const& t : disk->tracks)
 {
  for(uint32 const& v : t.data.data)
   h->process_scalar<uint32>(v);

  h->process_scalar<uint32>(t.length);
  h->process_scalar<uint32>(t.flux_fudge);
 }
}

#if 0
// Doesn't support certain cases; don't use.
static void SaveDisk(Stream* sp, const FloppyDisk* disk)
{
 std::unique_ptr<uint8[]> tbuf(new uint8[6656]);
 uint8 bh[256];

 memset(bh, 0, sizeof(bh));
 memcpy(&bh[0], woz_header_magic, sizeof(woz_header_magic));

 MDFN_en32lsb(&bh[8], 0x00000000);	// TODO: CRC32

 //
 // INFO
 //
 MDFN_en32lsb(&bh[12], 0x4F464E49);
 MDFN_en32lsb(&bh[16], 60);
 bh[20] = 0x01;	// Version
 bh[21] = 0x01;	// Disk type
 bh[22] = disk->write_protect;
 bh[23] = 0;	// TODO: cross-track sync
 bh[24] = 0;	// TODO: cleaned
 {
  const char* creator = "Mednafen " MEDNAFEN_VERSION;
  const size_t creator_len = strlen(creator);

  for(unsigned i = 0; i < 32; i++)
   bh[25 + i] = (i < creator_len) ? creator[i] : 0x20;
 }

 //
 // TMAP
 //
 MDFN_en32lsb(&bh[80], 0x50414D54);
 MDFN_en32lsb(&bh[84], 160);
 for(unsigned i = 0; i < 160; i++)
  bh[88 + i] = i;

 //
 // TRKS
 //
 MDFN_en32lsb(&bh[248], 0x534B5254);
 MDFN_en32lsb(&bh[252], 6656 * 160);	// TODO: size

 sp->write(bh, sizeof(bh));

/*
 struct Track
 {
  SimpleBitset<65536> data;
  uint32 length = 51024;
  bool flux_fudge = false;
 } tracks[num_tracks];
*/

 for(unsigned t = 0; t < 160; t++)
 {
  auto const& track = disk->tracks[t];
  const uint32 track_bytelength = (track.length + 7) >> 3;
  bool lv = false; //disk->tracks[t].data[track.length - 1] ^ disk->tracks[t].flux_fudge;

  assert(track_bytelength <= 6646);

  for(size_t i = 0; i < 6646; i++)
  {
   unsigned v = 0x00;

   for(size_t b = 0; b < 8; b++)
   {
    bool cv = disk->tracks[t].data[(i << 3) + b];
    v <<= 1;
    v |= lv ^ cv;
    lv = cv;
   }

   tbuf[i] = v;
  }

  MDFN_en16lsb(&tbuf[6646], track_bytelength);
  MDFN_en16lsb(&tbuf[6648], track.length);
  MDFN_en16lsb(&tbuf[6650], 0xFFFF);
  tbuf[6652] = 0;
  tbuf[6653] = 0;
  MDFN_en16lsb(&tbuf[6654], 0);

  sp->write(&tbuf[0], 6656);
 }
}
#endif

static void SaveDisk(Stream* sp, const FloppyDisk* disk)
{
 uint8 header[16] = { 'M', 'D', 'F', 'N', 'A', 'F', 'D', MDFN_IS_BIGENDIAN };
 MDFN_en32lsb(&header[8], MEDNAFEN_VERSION_NUMERIC);
 header[12] = disk->write_protect;

 sp->write(header, sizeof(header));

 for(unsigned t = 0; t < num_tracks; t++)
 {
  uint8 track_header[8] = { 0 };

  MDFN_en32lsb(&track_header[0], disk->tracks[t].length);
  track_header[4] = disk->tracks[t].flux_fudge;

  sp->write(track_header, sizeof(track_header));
  sp->write(disk->tracks[t].data.data, disk->tracks[t].data.data_count * sizeof(disk->tracks[t].data.data[0]));
 }
}

static bool DetectDOS32(FloppyDisk* disk)
{
 std::vector<uint8> buf(65536 / 8 * 2);
 const FloppyDisk::Track* tr = &disk->tracks[0];
 bool prev_m = false;
 uint32 fc_history = 0;
 unsigned bit_counter = 0;
 size_t buf_index = 0;
 bool dos32_sh0_present = false;
 bool dos33_sh0_present = false;

 for(unsigned i = 0; i < tr->length * 2; i++)
 {
  const unsigned angle = i % tr->length;
  const bool m = tr->data[angle];

  fc_history <<= 1;
  fc_history |= prev_m ^ m;
  prev_m = m;  
  //
  //
  if(bit_counter || (fc_history & 1))
  {
   bit_counter++;
   if(bit_counter == 8)
   {
    assert(buf_index < buf.size());
    //
    bit_counter = 0;
    buf[buf_index] = fc_history & 0xFF;
    buf_index++;
   }
  }
 }

 for(unsigned i = 0; i < buf.size() / 2; i++)
 {
  uint8* d = &buf[i];

  if(d[0] == 0xD5 && d[1] == 0xAA && (d[2] == 0xB5 || d[2] == 0x96))
  {
   const uint8 sh_volume = ((d[3] << 1) | (d[3] >> 7)) & d[4];
   const uint8 sh_track = ((d[5] << 1) | (d[5] >> 7)) & d[6];
   const uint8 sh_sector = ((d[7] << 1) | (d[7] >> 7)) & d[8];
   const uint8 sh_csum = ((d[9] << 1) | (d[9] >> 7)) & d[10];

   //printf("Volume: %02x Track: %02x Sector: %02x(%02x%02x) CSum: %02x\n", sh_volume, sh_track, sh_sector, d[7], d[8], sh_csum);

   if(sh_track == 0 && sh_sector == 0 && !(sh_volume ^ sh_track ^ sh_sector ^ sh_csum))
   {
    //printf("YES: %02x\n", d[2]);
    if(d[2] == 0x96)
     dos33_sh0_present = true;
    else
     dos32_sh0_present = true;
   }
  }

#if 0
  if(d[0] == 0xD5 && d[1] == 0xAA && d[2] == 0xAD)
  {
   static const uint8 tab[0x20] =
   {
    0xAB, 0xAD, 0xAE, 0xAF, 0xB5, 0xB6, 0xB7, 0xBA, 0xBB, 0xBD, 0xBE, 0xBF, 0xD6, 0xD7, 0xDA, 0xDB,
    0xDD, 0xDE, 0xDF, 0xEA, 0xEB, 0xED, 0xEE, 0xEF, 0xF5, 0xF6, 0xF7, 0xFA, 0xFB, 0xFD, 0xFE, 0xFF
   };
   static uint8 rtab[256];
   static bool inited = false;;
   uint8* ec = &d[3];
   uint8 tbuf[411];
   uint8 ud[256] = { 0 };

   if(!inited)
   {
    memset(rtab, 0xFF, sizeof(rtab));
    for(unsigned ti = 0; ti < 0x20; ti++)
     rtab[tab[ti]] = ti;
    inited = true;
   }

   uint8 cv = 0;
   for(unsigned eci = 0; eci < 411; eci++)
   {
    assert(rtab[ec[eci]] != 0xFF);
    cv ^= rtab[ec[eci]];
    tbuf[eci] = cv;
   }

   for(unsigned tbi = 0; tbi < 410; tbi++)
   {
    printf("%03x: %02x\n", tbi, tbuf[tbi]);
   }
   printf("%02x %02x, %02x\n", cv, tbuf[410], ec[411]);

   //buf[1 * 0x33 - 1 - group] = ((user_data[group * 5 + 0] & 0x7) << 2) | ((user_data[group * 5 + 3] & 0x4) >> 1) | ((user_data[group * 5 + 4] & 0x4) >> 2);
   //buf[2 * 0x33 - 1 - group] = ((user_data[group * 5 + 1] & 0x7) << 2) | ((user_data[group * 5 + 3] & 0x2) >> 0) | ((user_data[group * 5 + 4] & 0x2) >> 1);
   //buf[3 * 0x33 - 1 - group] = ((user_data[group * 5 + 2] & 0x7) << 2) | ((user_data[group * 5 + 3] & 0x1) << 1) | ((user_data[group * 5 + 4] & 0x1) >> 0);;
/*
   for(unsigned argh = 0; argh < 0x9A; argh++)
   {
    if((tbuf[argh] >> 2) == 0x0)	// for user data at 0x0
     printf("ARGH0 %02x(mod3=%02x, mod5=%02x, mod33=%02x)\n", argh, argh % 3, argh % 5, argh % 33);

    if((tbuf[argh] >> 2) == 0x3)	// for user data at 0x5
     printf("ARGH5 %02x(mod3=%02x, mod5=%02x, mod33=%02x)\n", argh, argh % 3, argh % 5, argh % 33);

    if((tbuf[argh] >> 2) == 0x7)	// for user data at 0xA
     printf("ARGHA %02x(mod3=%02x, mod5=%02x, mod33=%02x)\n", argh, argh % 3, argh % 5, argh % 33);

    if((tbuf[argh] >> 2) == 0x5)	// for user data at 0xF
     printf("ARGHF %02x(mod3=%02x, mod5=%02x, mod33=%02x)\n", argh, argh % 3, argh % 5, argh % 33);
   }
*/
   for(unsigned group = 0; group < 0x33; group++)
   {
    ud[group * 5 + 0] = tbuf[0x0CC - group/*0x0CC ... 0x09A*/] << 3;
    ud[group * 5 + 1] = tbuf[0x0FF - group/*0x0FF ... 0x0CD*/] << 3;
    ud[group * 5 + 2] = tbuf[0x132 - group/*0x132 ... 0x100*/] << 3;
    ud[group * 5 + 3] = tbuf[0x165 - group/*0x165 ... 0x133*/] << 3;
    ud[group * 5 + 4] = tbuf[0x198 - group/*0x198 ... 0x166*/] << 3;

    ud[group * 5 + 0] |= tbuf[0x67 + group] >> 2;	// OK
    ud[group * 5 + 1] |= tbuf[0x34 + group] >> 2;
    ud[group * 5 + 2] |= tbuf[0x01 + group] >> 2;

    ud[group * 5 + 3] |= ((tbuf[0x67 + group] & 0x2) << 1) | ((tbuf[0x34 + group] & 0x2) << 0) | ((tbuf[0x01 + group] & 0x2) >> 1);
    ud[group * 5 + 4] |= ((tbuf[0x67 + group] & 0x1) << 2) | ((tbuf[0x34 + group] & 0x1) << 1) | ((tbuf[0x01 + group] & 0x1) << 0);


    //ud[group * 5 + 4] |= ((bool)(tbuf[0x98] & 0x1) << 0) | ((bool)(tbuf[0x65] & 0x1) << 1) | ((bool)(tbuf[0x32] & 0x1) << 2);
    //ud[group * 5 + 4] |= ((bool)(tbuf[0x99] & 0x1) << 0) | ((bool)(tbuf[0x66] & 0x1) << 1) | ((bool)(tbuf[0x33] & 0x1) << 2);

    //ud[group * 5 + 3] |= ((bool)(tbuf[(0x33 - group) * 3 + 0] & 0x2) << 0) | ((bool)(tbuf[(0x33 - group) * 3 + 1] & 0x2) << 1) | ((bool)(tbuf[(0x33 - group) * 3 + 2] & 0x2) << 2);

    // argh: ud[group * 5 + 4] |= ((bool)(tbuf[(0x32 - group) * 3 + 0] & 0x1) << 0) | ((bool)(tbuf[(0x32 - group) * 3 + 1] & 0x1) << 1) | ((bool)(tbuf[(0x32 - group) * 3 + 2] & 0x1) << 2);

    //ud[group * 5 + 4] |= (!!(tbuf[3 * 0x33 - 1 - group] & 0x1) << 0) | (!!(tbuf[2 * 0x33 - 1 - group] & 0x1) << 1) | (!!(tbuf[1 * 0x33 - 1 - group] & 0x1) << 2);
   }

   ud[0xFF] = (tbuf[0x199] << 3) | (tbuf[0x00] & 0x7);	// TODO: Check lower bits;

   for(unsigned udi = 0; udi < 256; udi++)
   {
    printf("%02x: %02x\n", udi, ud[udi]);
   }

   abort();
  }
#endif
 }

 return dos32_sh0_present && !dos33_sh0_present;
}

#if 0
static void AnalyzeDisk(FloppyDisk* disk)
{
 unsigned track = 0;
 unsigned bit_history = 0;
 unsigned fc_history = 0;
 unsigned bit_counter = 0;
 unsigned l = disk->tracks[track].length;
 unsigned angle = l * 1/2;

 printf("%d\n", angle);

 for(; l; l--, angle = (angle + 1) % disk->tracks[track].length)
 {
  bit_history <<= 1;
  bit_history |= disk->tracks[track].data[angle];

  fc_history <<= 1;
  fc_history |= ((bit_history >> 1) ^ bit_history) & 1;

  if((fc_history & 0x3FF) == 0x3FC)
   bit_counter = 0;

  if(bit_counter || (fc_history & 1))
  {
   bit_counter++;
   if(bit_counter == 8)
   {
    printf("%02x\n", fc_history & 0xFF);
    bit_counter = 0;
   }
  }
  else
   printf("{0}\n");

  if((fc_history & 0x3FF) == 0x3FC)
   printf("(Sync10)\n");
 }
 printf("Hi\n");
}
#endif

static bool GetEverModified(FloppyDisk* disk)
{
 return disk->ever_modified;
}

static void SetEverModified(FloppyDisk* disk)
{
 disk->ever_modified = true;
}

static MDFN_NOWARN_UNUSED bool GetClearDiskDirty(FloppyDisk* disk)
{
 bool ret = disk->dirty;

 disk->dirty = false;

 return ret;
}

static void SetDisk(unsigned drive_index, FloppyDisk* disk)
{
 assert(drive_index < 2);
 //
 FloppyDrive* drive = &Drives[drive_index];
 FloppyDisk* old_disk = drive->inserted_disk;
 FloppyDisk* new_disk = disk ? disk : &DummyDisk;
 const unsigned tri = drive->stepper_position >> 24;

 old_disk->angle = (((uint64)old_disk->angle << (32 - 3)) / old_disk->tracks[tri].length);
 new_disk->angle = (((uint64)new_disk->angle * new_disk->tracks[tri].length + (1U << (32 - 3 - 1))) >> (32 - 3)) % (new_disk->tracks[tri].length << 3);
 drive->inserted_disk = new_disk;

 APPLE2_DBG(APPLE2_DBG_DISK2, "[DISK2] Drive %u disk set; stepper_track=%u, new_disk_angle=%u\n", 1 + drive_index, tri, new_disk->angle);
 //
 assert(Drives[0].inserted_disk == &DummyDisk || Drives[0].inserted_disk != Drives[1].inserted_disk);
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(Latch_Stepper),
  SFVAR(Latch_MotorOn),
  SFVAR(Latch_DriveSelect),
  SFVAR(Latch_Mode),
  SFVAR(lcg_state),
  
  SFVAR(motoroff_delay_counter),
  SFVAR(data_reg),
  SFVAR(sequence),

#if defined(MDFN_APPLE2_DISK2SEQ_HLE)
  SFVAR(SeqHLE.fc_counter),
  SFVAR(SeqHLE.pending_bits),
  SFVAR(SeqHLE.pending_bits_count),
  SFVAR(SeqHLE.qa_delay),
#endif

  SFVAR(Drives->m_history, 2, sizeof(*Drives), Drives),
  SFVAR(Drives->delay_flux_change, 2, sizeof(*Drives), Drives),
  SFVAR(Drives->stepper_position, 2, sizeof(*Drives), Drives),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "DISKII");

 if(load)
 {
  for(unsigned di = 0; di < 2; di++)
  {
   ClampStepperPosition(&Drives[di]);
  }
 }
}

static void StateAction_Disk(StateMem* sm, const unsigned load, const bool data_only, FloppyDisk* disk, const char* sname)
{
 StateHelperDisk = *disk;

 SFORMAT StateRegs[] =
 {
  //SFVAR(disk->write_protect),
  // Don't store write protect?
  SFVAR(StateHelperDisk.tracks->data.data, num_tracks, sizeof(*StateHelperDisk.tracks), StateHelperDisk.tracks),
  SFVAR(StateHelperDisk.tracks->length, num_tracks, sizeof(*StateHelperDisk.tracks), StateHelperDisk.tracks),
  SFVAR(StateHelperDisk.tracks->flux_fudge, num_tracks, sizeof(*StateHelperDisk.tracks), StateHelperDisk.tracks),

  SFVAR(disk->angle),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);

 if(load)
 {
  if(disk == Drives[0].inserted_disk || disk == Drives[1].inserted_disk)
   disk->angle %= max_bits_per_track << 3;	// Incomplete sanitization, but it should be fine for now.

  for(unsigned t = 0; t < num_tracks; t++)
  {
   StateHelperDisk.tracks[t].length = std::min<unsigned>(max_bits_per_track, std::max<unsigned>(1, StateHelperDisk.tracks[t].length));
  }

  for(unsigned t = 0; t < num_tracks; t++)
  {
   bool diff = false;

   diff |= StateHelperDisk.tracks[t].data != disk->tracks[t].data;
   diff |= StateHelperDisk.tracks[t].flux_fudge != disk->tracks[t].flux_fudge;
   diff |= StateHelperDisk.tracks[t].length != disk->tracks[t].length;

   if(diff)
   {
    APPLE2_DBG(APPLE2_DBG_DISK2, "[DISK2] State load dirty track %u.\n", t);
    //
    disk->tracks[t] = StateHelperDisk.tracks[t];
    disk->dirty = true;
    disk->ever_modified = true;
   }
  }
 }
}

static void Kill(void)
{

}

}

