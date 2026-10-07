// Adapted from Cytrus (Jarrod Norwell), GPL-2.0-or-later
#pragma once
namespace AzaharCamera {
/// Names of the registered factories, also used for Settings::values.camera_name on iOS.
inline constexpr const char* kFrontCamera = "av_front";
inline constexpr const char* kRearLeftCamera = "av_rear_left";
inline constexpr const char* kRearRightCamera = "av_rear_right";
/// iOS: registers "av_front", "av_rear_left", "av_rear_right" AVFoundation factories. tvOS: no-op.
void RegisterFactories();
}
