// The engine feeds signed 16-bit PCM to SoundTouch, matching the shipped vendor ABI.
#define SOUNDTOUCH_INTEGER_SAMPLES 1
#include <cstdint>
#include <type_traits>
#include <SoundTouch/SoundTouch.h>
static_assert(std::is_same_v<soundtouch::SAMPLETYPE, std::int16_t>);
#include "../../emuthree/emuThreeDS/citra_core/audio_core/time_stretch.cpp"
