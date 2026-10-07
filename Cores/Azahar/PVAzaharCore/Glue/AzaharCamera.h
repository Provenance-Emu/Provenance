// Adapted from Cytrus (Jarrod Norwell), GPL-2.0-or-later
#pragma once
namespace AzaharCamera {
/// iOS: registers "av_front", "av_rear_left", "av_rear_right" AVFoundation factories. tvOS: no-op.
void RegisterFactories();
}
