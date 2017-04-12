#ifndef _PCEFast_PSG_H
#define _PCEFast_PSG_H

#include <mednafen/sound/Blip_Buffer.h>

namespace PCE_Fast
{

class PCEFast_PSG;

struct psg_channel
{
        uint8 waveform[32];     /* Waveform data */
        uint8 waveform_index;   /* Waveform data index */
        uint8 dda;
        uint8 control;          /* Channel enable, DDA, volume */
        uint8 noisectrl;        /* Noise enable/ctrl (channels 4,5 only) */

        int32 vl[2];    //vll, vlr;

        int32 counter;

        void (PCEFast_PSG::*UpdateOutput)(const int32 timestamp, psg_channel *ch);

        uint32 freq_cache;
        uint32 noise_freq_cache;        // Channel 4,5 only
        int32 noisecount;
        uint32 lfsr;

        int32 samp_accum;         // The result of adding up all the samples in the waveform buffer(part of an optimization for high-frequency playback).
        int32 blip_prev_samp[2];
        int32 lastts;

        uint16 frequency;       /* Channel frequency */
        uint8 balance;          /* Channel balance */
};

class PCEFast_PSG
{
        public:

        PCEFast_PSG(Blip_Buffer* bbs) MDFN_COLD;
        ~PCEFast_PSG() MDFN_COLD;

	int StateAction(StateMem *sm, int load, int data_only) MDFN_COLD;

        void Power(const int32 timestamp) MDFN_COLD;
        void Write(int32 timestamp, uint8 A, uint8 V);

	void SetVolume(double new_volume) MDFN_COLD;

	void EndFrame(int32 timestamp);

        private:

	void Update(int32 timestamp);

	void UpdateSubLFO(int32 timestamp);
	void UpdateSubNonLFO(int32 timestamp);

	void RecalcUOFunc(int chnum);
	void UpdateOutput_Off(const int32 timestamp, psg_channel *ch);
	void UpdateOutput_Accum(const int32 timestamp, psg_channel *ch);
        void UpdateOutput_Norm(const int32 timestamp, psg_channel *ch);
        void UpdateOutput_Noise(const int32 timestamp, psg_channel *ch);

	int32 GetVL(const int chnum, const int lr);

	void RecalcFreqCache(int chnum);
	void RecalcNoiseFreqCache(int chnum);
	template<bool LFO_On>
	void RunChannel(int chc, int32 timestamp);
	double OutputVolume;

        uint8 select;               /* Selected channel (0-5) */
        uint8 globalbalance;        /* Global sound balance */
        uint8 lfofreq;              /* LFO frequency */
        uint8 lfoctrl;              /* LFO control */

        int32 vol_update_counter;
        int32 vol_update_which;
	int32 vol_update_vllatch;
	bool vol_pending;

        psg_channel channel[6];

        int32 lastts;

	Blip_Buffer* const sbuf;
	Blip_Synth<blip_good_quality, 8192> Synth;

        int32 dbtable_volonly[32];

	int32 dbtable[32][32];
};

}

#endif
