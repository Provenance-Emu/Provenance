/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include <cmath>
#include "../snes9x.h"
#include "apu.h"
#include "../msu1.h"
#include "../snapshot.h"
#include "../display.h"
#include "resampler.h"

#include "bapu/snes/snes.hpp"

static const int APU_DEFAULT_INPUT_RATE = 31950; // ~59.94Hz
static const int APU_SAMPLE_BLOCK       = 48;
static const int APU_NUMERATOR_NTSC     = 15664;
static const int APU_DENOMINATOR_NTSC   = 328125;
static const int APU_NUMERATOR_PAL      = 34176;
static const int APU_DENOMINATOR_PAL    = 709379;

// Max number of samples we'll ever generate before call to port API and
// moving the samples to the resampler.
// This is 535 sample frames, which corresponds to 1 video frame + some leeway
// for use with SoundSync, multiplied by 2, for left and right samples.
static const int MINIMUM_BUFFER_SIZE = 550 * 2;

namespace SNES {
#include "bapu/dsp/blargg_endian.h"
CPU cpu;
} // namespace SNES

namespace spc {
static apu_callback callback = NULL;
static void *callback_data = NULL;

static bool8 sound_in_sync = TRUE;
static bool8 sound_enabled = FALSE;

static Resampler *resampler = NULL;

static int32 reference_time;
static uint32 remainder;

static const int timing_hack_numerator = 256;
static int timing_hack_denominator = 256;
/* Set these to NTSC for now. Will change to PAL in S9xAPUTimingSetSpeedup
   if necessary on game load. */
static uint32 ratio_numerator = APU_NUMERATOR_NTSC;
static uint32 ratio_denominator = APU_DENOMINATOR_NTSC;

static double dynamic_rate_multiplier = 1.0;
} // namespace spc

namespace msu {
// Always 16-bit, Stereo; 1.5x dsp buffer to never overflow
static Resampler *resampler = NULL;
static int16 *resample_buffer = NULL;
static int resample_buffer_size = 0;
} // namespace msu

static void UpdatePlaybackRate(void);
static void SPCSnapshotCallback(void);
static inline int S9xAPUGetClock(int32);
static inline int S9xAPUGetClockRemainder(int32);

bool8 S9xMixSamples(uint8 *dest, int sample_count)
{
    int16 *out = (int16 *)dest;

    if (Settings.Mute)
    {
        memset(out, 0, sample_count << 1);
        S9xClearSamples();
    }
    else
    {
        if (spc::resampler->avail() >= sample_count)
        {
            spc::resampler->read((short *)out, sample_count);

            if (Settings.MSU1)
            {
                if (msu::resampler->avail() >= sample_count)
                {
                    if (msu::resample_buffer_size < sample_count)
                    {
                        if (msu::resample_buffer)
                            delete[] msu::resample_buffer;
                        msu::resample_buffer = new int16[sample_count];
                        msu::resample_buffer_size = sample_count;
                    }
                    msu::resampler->read(msu::resample_buffer,
                                         sample_count);
                    for (int i = 0; i < sample_count; ++i)
                    {
                        int32 mixed = (int32)out[i] + msu::resample_buffer[i];
                        out[i] = ((int16)mixed != mixed) ? (mixed >> 31) ^ 0x7fff : mixed;
                    }
                }
                else // should never occur
                    assert(0);
            }
        }
        else
        {
            memset(out, 0, sample_count << 1);
            return false;
        }
    }

    if (spc::resampler->space_empty() >= 535 * 2 || !Settings.SoundSync ||
        Settings.TurboMode || Settings.Mute)
        spc::sound_in_sync = true;
    else
        spc::sound_in_sync = false;

    return true;
}

int S9xGetSampleCount(void)
{
    return spc::resampler->avail();
}

void S9xLandSamples(void)
{
    if (spc::callback != NULL)
        spc::callback(spc::callback_data);

    if (spc::resampler->space_empty() >= 535 * 2 || !Settings.SoundSync ||
        Settings.TurboMode || Settings.Mute)
        spc::sound_in_sync = true;
    else
        spc::sound_in_sync = false;
}

void S9xClearSamples(void)
{
    spc::resampler->clear();
    if (Settings.MSU1)
        msu::resampler->clear();
}

bool8 S9xSyncSound(void)
{
    if (!Settings.SoundSync || spc::sound_in_sync)
        return (TRUE);

    S9xLandSamples();

    return (spc::sound_in_sync);
}

void S9xSetSamplesAvailableCallback(apu_callback callback, void *data)
{
    spc::callback = callback;
    spc::callback_data = data;
}

void S9xUpdateDynamicRate(int avail, int buffer_size)
{
    spc::dynamic_rate_multiplier = 1.0 + (Settings.DynamicRateLimit * (buffer_size - 2 * avail)) /
                                             (double)(1000 * buffer_size);

    UpdatePlaybackRate();
}

static void UpdatePlaybackRate(void)
{
    if (Settings.SoundInputRate == 0)
        Settings.SoundInputRate = APU_DEFAULT_INPUT_RATE;

    double time_ratio = (double)Settings.SoundInputRate * spc::timing_hack_numerator / (Settings.SoundPlaybackRate * spc::timing_hack_denominator);

    if (Settings.DynamicRateControl)
    {
        time_ratio *= spc::dynamic_rate_multiplier;
    }

    spc::resampler->time_ratio(time_ratio);

    if (Settings.MSU1)
    {
        time_ratio = (44100.0 / Settings.SoundPlaybackRate) * (Settings.SoundInputRate / 32040.0);
        msu::resampler->time_ratio(time_ratio);
    }
}

bool8 S9xInitSound(int buffer_ms)
{
    // The resampler and spc unit use samples (16-bit short) as arguments.
    int buffer_size_samples = MINIMUM_BUFFER_SIZE;
    int requested_buffer_size_samples = Settings.SoundPlaybackRate * buffer_ms * 2 / 1000;

    if (requested_buffer_size_samples > buffer_size_samples)
        buffer_size_samples = requested_buffer_size_samples;

    if (!spc::resampler)
    {
        spc::resampler = new Resampler(buffer_size_samples);
        if (!spc::resampler)
            return (FALSE);
    }
    else
        spc::resampler->resize(buffer_size_samples);


    if (!msu::resampler)
    {
        msu::resampler = new Resampler(buffer_size_samples * 3 / 2);
        if (!msu::resampler)
            return (FALSE);
    }
    else
        msu::resampler->resize(buffer_size_samples * 3 / 2);

    SNES::dsp.spc_dsp.set_output(spc::resampler);
    S9xMSU1SetOutput(msu::resampler);

    UpdatePlaybackRate();

    spc::sound_enabled = S9xOpenSoundDevice();

    return (spc::sound_enabled);
}

void S9xSetSoundControl(uint8 voice_switch)
{
    SNES::dsp.spc_dsp.set_stereo_switch(voice_switch << 8 | voice_switch);
}

void S9xSetSoundMute(bool8 mute)
{
    Settings.Mute = mute;
    if (!spc::sound_enabled)
        Settings.Mute = TRUE;
}

void S9xDumpSPCSnapshot(void)
{
    SNES::dsp.spc_dsp.dump_spc_snapshot();
}

static void SPCSnapshotCallback(void)
{
    S9xSPCDump(S9xGetFilenameInc((".spc"), SPC_DIR));
    printf("Dumped key-on triggered spc snapshot.\n");
}

bool8 S9xInitAPU(void)
{
    spc::resampler = NULL;
    msu::resampler = NULL;

    return (TRUE);
}

void S9xDeinitAPU(void)
{
    if (spc::resampler)
    {
        delete spc::resampler;
        spc::resampler = NULL;
    }

    if (msu::resampler)
    {
        delete msu::resampler;
        msu::resampler = NULL;
    }

    S9xMSU1DeInit();
}

static inline int S9xAPUGetClock(int32 cpucycles)
{
    return (spc::ratio_numerator * (cpucycles - spc::reference_time) + spc::remainder) /
           spc::ratio_denominator;
}

static inline int S9xAPUGetClockRemainder(int32 cpucycles)
{
    return (spc::ratio_numerator * (cpucycles - spc::reference_time) + spc::remainder) %
           spc::ratio_denominator;
}

uint8 S9xAPUReadPort(int port)
{
    S9xAPUExecute();
    return ((uint8)SNES::smp.port_read(port & 3));
}

void S9xAPUWritePort(int port, uint8 byte)
{
    S9xAPUExecute();
    SNES::cpu.port_write(port & 3, byte);
}

void S9xAPUSetReferenceTime(int32 cpucycles)
{
    spc::reference_time = cpucycles;
}

void S9xAPUExecute(void)
{
    SNES::smp.clock -= S9xAPUGetClock(CPU.Cycles);
    SNES::smp.enter();

    spc::remainder = S9xAPUGetClockRemainder(CPU.Cycles);

    S9xAPUSetReferenceTime(CPU.Cycles);
}

void S9xAPUEndScanline(void)
{
    S9xAPUExecute();
    SNES::dsp.synchronize();

    if (spc::resampler->space_filled() >= APU_SAMPLE_BLOCK || !spc::sound_in_sync)
        S9xLandSamples();
}

void S9xAPUTimingSetSpeedup(int ticks)
{
    if (ticks != 0)
        printf("APU speedup hack: %d\n", ticks);

    spc::timing_hack_denominator = 256 - ticks;

    spc::ratio_numerator = Settings.PAL ? APU_NUMERATOR_PAL : APU_NUMERATOR_NTSC;
    spc::ratio_denominator = Settings.PAL ? APU_DENOMINATOR_PAL : APU_DENOMINATOR_NTSC;
    spc::ratio_denominator = spc::ratio_denominator * spc::timing_hack_denominator / spc::timing_hack_numerator;

    UpdatePlaybackRate();
}

void S9xResetAPU(void)
{
    spc::reference_time = 0;
    spc::remainder = 0;

    SNES::cpu.reset();
    SNES::smp.power();
    SNES::dsp.power();
    SNES::dsp.spc_dsp.set_spc_snapshot_callback(SPCSnapshotCallback);

    S9xClearSamples();
}

void S9xSoftResetAPU(void)
{
    spc::reference_time = 0;
    spc::remainder = 0;
    SNES::cpu.reset();
    SNES::smp.reset();
    SNES::dsp.reset();

    S9xClearSamples();
}

void S9xAPUSaveState(uint8 *block)
{
    uint8 *ptr = block;

    SNES::smp.save_state(&ptr);
    SNES::dsp.save_state(&ptr);

    SNES::set_le32(ptr, spc::reference_time);
    ptr += sizeof(int32);
    SNES::set_le32(ptr, spc::remainder);
    ptr += sizeof(int32);
    SNES::set_le32(ptr, SNES::dsp.clock);
    ptr += sizeof(int32);
    memcpy(ptr, SNES::cpu.registers, 4);
    ptr += sizeof(int32);

    memset(ptr, 0, SPC_SAVE_STATE_BLOCK_SIZE - (ptr - block));
}

void S9xAPULoadState(uint8 *block)
{
    uint8 *ptr = block;

    SNES::smp.load_state(&ptr);
    SNES::dsp.load_state(&ptr);

    spc::reference_time = SNES::get_le32(ptr);
    ptr += sizeof(int32);
    spc::remainder = SNES::get_le32(ptr);
    ptr += sizeof(int32);
    SNES::dsp.clock = SNES::get_le32(ptr);
    ptr += sizeof(int32);
    memcpy(SNES::cpu.registers, ptr, 4);
}

static void to_var_from_buf(uint8 **buf, void *var, size_t size)
{
    memcpy(var, *buf, size);
    *buf += size;
}

#undef IF_0_THEN_256
#define IF_0_THEN_256(n) ((uint8)((n)-1) + 1)
void S9xAPULoadBlarggState(uint8 *oldblock)
{
    uint8 *ptr = oldblock;

    SNES::SPC_State_Copier copier(&ptr, to_var_from_buf);

    copier.copy(SNES::smp.apuram, 0x10000); // RAM

    uint8 regs_in[0x10];
    uint8 regs[0x10];
    uint16 pc, spc_time, dsp_time;
    uint8 a, x, y, psw, sp;

    copier.copy(regs, 0x10);    // REGS
    copier.copy(regs_in, 0x10); // REGS_IN

    // CPU Regs
    pc = copier.copy_int(0, sizeof(uint16));
    a = copier.copy_int(0, sizeof(uint8));
    x = copier.copy_int(0, sizeof(uint8));
    y = copier.copy_int(0, sizeof(uint8));
    psw = copier.copy_int(0, sizeof(uint8));
    sp = copier.copy_int(0, sizeof(uint8));
    copier.extra();

    // times
    spc_time = copier.copy_int(0, sizeof(uint16));
    dsp_time = copier.copy_int(0, sizeof(uint16));

    int cur_time = S9xAPUGetClock(CPU.Cycles);

    // spc_time is absolute, dsp_time is relative
    // smp.clock is relative, dsp.clock relative but counting upwards
    SNES::smp.clock = spc_time - cur_time;
    SNES::dsp.clock = -1 * dsp_time;

    // DSP
    SNES::dsp.load_state(&ptr);

    // Timers
    uint16 next_time[3];
    uint8 divider[3], counter[3];
    for (int i = 0; i < 3; i++)
    {
        next_time[i] = copier.copy_int(0, sizeof(uint16));
        divider[i] = copier.copy_int(0, sizeof(uint8));
        counter[i] = copier.copy_int(0, sizeof(uint8));
        copier.extra();
    }
    // construct timers out of available parts from blargg smp
    SNES::smp.timer0.enable = regs[1] >> 0 & 1;        // regs[1] = CONTROL
    SNES::smp.timer0.target = IF_0_THEN_256(regs[10]); // regs[10+i] = TiTARGET
    // blargg counts time, get ticks through timer frequency
    // (assume tempo = 256)
    SNES::smp.timer0.stage1_ticks = 128 - (next_time[0] - cur_time) / 128;
    SNES::smp.timer0.stage2_ticks = divider[0];
    SNES::smp.timer0.stage3_ticks = counter[0];

    SNES::smp.timer1.enable = regs[1] >> 1 & 1;
    SNES::smp.timer1.target = IF_0_THEN_256(regs[11]);
    SNES::smp.timer1.stage1_ticks = 128 - (next_time[1] - cur_time) / 128;
    SNES::smp.timer1.stage2_ticks = divider[0];
    SNES::smp.timer1.stage3_ticks = counter[0];

    SNES::smp.timer2.enable = regs[1] >> 2 & 1;
    SNES::smp.timer2.target = IF_0_THEN_256(regs[12]);
    SNES::smp.timer2.stage1_ticks = 16 - (next_time[2] - cur_time) / 16;
    SNES::smp.timer2.stage2_ticks = divider[0];
    SNES::smp.timer2.stage3_ticks = counter[0];

    copier.extra();

    SNES::smp.opcode_number = 0;
    SNES::smp.opcode_cycle = 0;

    SNES::smp.regs.pc = pc;
    SNES::smp.regs.sp = sp;
    SNES::smp.regs.B.a = a;
    SNES::smp.regs.x = x;
    SNES::smp.regs.B.y = y;

    // blargg's psw has same layout as byuu's flags
    SNES::smp.regs.p = psw;

    // blargg doesn't explicitly store iplrom_enable
    SNES::smp.status.iplrom_enable = regs[1] & 0x80;

    SNES::smp.status.dsp_addr = regs[2];

    SNES::smp.status.ram00f8 = regs_in[8];
    SNES::smp.status.ram00f9 = regs_in[9];

    // default to 0 - we are on an opcode boundary, shouldn't matter
    SNES::smp.rd = SNES::smp.wr = SNES::smp.dp = SNES::smp.sp = SNES::smp.ya = SNES::smp.bit = 0;

    spc::reference_time = SNES::get_le32(ptr);
    ptr += sizeof(int32);
    spc::remainder = SNES::get_le32(ptr);

    // blargg stores CPUIx in regs_in
    memcpy(SNES::cpu.registers, regs_in + 4, 4);
}

bool8 S9xSPCDump(const char *filename)
{
    FILE *fs;
    uint8 buf[SPC_FILE_SIZE];
    size_t ignore;

    fs = fopen(filename, "wb");
    if (!fs)
        return (FALSE);

    S9xSetSoundMute(TRUE);

    SNES::smp.save_spc(buf);

    ignore = fwrite(buf, SPC_FILE_SIZE, 1, fs);

    if (ignore == 0)
    {
        fprintf(stderr, "Couldn't write file %s.\n", filename);
    }

    fclose(fs);

    S9xSetSoundMute(FALSE);

    return (TRUE);
}
