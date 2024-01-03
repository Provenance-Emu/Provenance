// Local Changes: Use L2 to Change Layout
#ifndef _INPUT_H
#define _INPUT_H

#include "types.h"

enum TouchMode
{
   Disabled,
   Mouse,
   Touch,
   Joystick,
};

struct InputState
{
   bool touching;
   int touch_x, touch_y;
   TouchMode current_touch_mode;

   bool layout_btn = false;
   bool holding_noise_btn = false;
   bool swap_screens_btn = false;
   bool lid_closed = false;
};

extern InputState input_state;

bool cursor_enabled(InputState *state);

extern bool libretro_supports_bitmasks;

void update_input(InputState *state);

#endif
