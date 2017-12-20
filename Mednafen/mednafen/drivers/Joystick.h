#ifndef __MDFN_DRIVERS_N_JOYSTICK_H
#define __MDFN_DRIVERS_N_JOYSTICK_H

#include <utility>
#include <vector>
#include <list>

class Joystick
{
 public:

 Joystick();
 virtual ~Joystick();

 INLINE uint64 ID(void) { return id; }	// Should be guaranteed unique if at all possible, but if it's not, JoystickManager will handle clashes.
 INLINE const char *Name(void) { return name; }
 INLINE unsigned NumAxes(void) { return num_axes; }
 INLINE unsigned NumRelAxes(void) { return num_rel_axes; }
 INLINE unsigned NumButtons(void) { return num_buttons; }

 INLINE int16 GetAxis(unsigned axis) { return axis_state[axis]; }	// return value should be -32767 through 32767 for stick-type axes, and 0 through 32767
									// for analog buttons(if that information is even available, which it is commonly not).
									// If an axis is an analog button and the value returned will be 0 through 32767, then you must
									// also implement the IsAxisButton() method.
 INLINE int GetRelAxis(unsigned rel_axis) { return rel_axis_state[rel_axis]; }
 INLINE bool GetButton(unsigned button) { return button_state[button]; }

 virtual bool IsAxisButton(unsigned axis);
 virtual void SetRumble(uint8 weak_intensity, uint8 strong_intensity);
 virtual unsigned HatToAxisCompat(unsigned hat);
 virtual unsigned HatToButtonCompat(unsigned hat);

 protected:

 void CalcOldStyleID(unsigned num_axes, unsigned num_balls, unsigned num_hats, unsigned num_buttons);

 char name[256];
 unsigned num_axes;
 unsigned num_rel_axes;
 unsigned num_buttons;
 uint64 id;

 std::vector<int16> axis_state;
 std::vector<int> rel_axis_state;
 std::vector<bool> button_state;
};


class JoystickDriver
{
 public:

 JoystickDriver();
 virtual ~JoystickDriver();

 virtual unsigned NumJoysticks();			// Cached internally on JoystickDriver instantiation.
 virtual Joystick *GetJoystick(unsigned index);
 virtual void UpdateJoysticks(void);
};

struct JoystickManager_Cache
{
 Joystick *joystick;
 uint64 UniqueID;

 enum
 {
  AXIS_CONFIG_TYPE_GENERIC = 0,
  AXIS_CONFIG_TYPE_ANABUTTON_POSPRESS,
  AXIS_CONFIG_TYPE_ANABUTTON_NEGPRESS
 };

 // Helpers for input configuration(may have semantics that differ from what the names would suggest)!
 int config_prio;	// Set to -1 to exclude this joystick instance from configuration, 0 is normal, 1 is SPECIALSAUCEWITHBACON.
 std::vector<int16> axis_config_type;
 bool prev_state_valid;
 std::vector<int16> prev_axis_state;
 std::vector<int> axis_hysterical_ax_murderer;
 std::vector<bool> prev_button_state;
 std::vector<int32> rel_axis_accum_state;
};

class JoystickManager
{
 public:

 JoystickManager();
 ~JoystickManager();

 unsigned DetectAnalogButtonsForChangeCheck(void);
 void Reset_BC_ChangeCheck(void);
 bool Do_BC_ChangeCheck(ButtConfig *bc); // TODO: , bool hint_analog); // hint_analog = true if the emulated button is an analog button/axis/whatever, false if it's digital(binary 0/1).
							   // affects sort order if multiple events come in during the debouncey time period.
 void SetAnalogThreshold(double thresh); // 0.0..-1.0...

 void UpdateJoysticks(void);

 void SetRumble(const std::vector<ButtConfig> &bc, uint8 weak_intensity, uint8 strong_intensity);
 bool TestButton(const ButtConfig &bc);
 int TestAnalogButton(const ButtConfig &bc);

 unsigned GetIndexByUniqueID(uint64 unique_id);	// Returns ~0U if joystick was not found.
 unsigned GetUniqueIDByIndex(unsigned index);

 void TestRumble(void);

 private:
 int AnalogThreshold;

 std::vector<JoystickDriver *> JoystickDrivers;
 std::vector<JoystickManager_Cache> JoystickCache;
 ButtConfig BCPending;
 int BCPending_Prio;
 uint32 BCPending_Time;
 uint32 BCPending_CCCC;
};

#endif
