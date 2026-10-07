#pragma once
namespace AzaharInput {
void RegisterFactories();   // before Core::System::Load
void UnregisterFactories(); // after Shutdown
void ApplyProfile();        // writes Settings::values.current_input_profile
void SetButton(int nativeButton, bool pressed);     // Settings::NativeButton::Values
void SetAnalog(int nativeAnalog, float x, float y); // Settings::NativeAnalog::Values, range -1..1
}
