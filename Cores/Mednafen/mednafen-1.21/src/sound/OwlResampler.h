#ifndef __MDFN_SOUND_OWLRESAMPLER_H
#define __MDFN_SOUND_OWLRESAMPLER_H

class OwlResampler;
class RavenBuffer;

struct StateMem;

class OwlBuffer
{
 public:

 enum { HRBUF_LEFTOVER_PADDING = 8192 };
 enum { HRBUF_OVERFLOW_PADDING =   32 }; // For deltas and impulse responses and whatnot that are dangling off the end(>= final timestamp) sorta.

 union I32_F_Pudding
 {
  int32 i32;
  float f;
 };

 OwlBuffer();
 ~OwlBuffer();

 INLINE int32* Buf(void)
 {
  return &HRBuf[HRBUF_LEFTOVER_PADDING].i32;
 }

 INLINE I32_F_Pudding* BufPudding(void)
 {
  return &HRBuf[HRBUF_LEFTOVER_PADDING];
 }

 void Integrate(unsigned count, unsigned lp_shift = 0, unsigned hp_shift = 0, RavenBuffer* mixin0 = NULL, RavenBuffer* mixin1 = NULL);	// Convenience function.
 void ResampleSkipped(unsigned count);

 void ZeroLeftover(void);

 void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix, const unsigned scount);

 private:

 I32_F_Pudding HRBuf[HRBUF_LEFTOVER_PADDING + 65536 + HRBUF_OVERFLOW_PADDING];
 int32 accum;
 int64 filter_state[2];

 //
 // Resampler state:
 //
 int32 leftover;

 // Index into the input buffer
 uint32 InputIndex;

 // Current input phase
 uint32 InputPhase;

 // DC bias removal filter thingy
 int64 debias;

 friend class OwlResampler;
};

class RavenBuffer
{
 public:

 RavenBuffer();
 ~RavenBuffer();

 INLINE int32* Buf(void)
 {
  return &BB[0];
 }

 void Process(unsigned count, bool integrate = true, uint32 lp_shift = 0);
 void Finish(unsigned count);

 friend class OwlBuffer;

 private:
 int32 BB[65536 + OwlBuffer::HRBUF_OVERFLOW_PADDING];
 int32 accum;
 int64 filter_state[2];
};

class OwlResampler
{
	public:

	// Resamples from input_rate to output_rate, allowing for rate_error(output_rate +/- output_rate*rate_error)
	// error in the resample ratio.
	//
	// debias_corner is the cheap high-pass DC bias removal filter coefficient.  Higher values will result in more bias removal(and
	// case a high-pass filter effect), while lower values will lower this effect.  It should be <= output_rate / 64, to be on the safe side(prevent
	// multiplication overflow).  A value of 0 will disable its effect.
	//
	// quality is an arbitrary control of quality(0 for lowest quality, 5 for highest quality)
	//
        // nyq_fudge may be a tasty sleep drug.
	//
	OwlResampler(double input_rate, double output_rate, double rate_error, double debias_corner, int quality, double nyq_fudge = 1.0) MDFN_COLD;
	OwlResampler(const OwlResampler &resamp) MDFN_COLD;
	~OwlResampler() MDFN_COLD;

	INLINE int32 Resample(OwlBuffer* in, const uint32 in_count, int16* out, const uint32 max_out_count, const bool reverse = false)
	{
	 return (this->*OwlResampler::Resample_)(in, in_count, out, max_out_count, reverse);
	}
	void ResetBufResampState(OwlBuffer* buf);

	// Get the InputRate / OutputRate ratio, expressed as a / b
	void GetRatio(int32 *a, int32 *b)
	{
	 *a = Ratio_Dividend;
	 *b = Ratio_Divisor;
	}

	private:

	// Copy of the parameters passed to the constructor
	double InputRate, OutputRate, RateError, DebiasCorner;
	int Quality;

        // Number of phases.
        uint32 NumPhases;
	uint32 NumPhases_Padded;

	// Coefficients(in each phase, not total)
	uint32 NumCoeffs;

	struct PhaseInfo
	{
	 // One pointer for each phase
	 float* Coeffs;

	 // In the FIR loop:  InputPhase = PInfos[InputPhase].Next
	 uint32 Next;

	 // Incrementor for InputIndex.  In the FIR loop, after updating InputPhase:  InputIndex += PInfos[InputPhase].Step
	 uint32 Step;
	};

	std::vector<PhaseInfo> PInfos;
	std::vector<float> CoeffsBuffer;
	std::vector<int32> IntermediateBuffer; //int32 boobuf[8192];

	template<unsigned TA_SIMD_Type>
	int32 T_Resample(OwlBuffer* in, const uint32 in_count, int16* out, const uint32 max_out_count, const bool reverse);
	int32 (OwlResampler::*Resample_)(OwlBuffer* in, const uint32 in_count, int16* out, const uint32 max_out_count, const bool reverse);

	uint16 debias_multiplier;

	// for GetRatio()
	int32 Ratio_Dividend;
	int32 Ratio_Divisor;
};
#endif
