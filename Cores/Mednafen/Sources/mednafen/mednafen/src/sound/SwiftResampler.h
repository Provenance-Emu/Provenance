#ifndef __MDFN_SOUND_SWIFTRESAMPLER_H
#define __MDFN_SOUND_SWIFTRESAMPLER_H

namespace Mednafen
{

//
// Read the notes at the top of SwiftResampler.cpp before using.
//
class SwiftResampler
{
	public:

	enum { MaxLeftover = 1536 };
	enum { MaxWaveOverRead = 16 };	// SSE2

	// Resamples from input_rate to output_rate, allowing for rate_error(output_rate +/- output_rate*rate_error)
	// error in the resample ratio.
	//
	// hp_tc is the time constant(in seconds) for the DC bias removal highpass filter.
	// Higher values will result in more bias removal(and cause a high-pass filter effect), while lower values will lower this effect.
	// Values lower than 200e-6, other than 0, may cause assert()'s to be triggered at some output rates due to overflow issues.
	// A value of 0 will disable it entirely.
	//
	// quality is an arbitrary control of quality(-2 for lowest quality, 3 for highest quality)
	SwiftResampler(double input_rate, double output_rate, double rate_error, double hp_tc, int quality) MDFN_COLD;
	SwiftResampler(const SwiftResampler &resamp) MDFN_COLD;
	~SwiftResampler() MDFN_COLD;

	// Specify volume in percent amplitude(range 0 through 1.000..., inclusive).  Default: SetVolume(1.0);
	void SetVolume(double newvolume);

	// Resamples "inlen" samples from "in", writing the output "out", generating no more output samples than "maxoutlen".
	// The int32 pointed to by leftover is set to the number of input samples left over from this filter iteration.
	// "in" should be aligned to a 16-byte boundary, for the SIMD versions of the filter to work properly.  "out" doesn't have any
	// special alignment requirement.
	INLINE int32 Do(int16 *in, int16 *out, uint32 maxoutlen, uint32 inlen, int32 *leftover)
	{
	 return (this->*SwiftResampler::Resample_)(in, out, maxoutlen, inlen, leftover);
	}

	// Get the InputRate / OutputRate ratio, expressed as a / b
	INLINE void GetRatio(int32 *a, int32 *b)
	{
	 *a = Ratio_Dividend;
	 *b = Ratio_Divisor;
	}

	INLINE const char* GetSIMDType(void)
	{
	 return SIMDTypeString;
	}
	private:

	// Copy of the parameters passed to the constructor
	double InputRate, OutputRate, RateError;
	int Quality;

        // Number of phases.
        uint32 NumPhases;
	uint32 NumPhases_Padded;

	// Coefficients(in each phase, not total)
	uint32 NumCoeffs;
	uint32 NumCoeffs_Padded;

	uint32 NumAlignments;

	// Index into the input buffer
	uint32 InputIndex;

	// Current input phase
	uint32 InputPhase;

	// In the FIR loop:  InputPhase = PhaseNext[InputPhase]
	std::unique_ptr<uint32[]> PhaseNext;

	// Incrementor for InputIndex.  In the FIR loop, after updating InputPhase:  InputIndex += PhaseStep[InputPhase]
	std::unique_ptr<uint32[]> PhaseStep;

	// One pointer for each phase in each possible alignment
	std::unique_ptr<int16*[]> FIR_Coeffs;

	#define FIR_ENTRY(align, phase, coco) FIR_Coeffs[(phase) * NumAlignments + align][coco]

	// Coefficient counts for the 4 alignments
	std::unique_ptr<uint32[]> FIR_CoCounts;

	int32 SoundVolume;
	std::vector<int16> CoeffsBuffer;
	std::vector<int32> IntermediateBuffer;

	enum
	{
	 SIMD_NONE,
	 SIMD_MMX,
	 SIMD_SSE2,
	 SIMD_SSE2_INTRIN,
	 SIMD_ALTIVEC,
	 SIMD_NEON
	};

	int32 debias;
	int32 debias_multiplier;

	// for GetRatio()
	int32 Ratio_Dividend;
	int32 Ratio_Divisor;

	//
	//
	//
	template<size_t align_mask = 0>
	uint32 ResampLoop(int16* in, int32* out, uint32 max, void (*MAC_Function)(const int16* wave, const int16* coeffs, int32 count, int32* accum_output));

	template<unsigned TA_SIMD_Type, unsigned TA_NumFractBits>
	int32 T_Resample(int16 *in, int16 *out, uint32 maxoutlen, uint32 inlen, int32 *leftover);

	int32 (SwiftResampler::*Resample_)(int16 *in, int16 *out, uint32 maxoutlen, uint32 inlen, int32 *leftover);
	const char* SIMDTypeString;
};

}
#endif
