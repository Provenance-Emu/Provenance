// Copyright 2008 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#include "AudioCommon/Mixer.h"
#include "AudioCommon/Enums.h"

#include <algorithm>
#include <cmath>
#include <cstring>

#include "Common/ChunkFile.h"
#include "Common/CommonTypes.h"
#include "Common/Logging/Log.h"
#include "Common/Swap.h"
#include "Core/Config/MainSettings.h"
#include "Core/ConfigManager.h"

static u32 DPL2QualityToFrameBlockSize(AudioCommon::DPL2Quality quality)
{
  switch (quality)
  {
  case AudioCommon::DPL2Quality::Low:
    return 512;
  case AudioCommon::DPL2Quality::Medium:
    return 1024;
  case AudioCommon::DPL2Quality::Highest:
    return 4096;
  default:
    return 2048;
  }
}

Mixer::Mixer(unsigned int BackendSampleRate)
    : m_sampleRate(BackendSampleRate), m_stretcher(BackendSampleRate),
      m_surround_decoder(BackendSampleRate,
                         DPL2QualityToFrameBlockSize(Config::Get(Config::MAIN_DPL2_QUALITY)))
{
  INFO_LOG_FMT(AUDIO_INTERFACE, "Mixer is initialized");
}

Mixer::~Mixer()
{
}

void Mixer::DoState(PointerWrap& p)
{
  m_dma_mixer.DoState(p);
  m_streaming_mixer.DoState(p);
  m_wiimote_speaker_mixer.DoState(p);
}

// Executed from sound stream thread
unsigned int Mixer::MixerFifo::Mix(short* samples, unsigned int numSamples,
                                   bool consider_framelimit)
{
  unsigned int currentSample = 0;

  // Cache access in non-volatile variable
  // This is the only function changing the read value, so it's safe to
  // cache it locally although it's written here.
  // The writing pointer will be modified outside, but it will only increase,
  // so we will just ignore new written data while interpolating.
  // Without this cache, the compiler wouldn't be allowed to optimize the
  // interpolation loop.
  u32 indexR = m_indexR.load();
  u32 indexW = m_indexW.load();

  // render numleft sample pairs to samples[]
  // advance indexR with sample position
  // remember fractional offset

  float emulationspeed = SConfig::GetInstance().m_EmulationSpeed;
  float aid_sample_rate = static_cast<float>(m_input_sample_rate);
  if (consider_framelimit && emulationspeed > 0.0f)
  {
    float numLeft = static_cast<float>(((indexW - indexR) & INDEX_MASK) / 2);

    u32 low_waterwark = m_input_sample_rate * SConfig::GetInstance().iTimingVariance / 1000;
    low_waterwark = std::min(low_waterwark, MAX_SAMPLES / 2);

    m_numLeftI = (numLeft + m_numLeftI * (CONTROL_AVG - 1)) / CONTROL_AVG;
    float offset = (m_numLeftI - low_waterwark) * CONTROL_FACTOR;
    if (offset > MAX_FREQ_SHIFT)
      offset = MAX_FREQ_SHIFT;
    if (offset < -MAX_FREQ_SHIFT)
      offset = -MAX_FREQ_SHIFT;

    aid_sample_rate = (aid_sample_rate + offset) * emulationspeed;
  }

  const u32 ratio = (u32)(65536.0f * aid_sample_rate / (float)m_mixer->m_sampleRate);

  s32 lvolume = SConfig::GetInstance().m_Volume;
  s32 rvolume = SConfig::GetInstance().m_Volume;

  // TODO: consider a higher-quality resampling algorithm.
  for (; currentSample < numSamples * 2 && ((indexW - indexR) & INDEX_MASK) > 2; currentSample += 2)
  {
    u32 indexR2 = indexR + 2;  // next sample

    s16 l1 = Common::swap16(m_buffer[indexR & INDEX_MASK]);   // current
    s16 l2 = Common::swap16(m_buffer[indexR2 & INDEX_MASK]);  // next
    int sampleL = ((l1 << 16) + (l2 - l1) * (u16)m_frac) >> 16;
    sampleL = (sampleL * lvolume) >> 8;
    sampleL += samples[currentSample + 1];
    samples[currentSample + 1] = std::clamp(sampleL, -32767, 32767);

    s16 r1 = Common::swap16(m_buffer[(indexR + 1) & INDEX_MASK]);   // current
    s16 r2 = Common::swap16(m_buffer[(indexR2 + 1) & INDEX_MASK]);  // next
    int sampleR = ((r1 << 16) + (r2 - r1) * (u16)m_frac) >> 16;
    sampleR = (sampleR * rvolume) >> 8;
    sampleR += samples[currentSample];
    samples[currentSample] = std::clamp(sampleR, -32767, 32767);

    m_frac += ratio;
    indexR += 2 * (u16)(m_frac >> 16);
    m_frac &= 0xffff;
  }

  // Actual number of samples written to the buffer without padding.
  unsigned int actual_sample_count = currentSample / 2;

  // Padding
  short s[2];
  s[0] = Common::swap16(m_buffer[(indexR - 1) & INDEX_MASK]);
  s[1] = Common::swap16(m_buffer[(indexR - 2) & INDEX_MASK]);
  s[0] = (s[0] * rvolume) >> 8;
  s[1] = (s[1] * lvolume) >> 8;
  for (; currentSample < numSamples * 2; currentSample += 2)
  {
    int sampleR = std::clamp(s[0] + samples[currentSample + 0], -32767, 32767);
    int sampleL = std::clamp(s[1] + samples[currentSample + 1], -32767, 32767);

    samples[currentSample + 0] = sampleR;
    samples[currentSample + 1] = sampleL;
  }

  // Flush cached variable
  m_indexR.store(indexR);

  return actual_sample_count;
}

unsigned int Mixer::Mix(short* samples, unsigned int num_samples)
{
  if (!samples)
    return 0;

  memset(samples, 0, num_samples * 2 * sizeof(short));

  if (SConfig::GetInstance().m_audio_stretch)
  {
    unsigned int available_samples =
        std::min(m_dma_mixer.AvailableSamples(), m_streaming_mixer.AvailableSamples());

    m_scratch_buffer.fill(0);

    m_dma_mixer.Mix(m_scratch_buffer.data(), available_samples, false);
    m_streaming_mixer.Mix(m_scratch_buffer.data(), available_samples, false);
    m_wiimote_speaker_mixer.Mix(m_scratch_buffer.data(), available_samples, false);

    if (!m_is_stretching)
    {
      m_stretcher.Clear();
      m_is_stretching = true;
    }
    m_stretcher.ProcessSamples(m_scratch_buffer.data(), available_samples, num_samples);
    m_stretcher.GetStretchedSamples(samples, num_samples);
  }
  else
  {
    m_dma_mixer.Mix(samples, num_samples, true);
    m_streaming_mixer.Mix(samples, num_samples, true);
    m_wiimote_speaker_mixer.Mix(samples, num_samples, true);
    m_is_stretching = false;
  }

  return num_samples;
}

unsigned int Mixer::MixSurround(float* samples, unsigned int num_samples)
{
  if (!num_samples)
    return 0;

  memset(samples, 0, num_samples * SURROUND_CHANNELS * sizeof(float));

  size_t needed_frames = m_surround_decoder.QueryFramesNeededForSurroundOutput(num_samples);

  // Mix() may also use m_scratch_buffer internally, but is safe because it alternates reads
  // and writes.
  size_t available_frames = Mix(m_scratch_buffer.data(), static_cast<u32>(needed_frames));
  if (available_frames != needed_frames)
  {
    ERROR_LOG_FMT(AUDIO, "Error decoding surround frames.");
    return 0;
  }

  m_surround_decoder.PutFrames(m_scratch_buffer.data(), needed_frames);
  m_surround_decoder.ReceiveFrames(samples, num_samples);

  return num_samples;
}

void Mixer::MixerFifo::PushSamples(const short* samples, unsigned int num_samples)
{
  // Cache access in non-volatile variable
  // indexR isn't allowed to cache in the audio throttling loop as it
  // needs to get updates to not deadlock.
  u32 indexW = m_indexW.load();

  // Check if we have enough free space
  // indexW == m_indexR results in empty buffer, so indexR must always be smaller than indexW
  if (num_samples * 2 + ((indexW - m_indexR.load()) & INDEX_MASK) >= MAX_SAMPLES * 2)
    return;

  // AyuanX: Actual re-sampling work has been moved to sound thread
  // to alleviate the workload on main thread
  // and we simply store raw data here to make fast mem copy
  int over_bytes = num_samples * 4 - (MAX_SAMPLES * 2 - (indexW & INDEX_MASK)) * sizeof(short);
  if (over_bytes > 0)
  {
    memcpy(&m_buffer[indexW & INDEX_MASK], samples, num_samples * 4 - over_bytes);
    memcpy(&m_buffer[0], samples + (num_samples * 4 - over_bytes) / sizeof(short), over_bytes);
  }
  else
  {
    memcpy(&m_buffer[indexW & INDEX_MASK], samples, num_samples * 4);
  }

  m_indexW.fetch_add(num_samples * 2);
}

void Mixer::PushSamples(const short* samples, unsigned int num_samples)
{
  m_dma_mixer.PushSamples(samples, num_samples);
  int sample_rate = m_dma_mixer.GetInputSampleRate();
  if (m_log_dsp_audio)
    m_wave_writer_dsp.AddStereoSamplesBE(samples, num_samples, sample_rate);
}

void Mixer::PushStreamingSamples(const short* samples, unsigned int num_samples)
{
  m_streaming_mixer.PushSamples(samples, num_samples);
  int sample_rate = m_streaming_mixer.GetInputSampleRate();
  if (m_log_dtk_audio)
    m_wave_writer_dtk.AddStereoSamplesBE(samples, num_samples, sample_rate);
}

void Mixer::PushWiimoteSpeakerSamples(const short* samples, unsigned int num_samples,
                                      unsigned int sample_rate)
{
  short samples_stereo[MAX_SAMPLES * 2];

  if (num_samples < MAX_SAMPLES)
  {
    m_wiimote_speaker_mixer.SetInputSampleRate(sample_rate);

    for (unsigned int i = 0; i < num_samples; ++i)
    {
      samples_stereo[i * 2] = Common::swap16(samples[i]);
      samples_stereo[i * 2 + 1] = Common::swap16(samples[i]);
    }

    m_wiimote_speaker_mixer.PushSamples(samples_stereo, num_samples);
  }
}

void Mixer::SetDMAInputSampleRate(unsigned int rate)
{
  m_dma_mixer.SetInputSampleRate(rate);
}

void Mixer::SetStreamInputSampleRate(unsigned int rate)
{
  m_streaming_mixer.SetInputSampleRate(rate);
}

void Mixer::SetStreamingVolume(unsigned int lvolume, unsigned int rvolume)
{
    m_streaming_mixer.SetVolume(lvolume, rvolume);
}

void Mixer::SetWiimoteSpeakerVolume(unsigned int lvolume, unsigned int rvolume)
{
  m_wiimote_speaker_mixer.SetVolume(lvolume, rvolume);
}

void Mixer::StartLogDTKAudio(const std::string& filename)
{
  if (!m_log_dtk_audio)
  {
    bool success = m_wave_writer_dtk.Start(filename, m_streaming_mixer.GetInputSampleRate());
    if (success)
    {
      m_log_dtk_audio = true;
      m_wave_writer_dtk.SetSkipSilence(false);
      NOTICE_LOG_FMT(AUDIO, "Starting DTK Audio logging");
    }
    else
    {
      m_wave_writer_dtk.Stop();
      NOTICE_LOG_FMT(AUDIO, "Unable to start DTK Audio logging");
    }
  }
  else
  {
    WARN_LOG_FMT(AUDIO, "DTK Audio logging has already been started");
  }
}

void Mixer::StopLogDTKAudio()
{
  if (m_log_dtk_audio)
  {
    m_log_dtk_audio = false;
    m_wave_writer_dtk.Stop();
    NOTICE_LOG_FMT(AUDIO, "Stopping DTK Audio logging");
  }
  else
  {
    WARN_LOG_FMT(AUDIO, "DTK Audio logging has already been stopped");
  }
}

void Mixer::StartLogDSPAudio(const std::string& filename)
{
  if (!m_log_dsp_audio)
  {
    bool success = m_wave_writer_dsp.Start(filename, m_dma_mixer.GetInputSampleRate());
    if (success)
    {
      m_log_dsp_audio = true;
      m_wave_writer_dsp.SetSkipSilence(false);
      NOTICE_LOG_FMT(AUDIO, "Starting DSP Audio logging");
    }
    else
    {
      m_wave_writer_dsp.Stop();
      NOTICE_LOG_FMT(AUDIO, "Unable to start DSP Audio logging");
    }
  }
  else
  {
    WARN_LOG_FMT(AUDIO, "DSP Audio logging has already been started");
  }
}

void Mixer::StopLogDSPAudio()
{
  if (m_log_dsp_audio)
  {
    m_log_dsp_audio = false;
    m_wave_writer_dsp.Stop();
    NOTICE_LOG_FMT(AUDIO, "Stopping DSP Audio logging");
  }
  else
  {
    WARN_LOG_FMT(AUDIO, "DSP Audio logging has already been stopped");
  }
}

void Mixer::MixerFifo::DoState(PointerWrap& p)
{
  p.Do(m_input_sample_rate);
  p.Do(m_LVolume);
  p.Do(m_RVolume);
}

void Mixer::MixerFifo::SetInputSampleRate(unsigned int rate)
{
  m_input_sample_rate = rate;
}

unsigned int Mixer::MixerFifo::GetInputSampleRate() const
{
  return m_input_sample_rate;
}

void Mixer::MixerFifo::SetVolume(unsigned int lvolume, unsigned int rvolume)
{
  m_LVolume.store(lvolume + (lvolume >> 7));
  m_RVolume.store(rvolume + (rvolume >> 7));
}

unsigned int Mixer::MixerFifo::AvailableSamples() const
{
  unsigned int samples_in_fifo = ((m_indexW.load() - m_indexR.load()) & INDEX_MASK) / 2;
  if (samples_in_fifo <= 1)
    return 0;  // Mixer::MixerFifo::Mix always keeps one sample in the buffer.
  return (samples_in_fifo - 1) * m_mixer->m_sampleRate / m_input_sample_rate;
}
