// Local Changes: Use L2 to Change Layout

#include "input.h"
#include "libretro_state.h"
#include "utils.h"

#include "NDS.h"

InputState input_state;
u32 input_mask = 0xFFF;
static bool has_touched = false;

#define ADD_KEY_TO_MASK(key, i, bits) if (bits & (1 << key)) input_mask &= ~(1 << i); else input_mask |= (1 << i);

bool cursor_enabled(InputState *state)
{
   return state->current_touch_mode == TouchMode::Mouse || state->current_touch_mode == TouchMode::Joystick;
}

void update_input(InputState *state)
{
   u32 joypad_bits;
   int i;

   input_poll_cb();

   if (libretro_supports_bitmasks)
   {
      joypad_bits = input_state_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_MASK);
   }
   else
   {
      joypad_bits = 0;
      for (i = 0; i < (RETRO_DEVICE_ID_JOYPAD_R3 + 1); i++)
         joypad_bits |= input_state_cb(0, RETRO_DEVICE_JOYPAD, 0, i) ? (1 << i) : 0;
   }
   
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_A,      0,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_B,      1,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_SELECT, 2,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_START,  3,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_RIGHT,  4,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_LEFT,   5,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_UP,     6,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_DOWN,   7,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_R,      8,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_L,      9,  joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_X,      10, joypad_bits);
   ADD_KEY_TO_MASK(RETRO_DEVICE_ID_JOYPAD_Y,      11, joypad_bits);

   NDS::SetKeyMask(input_mask);

   bool lid_closed_btn = !!input_state_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L3);
   if(lid_closed_btn != state->lid_closed)
   {
      NDS::SetLidClosed(lid_closed_btn);
      state->lid_closed = lid_closed_btn;
   }
   state->holding_noise_btn = !!input_state_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R3);

   state->layout_btn = !!input_state_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L2);
   state->swap_screens_btn = !!input_state_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R2);

   if(current_screen_layout != ScreenLayout::TopOnly)
   {
      switch(state->current_touch_mode)
      {
         case TouchMode::Disabled:
            state->touching = false;
            break;
         case TouchMode::Mouse:
            {
               int16_t mouse_x = input_state_cb(0, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_X);
               int16_t mouse_y = input_state_cb(0, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_Y);

               state->touching = input_state_cb(0, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_LEFT);

               state->touch_x = Clamp(state->touch_x + mouse_x, 0, VIDEO_WIDTH - 1);
               state->touch_y = Clamp(state->touch_y + mouse_y, 0, VIDEO_HEIGHT - 1);
            }

            break;
         case TouchMode::Touch:
            if(input_state_cb(0, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_PRESSED))
            {
               int16_t pointer_x = input_state_cb(0, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_X);
               int16_t pointer_y = input_state_cb(0, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_Y);

               unsigned int touch_scale = screen_layout_data.displayed_layout == ScreenLayout::HybridBottom ? screen_layout_data.hybrid_ratio : 1;

               unsigned int x = ((int)pointer_x + 0x8000) * screen_layout_data.buffer_width / 0x10000 / touch_scale;
               unsigned int y = ((int)pointer_y + 0x8000) * screen_layout_data.buffer_height / 0x10000 / touch_scale;

               if ((x >= screen_layout_data.touch_offset_x) && (x < screen_layout_data.touch_offset_x + screen_layout_data.screen_width) &&
                     (y >= screen_layout_data.touch_offset_y) && (y < screen_layout_data.touch_offset_y + screen_layout_data.screen_height))
               {
                  state->touching = true;

                  state->touch_x = Clamp((x - screen_layout_data.touch_offset_x) * VIDEO_WIDTH / screen_layout_data.screen_width, 0, VIDEO_WIDTH - 1);
                  state->touch_y = Clamp((y - screen_layout_data.touch_offset_y) * VIDEO_HEIGHT / screen_layout_data.screen_height, 0, VIDEO_HEIGHT - 1);
               }
            }
            else if(state->touching)
            {
               state->touching = false;
            }

            break;
         case TouchMode::Joystick:
            int16_t joystick_x = input_state_cb(0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_X) / 2048;
            int16_t joystick_y = input_state_cb(0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_Y) / 2048;

            state->touch_x = Clamp(state->touch_x + joystick_x, 0, VIDEO_WIDTH - 1);
            state->touch_y = Clamp(state->touch_y + joystick_y, 0, VIDEO_HEIGHT - 1);

            state->touching = !!input_state_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R3);

            break;
      }
   }
   else
   {
      state->touching = false;
   }

   if(state->touching)
   {
      NDS::TouchScreen(state->touch_x, state->touch_y);
      has_touched = true;
   }
   else if(has_touched)
   {
      NDS::ReleaseScreen();
      has_touched = false;
   }
}
