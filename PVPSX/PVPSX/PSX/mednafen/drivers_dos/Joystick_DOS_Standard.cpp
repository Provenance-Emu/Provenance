// UNFINISHED

/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "main.h"
#include "input.h"
#include "Joystick.h"
#include "Joystick_DOS_Standard.h"

#ifdef DOS
 #include <somethingoranother.h>
#else
 // For Linux testing - Don't try this at home, kids.
 #include <sys/io.h>
#endif

class Joystick_DOS_Standard : public Joystick
{
 public:

 Joystick_DOS_Standard(unsigned port_arg);
 ~Joystick_DOS_Standard();

 static bool Detect(unsigned port);

 void UpdateInternal(void);

 private:
 int port;
 int jsdev_fd;
 int evdev_fd;
};

Joystick_DOS_Standard::Joystick_DOS_Standard(unsigned port_arg)
{
 port = port_arg;
 #ifndef DOS
  ioperm(port, TRUE);
 #endif

 num_axes = 4;
 num_buttons = 4;
 num_rel_axes = 0;

 id = port;
}

Joystick_DOS_Standard::~Joystick_DOS_Standard()
{

}

bool Joystick_DOS_Standard::Detect(unsigned port)
{


}

void Joystick_DOS_Standard::UpdateInternal(void)
{
 uint32 start_time;
 uint64 end_time[4] = { 0, 0, 0, 0 };
 uint8 buttons;
 uint8 axes;

 buttons = inb(port) & 0xF0;
 outb(0, port);
 start_time = _rdtsc();

 do
 {
  uint64 curtime = _rdtsc();
  axes = inb(port) & 0x0F;
  end_time[0] |= end_time
 } while(axes);
}

class JoystickDriver_DOS_Standard : public JoystickDriver
{
 public:

 JoystickDriver_DOS_Standard();
 virtual ~JoystickDriver_DOS_Standard();

 virtual unsigned NumJoysticks();                       // Cached internally on JoystickDriver instantiation.
 virtual Joystick *GetJoystick(unsigned index);
 virtual void UpdateJoysticks(void);

 private:
 std::vector<Joystick_DOS_Standard *> joys;
};

JoystickDriver_DOS_Standard::JoystickDriver_DOS_Standard()
{

}

JoystickDriver_DOS_Standard::~JoystickDriver_DOS_Standard()
{
 for(unsigned int n = 0; n < joys.size(); n++)
 {
  delete joys[n];
 }
}

unsigned JoystickDriver_DOS_Standard::NumJoysticks(void)
{
 return joys.size();
}

Joystick *JoystickDriver_DOS_Standard::GetJoystick(unsigned index)
{
 return joys[index];
}

void JoystickDriver_DOS_Standard::UpdateJoysticks(void)
{
 for(unsigned int n = 0; n < joys.size(); n++)
 {
  joys[n]->UpdateInternal();
 }
}

JoystickDriver *JoystickDriver_DOS_Standard_New(void)
{
 return new JoystickDriver_DOS_Standard();
}
