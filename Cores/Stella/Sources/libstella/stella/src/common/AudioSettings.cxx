//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "AudioSettings.hxx"
#include "Settings.hxx"

namespace {
  constexpr uInt32 lboundInt(int x, int defaultValue)
  {
    return x <= 0 ? defaultValue : x;
  }

  constexpr AudioSettings::Preset normalizedPreset(int numericPreset)
  {
    return (
      numericPreset >= static_cast<int>(AudioSettings::Preset::custom) &&
      numericPreset <= static_cast<int>(AudioSettings::Preset::ultraQualityMinimalLag)
    ) ? static_cast<AudioSettings::Preset>(numericPreset) : AudioSettings::DEFAULT_PRESET;
  }

  constexpr AudioSettings::ResamplingQuality normalizeResamplingQuality(int numericResamplingQuality)
  {
    return (
      numericResamplingQuality >= static_cast<int>(AudioSettings::ResamplingQuality::nearestNeightbour) &&
      numericResamplingQuality <= static_cast<int>(AudioSettings::ResamplingQuality::lanczos_3)
    ) ? static_cast<AudioSettings::ResamplingQuality>(numericResamplingQuality) : AudioSettings::DEFAULT_RESAMPLING_QUALITY;
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AudioSettings::AudioSettings(Settings& settings)
  : mySettings{settings}
{
  setPreset(normalizedPreset(mySettings.getInt(SETTING_PRESET)));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::normalize(Settings& settings)
{
  const int settingPreset = settings.getInt(SETTING_PRESET);
  const Preset preset = normalizedPreset(settingPreset);
  if (static_cast<int>(preset) != settingPreset) settings.setValue(SETTING_PRESET, static_cast<int>(DEFAULT_PRESET));

  switch (settings.getInt(SETTING_SAMPLE_RATE)) {
    case 44100:
    case 48000:
    case 96000:
      break;

    default:
      settings.setValue(SETTING_SAMPLE_RATE, DEFAULT_SAMPLE_RATE);
      break;
  }

  switch (settings.getInt(SETTING_FRAGMENT_SIZE)) {
    case 128:
    case 256:
    case 512:
    case 1024:
    case 2048:
    case 4096:
      break;

    default:
      settings.setValue(SETTING_FRAGMENT_SIZE, DEFAULT_FRAGMENT_SIZE);
      break;
  }

  const int settingBufferSize = settings.getInt(SETTING_BUFFER_SIZE);
  if (settingBufferSize < 0 || settingBufferSize > MAX_BUFFER_SIZE) settings.setValue(SETTING_BUFFER_SIZE, DEFAULT_BUFFER_SIZE);

  const int settingHeadroom = settings.getInt(SETTING_HEADROOM);
  if (settingHeadroom < 0 || settingHeadroom > MAX_HEADROOM) settings.setValue(SETTING_HEADROOM, DEFAULT_HEADROOM);

  const int settingResamplingQuality = settings.getInt(SETTING_RESAMPLING_QUALITY);
  const ResamplingQuality resamplingQuality =
      normalizeResamplingQuality(settingResamplingQuality);
  if (static_cast<int>(resamplingQuality) != settingResamplingQuality)
    settings.setValue(SETTING_RESAMPLING_QUALITY, static_cast<int>(DEFAULT_RESAMPLING_QUALITY));

  const int settingVolume = settings.getInt(SETTING_VOLUME);
  if (settingVolume < 0 || settingVolume > 100) settings.setValue(SETTING_VOLUME, DEFAULT_VOLUME);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AudioSettings::Preset AudioSettings::preset()
{
  updatePresetFromSettings();
  return myPreset;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 AudioSettings::sampleRate()
{
  updatePresetFromSettings();
  return customSettings() ? lboundInt(mySettings.getInt(SETTING_SAMPLE_RATE), DEFAULT_SAMPLE_RATE) : myPresetSampleRate;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 AudioSettings::fragmentSize()
{
  updatePresetFromSettings();
  return customSettings() ? lboundInt(mySettings.getInt(SETTING_FRAGMENT_SIZE), DEFAULT_FRAGMENT_SIZE) : myPresetFragmentSize;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 AudioSettings::bufferSize()
{
  updatePresetFromSettings();
  // 0 is a valid value -> keep it
  return customSettings() ? lboundInt(mySettings.getInt(SETTING_BUFFER_SIZE), 0) : myPresetBufferSize;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 AudioSettings::headroom()
{
  updatePresetFromSettings();
  // 0 is a valid value -> keep it
  return customSettings() ? lboundInt(mySettings.getInt(SETTING_HEADROOM), 0) : myPresetHeadroom;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AudioSettings::ResamplingQuality AudioSettings::resamplingQuality()
{
  updatePresetFromSettings();
  return customSettings() ? normalizeResamplingQuality(mySettings.getInt(SETTING_RESAMPLING_QUALITY)) : myPresetResamplingQuality;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AudioSettings::stereo() const
{
  // 0 is a valid value -> keep it
  return mySettings.getBool(SETTING_STEREO);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 AudioSettings::volume() const
{
  // 0 is a valid value -> keep it
  return lboundInt(mySettings.getInt(SETTING_VOLUME), 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 AudioSettings::device() const
{
  return mySettings.getInt(SETTING_DEVICE);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AudioSettings::enabled() const
{
  return mySettings.getBool(SETTING_ENABLED);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 AudioSettings::dpcPitch() const
{
  return lboundInt(mySettings.getInt(SETTING_DPC_PITCH), 10000);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setPreset(AudioSettings::Preset preset)
{
  if (preset == myPreset) return;
  myPreset = preset;

  switch (myPreset) {
    case Preset::custom:
      break;

    case Preset::lowQualityMediumLag:
      myPresetSampleRate = 44100;
      myPresetFragmentSize = 1024;
      myPresetBufferSize = 6;
      myPresetHeadroom = 5;
      myPresetResamplingQuality = ResamplingQuality::nearestNeightbour;
      break;

    case Preset::highQualityMediumLag:
      myPresetSampleRate = 44100;
      myPresetFragmentSize = 1024;
      myPresetBufferSize = 6;
      myPresetHeadroom = 5;
      myPresetResamplingQuality = ResamplingQuality::lanczos_2;
      break;

    case Preset::highQualityLowLag:
      myPresetSampleRate = 48000;
      myPresetFragmentSize = 512;
      myPresetBufferSize = 3;
      myPresetHeadroom = 2;
      myPresetResamplingQuality = ResamplingQuality::lanczos_2;
      break;

    case Preset::ultraQualityMinimalLag:
      myPresetSampleRate = 96000;
      myPresetFragmentSize = 128;
      myPresetBufferSize = 0;
      myPresetHeadroom = 0;
      myPresetResamplingQuality = ResamplingQuality::lanczos_3;
      break;

    default:
      throw runtime_error("invalid preset");
  }

  if (myIsPersistent) mySettings.setValue(SETTING_PRESET, static_cast<int>(myPreset));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setSampleRate(uInt32 sampleRate)
{
  if (!myIsPersistent) return;

  mySettings.setValue(SETTING_SAMPLE_RATE, sampleRate);
  normalize(mySettings);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setFragmentSize(uInt32 fragmentSize)
{
  if (!myIsPersistent) return;

  mySettings.setValue(SETTING_FRAGMENT_SIZE, fragmentSize);
  normalize(mySettings);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setBufferSize(uInt32 bufferSize)
{
  if (!myIsPersistent) return;

  mySettings.setValue(SETTING_BUFFER_SIZE, bufferSize);
  normalize(mySettings);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setHeadroom(uInt32 headroom)
{
  if (!myIsPersistent) return;

  mySettings.setValue(SETTING_HEADROOM, headroom);
  normalize(mySettings);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setResamplingQuality(AudioSettings::ResamplingQuality resamplingQuality)
{
  if (!myIsPersistent) return;

  mySettings.setValue(SETTING_RESAMPLING_QUALITY, static_cast<int>(resamplingQuality));
  normalize(mySettings);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setStereo(bool allROMs)
{
  if(!myIsPersistent) return;

  mySettings.setValue(SETTING_STEREO, allROMs);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setDpcPitch(uInt32 pitch)
{
  if (!myIsPersistent) return;

  mySettings.setValue(SETTING_DPC_PITCH, pitch);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setVolume(uInt32 volume)
{
  if (!myIsPersistent) return;

  mySettings.setValue(SETTING_VOLUME, volume);
  normalize(mySettings);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setDevice(uInt32 device)
{
  if(!myIsPersistent) return;

  mySettings.setValue(SETTING_DEVICE, device);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setEnabled(bool isEnabled)
{
  if (!myIsPersistent) return;

  mySettings.setValue(SETTING_ENABLED, isEnabled);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::setPersistent(bool isPersistent)
{
  myIsPersistent = isPersistent;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AudioSettings::customSettings() const
{
  return myPreset == Preset::custom;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioSettings::updatePresetFromSettings()
{
  if (!myIsPersistent) return;

  setPreset(normalizedPreset(mySettings.getInt(SETTING_PRESET)));
}
