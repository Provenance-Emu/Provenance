#ifndef __MDFN_DRIVERS_JOYSTICK_H
#define __MDFN_DRIVERS_JOYSTICK_H

class Joystick
{
 public:

 Joystick() MDFN_COLD;
 virtual ~Joystick() MDFN_COLD;

 INLINE std::array<uint8, 16> ID(void) { return id; }	// Should be guaranteed unique if at all possible, but if it's not, JoystickManager will handle clashes.
 INLINE uint64 ID_09x(void) { return id_09x; }
 INLINE const char* Name(void) { return name.c_str(); }
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

 void Calc09xID(unsigned num_axes, unsigned num_balls, unsigned num_hats, unsigned num_buttons) MDFN_COLD;

 std::string name;
 uint64 id_09x;
 std::array<uint8, 16> id;

 unsigned num_axes;
 unsigned num_rel_axes;
 unsigned num_buttons;

 std::vector<int16> axis_state;
 std::vector<int> rel_axis_state;
 std::vector<bool> button_state;
};


class JoystickDriver
{
 public:

 JoystickDriver() MDFN_COLD;
 virtual ~JoystickDriver() MDFN_COLD;

 virtual unsigned NumJoysticks();			// Cached internally on JoystickDriver instantiation.
 virtual Joystick *GetJoystick(unsigned index);
 virtual void UpdateJoysticks(void);
};

namespace JoystickManager
{
 void Init(void) MDFN_COLD;
 void Kill(void) MDFN_COLD;

 unsigned DetectAnalogButtonsForChangeCheck(void);
 void Reset_BC_ChangeCheck(void);
 bool Do_BC_ChangeCheck(ButtConfig *bc); // TODO: , bool hint_analog); // hint_analog = true if the emulated button is an analog button/axis/whatever, false if it's digital(binary 0/1).
							   // affects sort order if multiple events come in during the debouncey time period.
 void SetAnalogThreshold(double thresh); // 0.0..-1.0...

 void UpdateJoysticks(void);

 void SetRumble(const std::vector<ButtConfig> &bc, uint8 weak_intensity, uint8 strong_intensity);
 bool TestButton(const ButtConfig &bc);
 int TestAnalogButton(const ButtConfig &bc);
 int64 TestAxisRel(const ButtConfig& bc);

 // Returns ~0U if joystick was not found.
 unsigned GetIndexByUniqueID(const std::array<uint8, 16>& unique_id);
 unsigned GetIndexByUniqueID_09x(uint64 unique_id);

 std::array<uint8, 16> GetUniqueIDByIndex(unsigned index);

 std::string BNToString(const uint32 bn);
 bool StringToBN(const char* s, uint16* bn);

 bool Translate09xBN(unsigned bn09x, uint16* bn, bool abs_pointer_axis_thing);

 //
 // avoid using these enums directly outside of Joystick.cpp, as their semantics may change(with the exception of JOY_BN_GUN_TRANSLATE).
 //
 enum
 {
  JOY_BN_INDEX_MASK 	= 0x03FF,

  //JOY_BN_HATCOMPAT_MASK	= 0x01FF,

  JOY_BN_TYPE_SHIFT	= 10,
  JOY_BN_TYPE_MASK	= 0x3 << JOY_BN_TYPE_SHIFT,
  JOY_BN_TYPE_BUTTON	= 0U << JOY_BN_TYPE_SHIFT,
  JOY_BN_TYPE_ABS_AXIS	= 1U << JOY_BN_TYPE_SHIFT,
  JOY_BN_TYPE_REL_AXIS	= 2U << JOY_BN_TYPE_SHIFT,
  JOY_BN_TYPE_HATCOMPAT	= 3U << JOY_BN_TYPE_SHIFT,

  JOY_BN_GUN_TRANSLATE	= 1U << 13,
  JOY_BN_HALFAXIS	= 1U << 14,
  JOY_BN_NEGATE		= 1U << 15
 };
}

#endif
