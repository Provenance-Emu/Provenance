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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifdef SOUND_SUPPORT

#include <sstream>
#include <cassert>
#include <cmath>

#include "SDL_lib.hxx"
#include "Logger.hxx"
#include "FrameBuffer.hxx"
#include "Settings.hxx"
#include "System.hxx"
#include "OSystem.hxx"
#include "Console.hxx"
#include "SoundSDL2.hxx"
#include "AudioQueue.hxx"
#include "EmulationTiming.hxx"
#include "AudioSettings.hxx"
#include "audio/SimpleResampler.hxx"
#include "audio/LanczosResampler.hxx"
#include "StaggeredLogger.hxx"

#include "ThreadDebugging.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SoundSDL2::SoundSDL2(OSystem& osystem, AudioSettings& audioSettings)
  : Sound{osystem},
    myAudioSettings{audioSettings}
{
  ASSERT_MAIN_THREAD;

  Logger::debug("SoundSDL2::SoundSDL2 started ...");

  if (SDL_InitSubSystem(SDL_INIT_AUDIO) < 0) {
    ostringstream buf;

    buf << "WARNING: Failed to initialize SDL audio system! " << endl
        << "         " << SDL_GetError() << endl;
    Logger::error(buf.str());
    return;
  }

  queryHardware(myDevices);

  SDL_zero(myHardwareSpec);
  if(!openDevice())
    return;

  SoundSDL2::mute(true);

  Logger::debug("SoundSDL2::SoundSDL2 initialized");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SoundSDL2::~SoundSDL2()
{
  ASSERT_MAIN_THREAD;

  if (!myIsInitializedFlag) return;

  SDL_CloseAudioDevice(myDevice);
  SDL_QuitSubSystem(SDL_INIT_AUDIO);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundSDL2::queryHardware(VariantList& devices)
{
  ASSERT_MAIN_THREAD;

  const int numDevices = SDL_GetNumAudioDevices(0);

  // log the available audio devices
  ostringstream s;
  s << "Supported audio devices (" << numDevices << "):";
  Logger::debug(s.str());

  VarList::push_back(devices, "Default", 0);
  for(int i = 0; i < numDevices; ++i) {
    ostringstream ss;

    ss << "  " << i + 1 << ": " << SDL_GetAudioDeviceName(i, 0);
    Logger::debug(ss.str());

    VarList::push_back(devices, SDL_GetAudioDeviceName(i, 0), i + 1);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SoundSDL2::openDevice()
{
  ASSERT_MAIN_THREAD;

  SDL_AudioSpec desired;
  desired.freq   = myAudioSettings.sampleRate();
  desired.format = AUDIO_F32SYS;
  desired.channels = 2;
  desired.samples  = static_cast<Uint16>(myAudioSettings.fragmentSize());
  desired.callback = callback;
  desired.userdata = this;

  if(myIsInitializedFlag)
    SDL_CloseAudioDevice(myDevice);

  myDeviceId = BSPF::clamp(myAudioSettings.device(), 0U, static_cast<uInt32>(myDevices.size() - 1));
  const char* device = myDeviceId ? myDevices.at(myDeviceId).first.c_str() : nullptr;

  myDevice = SDL_OpenAudioDevice(device, 0, &desired, &myHardwareSpec,
                                 SDL_AUDIO_ALLOW_FREQUENCY_CHANGE);

  if(myDevice == 0)
  {
    ostringstream buf;

    buf << "WARNING: Couldn't open SDL audio device! " << endl
        << "         " << SDL_GetError() << endl;
    Logger::error(buf.str());

    return myIsInitializedFlag = false;
  }
  return myIsInitializedFlag = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundSDL2::setEnabled(bool state)
{
  myAudioSettings.setEnabled(state);
  if (myAudioQueue) myAudioQueue->ignoreOverflows(!state);

  Logger::debug(state ? "SoundSDL2::setEnabled(true)" :
                "SoundSDL2::setEnabled(false)");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundSDL2::open(shared_ptr<AudioQueue> audioQueue,
                     EmulationTiming* emulationTiming)
{
  string pre_about = myAboutString;

  // Do we need to re-open the sound device?
  // Only do this when absolutely necessary
  if(myAudioSettings.sampleRate() != static_cast<uInt32>(myHardwareSpec.freq) ||
     myAudioSettings.fragmentSize() != static_cast<uInt32>(myHardwareSpec.samples) ||
     myAudioSettings.device() != myDeviceId)
    openDevice();

  myEmulationTiming = emulationTiming;

  Logger::debug("SoundSDL2::open started ...");
  mute(true);

  audioQueue->ignoreOverflows(!myAudioSettings.enabled());
  if(!myAudioSettings.enabled())
  {
    Logger::info("Sound disabled\n");
    return;
  }

  myAudioQueue = audioQueue;
  myUnderrun = true;
  myCurrentFragment = nullptr;

  // Adjust volume to that defined in settings
  setVolume(myAudioSettings.volume());

  initResampler();

  // Show some info
  myAboutString = about();
  if(myAboutString != pre_about)
    Logger::info(myAboutString);

  // And start the SDL sound subsystem ...
  mute(false);

  Logger::debug("SoundSDL2::open finished");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundSDL2::close()
{
  if(!myIsInitializedFlag) return;

  mute(true);

  if (myAudioQueue) myAudioQueue->closeSink(myCurrentFragment);
  myAudioQueue.reset();
  myCurrentFragment = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SoundSDL2::mute(bool state)
{
  const bool oldstate = SDL_GetAudioDeviceStatus(myDevice) == SDL_AUDIO_PAUSED;
  if(myIsInitializedFlag)
    SDL_PauseAudioDevice(myDevice, state ? 1 : 0);

  return oldstate;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SoundSDL2::toggleMute()
{
  const bool enabled = !myAudioSettings.enabled();

  setEnabled(enabled);
  myOSystem.console().initializeAudio();

  string message = "Sound ";
  message += enabled ? "unmuted" : "muted";

  myOSystem.frameBuffer().showTextMessage(message);

  //ostringstream strval;
  //uInt32 volume;
  //// Now show an onscreen message
  //if(enabled)
  //{
  //  volume = myVolume;
  //  strval << volume << "%";
  //}
  //else
  //{
  //  volume = 0;
  //  strval << "Muted";
  //}
  //myOSystem.frameBuffer().showMessage("Volume", strval.str(), volume);

  return enabled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundSDL2::setVolume(uInt32 percent)
{
  if(myIsInitializedFlag && (percent <= 100))
  {
    myAudioSettings.setVolume(percent);
    myVolume = percent;

    SDL_LockAudioDevice(myDevice);
    myVolumeFactor = static_cast<float>(percent) / 100.F;
    SDL_UnlockAudioDevice(myDevice);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundSDL2::adjustVolume(int direction)
{
  ostringstream strval;
  Int32 percent = myVolume;

  percent = BSPF::clamp(percent + direction * 2, 0, 100);

  setVolume(percent);

  // Enable audio if it is currently disabled
  const bool enabled = myAudioSettings.enabled();

  if(percent > 0 && !enabled)
  {
    setEnabled(true);
    myOSystem.console().initializeAudio();
  }

  // Now show an onscreen message
  if(percent)
    strval << percent << "%";
  else
    strval << "Off";
  myOSystem.frameBuffer().showGaugeMessage("Volume", strval.str(), percent);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string SoundSDL2::about() const
{
  ostringstream buf;
  buf << "Sound enabled:"  << endl
      << "  Volume:   " << myVolume << "%" << endl
      << "  Device:   " << myDevices.at(myDeviceId).first << endl
      << "  Channels: " << static_cast<uInt32>(myHardwareSpec.channels)
      << (myAudioQueue->isStereo() ? " (Stereo)" : " (Mono)") << endl
      << "  Preset:   ";
  switch (myAudioSettings.preset()) {
    case AudioSettings::Preset::custom:
      buf << "Custom" << endl;
      break;
    case AudioSettings::Preset::lowQualityMediumLag:
      buf << "Low quality, medium lag" << endl;
      break;
    case AudioSettings::Preset::highQualityMediumLag:
      buf << "High quality, medium lag" << endl;
      break;
    case AudioSettings::Preset::highQualityLowLag:
      buf << "High quality, low lag" << endl;
      break;
    case AudioSettings::Preset::ultraQualityMinimalLag:
      buf << "Ultra quality, minimal lag" << endl;
      break;
  }
  buf << "    Fragment size: " << static_cast<uInt32>(myHardwareSpec.samples) << " bytes" << endl
      << "    Sample rate:   " << static_cast<uInt32>(myHardwareSpec.freq) << " Hz" << endl;
  buf << "    Resampling:    ";
  switch(myAudioSettings.resamplingQuality())
  {
    case AudioSettings::ResamplingQuality::nearestNeightbour:
      buf << "Quality 1, nearest neighbor" << endl;
      break;
    case AudioSettings::ResamplingQuality::lanczos_2:
      buf << "Quality 2, Lanczos (a = 2)" << endl;
      break;
    case AudioSettings::ResamplingQuality::lanczos_3:
      buf << "Quality 3, Lanczos (a = 3)" << endl;
      break;
  }
  buf << "    Headroom:      " << std::fixed << std::setprecision(1)
      << (0.5 * myAudioSettings.headroom()) << " frames" << endl
      << "    Buffer size:   " << std::fixed << std::setprecision(1)
      << (0.5 * myAudioSettings.bufferSize()) << " frames" << endl;
  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundSDL2::processFragment(float* stream, uInt32 length)
{
  myResampler->fillFragment(stream, length);

  for (uInt32 i = 0; i < length; ++i)
    stream[i] *= myVolumeFactor;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundSDL2::initResampler()
{
  Resampler::NextFragmentCallback nextFragmentCallback = [this] () -> Int16* {
    Int16* nextFragment = nullptr;

    if (myUnderrun)
      nextFragment = myAudioQueue->size() >= myEmulationTiming->prebufferFragmentCount() ?
          myAudioQueue->dequeue(myCurrentFragment) : nullptr;
    else
      nextFragment = myAudioQueue->dequeue(myCurrentFragment);

    myUnderrun = nextFragment == nullptr;
    if (nextFragment) myCurrentFragment = nextFragment;

    return nextFragment;
  };

  Resampler::Format formatFrom =
    Resampler::Format(myEmulationTiming->audioSampleRate(), myAudioQueue->fragmentSize(), myAudioQueue->isStereo());
  Resampler::Format formatTo =
    Resampler::Format(myHardwareSpec.freq, myHardwareSpec.samples, myHardwareSpec.channels > 1);

  switch (myAudioSettings.resamplingQuality()) {
    case AudioSettings::ResamplingQuality::nearestNeightbour:
      myResampler = make_unique<SimpleResampler>(formatFrom, formatTo, nextFragmentCallback);
      break;

    case AudioSettings::ResamplingQuality::lanczos_2:
      myResampler = make_unique<LanczosResampler>(formatFrom, formatTo, nextFragmentCallback, 2);
      break;

    case AudioSettings::ResamplingQuality::lanczos_3:
      myResampler = make_unique<LanczosResampler>(formatFrom, formatTo, nextFragmentCallback, 3);
      break;

    default:
      throw runtime_error("invalid resampling quality");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundSDL2::callback(void* udata, uInt8* stream, int len)
{
  SoundSDL2* self = static_cast<SoundSDL2*>(udata);

  if (self->myAudioQueue)
    self->processFragment(reinterpret_cast<float*>(stream), len >> 2);
  else
    SDL_memset(stream, 0, len);
}

#endif  // SOUND_SUPPORT
