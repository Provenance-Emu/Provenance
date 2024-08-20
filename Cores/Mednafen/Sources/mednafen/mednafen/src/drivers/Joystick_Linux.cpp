/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Joystick_Linux.cpp:
**  Copyright (C) 2012-2018 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include "main.h"
#include "input.h"
#include "Joystick.h"
#include "Joystick_Linux.h"
#include <mednafen/FileStream.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/joystick.h>
#include <linux/input.h>
#include <sys/types.h>
#include <dirent.h>
#include <limits.h>

class Joystick_Linux : public Joystick
{
 public:

 Joystick_Linux(const char *jsdev_path, const char *evdev_path, const uint64 bvpv) MDFN_COLD;
 ~Joystick_Linux() MDFN_COLD;

 virtual unsigned HatToAxisCompat(unsigned hat);

 void UpdateInternal(void);

 void SetRumble(uint8 weak_intensity, uint8 strong_intensity);

 inline bool RumbleUsed(void)
 {
  return rumble_used;
 }

 private:

 void InitFF(void) MDFN_COLD;

 int jsdev_fd;
 int evdev_fd;

 unsigned compat_hat_offs;
 //unsigned ev_num_buttons;
 //unsigned ev_num_axes;
 //unsigned ev_button_map[KEY_CNT];

 bool rumble_supported;
 struct ff_effect current_rumble;
 bool rumble_used;
};

unsigned Joystick_Linux::HatToAxisCompat(unsigned hat)
{
 if(compat_hat_offs == ~0U)
  return(~0U);
 else
  return(compat_hat_offs + (hat * 2));
}

static bool TestEVBit(uint8 *data, unsigned bit_offset)
{
 return (bool)(data[(bit_offset >> 3)] & (1U << (bit_offset & 0x7)));
}

Joystick_Linux::Joystick_Linux(const char *jsdev_path, const char *evdev_path, const uint64 bvpv) : jsdev_fd(-1), evdev_fd(-1)
{
 unsigned char tmp;

 //printf("%s %s\n", jsdev_path, evdev_path);

 jsdev_fd = open(jsdev_path, O_RDONLY);
 if(jsdev_fd == -1)
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Error opening joystick device \"%s\": %s"), jsdev_path, ene.StrError());
 }

 fcntl(jsdev_fd, F_SETFL, fcntl(jsdev_fd, F_GETFL) | O_NONBLOCK);

 if(evdev_path != NULL)
 {
  evdev_fd = open(evdev_path, O_RDWR);
  if(evdev_fd == -1)
  {
   ErrnoHolder ene(errno);

   if(ene.Errno() == EACCES)
   {
    evdev_fd = open(evdev_path, O_RDONLY);
    if(evdev_fd == -1)
    {
     ErrnoHolder ene2(errno);

     fprintf(stderr, _("WARNING: Failed to open event device \"%s\": %s --- !!!!! BASE JOYSTICK FUNCTIONALITY WILL BE AVAILABLE, BUT FORCE-FEEDBACK(E.G. RUMBLE) WILL BE UNAVAILABLE, AND THE CALCULATED JOYSTICK ID WILL BE DIFFERENT. !!!!!\n"), evdev_path, ene2.StrError());
    }
    else
    {
     fprintf(stderr, _("WARNING: Could only open event device \"%s\" for reading, and not reading+writing: %s --- !!!!! FORCE-FEEDBACK(E.G. RUMBLE) WILL BE UNAVAILABLE. !!!!!\n"), evdev_path, ene.StrError());
    }
   }
   else
    fprintf(stderr, _("WARNING: Failed to open event device \"%s\": %s --- !!!!! BASE JOYSTICK FUNCTIONALITY WILL BE AVAILABLE, BUT FORCE-FEEDBACK(E.G. RUMBLE) WILL BE UNAVAILABLE, AND THE CALCULATED JOYSTICK ID WILL BE DIFFERENT. !!!!!\n"), evdev_path, ene.StrError());
  }
 }
 else
  fprintf(stderr, _("WARNING: Failed to find a valid corresponding event device to joystick device \"%s\" --- !!!!! BASE JOYSTICK FUNCTIONALITY WILL BE AVAILABLE, BUT FORCE-FEEDBACK(E.G. RUMBLE) WILL BE UNAVAILABLE, AND THE CALCULATED JOYSTICK ID WILL BE DIFFERENT. !!!!!\n"), jsdev_path);

 if(evdev_fd != -1)
  fcntl(evdev_fd, F_SETFL, fcntl(evdev_fd, F_GETFL) | O_NONBLOCK);


 num_rel_axes = 0;

 if(ioctl(jsdev_fd, JSIOCGAXES, &tmp) == -1)
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Failed to get number of axes: %s"), ene.StrError());
 }
 else
  num_axes = tmp;

 if(ioctl(jsdev_fd, JSIOCGBUTTONS, &tmp) == -1)
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Failed to get number of buttons: %s"), ene.StrError());
 }
 else
  num_buttons = tmp;

 axis_state.resize(num_axes);
 button_state.resize(num_buttons);

 // Get name
 {
  name.resize(256);	// 1);

  for(;;)
  {
   if(ioctl(jsdev_fd, JSIOCGNAME(name.size()), &name[0]) == -1)
   {
    ErrnoHolder ene(errno);

    throw MDFN_Error(ene.Errno(), _("Failed to get joystick name: %s"), ene.StrError());
   }

   //printf("%s\n", name.c_str());

   if(!name.back()) //strlen(name.c_str()) != (name.size() - 1)
   {
    name.resize(strlen(name.c_str()));
    break;
   }

   name.resize(name.size() * 2);
  }

  if(!name.size())
  {
   char tn[128];

   snprintf(tn, sizeof(tn), _("%u-button, %u-axis controller"), num_buttons, num_axes);
   name = tn;
  }
 }

 compat_hat_offs = ~0U;
 Calc09xID(num_axes, 0, 0, num_buttons);

 // 16-bit bus, 16-bit vendor, 16-bit product, 16-bit version
 MDFN_en64msb(&id[ 0], bvpv);

 // num axes, num buttons to handle some cases of kernel driver options being changed
 MDFN_en16msb(&id[8], num_axes);
 MDFN_en16msb(&id[10], num_buttons);
 MDFN_en32msb(&id[12], 0);

 if(evdev_fd != -1)
 {
#if 0
  uint8 keybits[(KEY_CNT + 7) / 8];
  unsigned ev_button_count = 0;
  
  memset(keybits, 0, sizeof(keybits));
  ioctl(evdev_fd, EVIOCGBIT(EV_KEY, sizeof(keybits)), keybits);

  for(unsigned kbt = 0; kbt < KEY_CNT; kbt++)
  {
   if(keybits[kbt >> 3] & (1 << (kbt & 0x7)))
   {
    ev_button_count++;
   }
  }
  printf("moo: %u\n", ev_button_count);
#endif
  uint8 absaxbits[(ABS_CNT + 7) / 8];
  unsigned ev_abs_count = 0;
  unsigned ev_hat_count = 0;

  memset(absaxbits, 0, sizeof(absaxbits));
  ioctl(evdev_fd, EVIOCGBIT(EV_ABS, sizeof(absaxbits)), absaxbits);
  for(unsigned aat = 0; aat < ABS_CNT; aat++)
  {
   if(TestEVBit(absaxbits, aat))
   {
    if(aat >= ABS_HAT0X && aat <= ABS_HAT3Y)
    {
     if(compat_hat_offs == ~0U)
      compat_hat_offs = ev_abs_count;
     ev_hat_count++;
    }
    ev_abs_count++;
   }
  }
  //printf("%u\n", compat_hat_offs);
  Calc09xID(ev_abs_count - ev_hat_count, 0, ev_hat_count / 2, num_buttons);

#if 0
  struct input_id iid;
  if(ioctl(evdev_fd, EVIOCGID, &iid) == -1)
  {
   ErrnoHolder ene(errno);

   throw MDFN_Error(ene.Errno(), _("Failed to get device ID: %s"), ene.StrError());
  }

  //printf("%04x %04x %04x %04x\n", iid.bustype, iid.vendor, iid.product, iid.version);
  MDFN_en16msb(&id[0], iid.bustype);
  MDFN_en16msb(&id[2], iid.vendor);
  MDFN_en16msb(&id[4], iid.product);
  MDFN_en16msb(&id[6], iid.version);
  MDFN_en64msb(&id[8], 0);
#endif
 }

#if 0
  uint8 keybits[(KEY_CNT + 7) / 8];
  unsigned ev_button_count = 0;
  
  memset(keybits, 0, sizeof(keybits));
  ioctl(evdev_fd, EVIOCGBIT(EV_KEY, sizeof(keybits)), keybits);
  hashie.update(keybits, sizeof(keybits));

  for(unsigned kbt = 0; kbt < KEY_CNT; kbt++)
  {
   if(keybits[kbt >> 3] & (1 << (kbt & 0x7)))
   {
    ev_button_count++;
   }
  }
  printf("moo: %u\n", ev_button_count);
 }
#endif

 rumble_supported = false;
 rumble_used = false;
 if(evdev_fd != -1)
  InitFF();
}

void Joystick_Linux::InitFF(void)
{
 uint8 features[(FF_CNT + 7) / 8];

 if(ioctl(evdev_fd, EVIOCGBIT(EV_FF, sizeof(features)), features) != -1)
 {
  if(TestEVBit((uint8 *)features, FF_RUMBLE))
  {
   rumble_supported = true;
   memset(&current_rumble, 0, sizeof(current_rumble));
   current_rumble.id = -1;
   current_rumble.type = FF_RUMBLE;
   current_rumble.replay.length = 3000;
   current_rumble.replay.delay = 0;
  }
 }
}

Joystick_Linux::~Joystick_Linux()
{
 if(jsdev_fd != -1)
 {
  close(jsdev_fd);
  jsdev_fd = -1;
 }

 if(evdev_fd != -1)
 {
  close(evdev_fd);
  evdev_fd = -1;
 }
}

void Joystick_Linux::SetRumble(uint8 weak_intensity, uint8 strong_intensity)
{
 if(rumble_supported)
 {
  uint32 scaled_weak = weak_intensity * (65535 / 255);
  uint32 scaled_strong = strong_intensity * (65535 / 255);
  input_event play;

  if(!scaled_weak && !scaled_strong && !rumble_used)
   return;

  //printf("RUMBLE SET: %d %d\n", weak_intensity, strong_intensity);
  rumble_used = true;
  current_rumble.u.rumble.weak_magnitude = scaled_weak;
  current_rumble.u.rumble.strong_magnitude = scaled_strong;

  if(ioctl(evdev_fd, EVIOCSFF, &current_rumble) == -1)
  {
   printf("EVIOCSFF failed: %m\n");
   return;
  }

  memset(&play, 0, sizeof(play));

  play.type = EV_FF;
  play.code = current_rumble.id;
  play.value = 1;
  write(evdev_fd, (const void *)&play, sizeof(play));
 }
}


void Joystick_Linux::UpdateInternal(void)
{
 // Axis movement generates a LOT of events very quickly(especially if you hack the kernel to poll USB HID game devices every 1ms instead of 8ms ;)), so read multiple events at once.
 union	// Save a bit of stack space.
 {
  struct js_event jse[32];
  struct input_event eve[32];
 };
 ssize_t read_count;

 while((read_count = read(jsdev_fd, &jse[0], sizeof(jse))) > 0)
 {
  for(unsigned i = 0; i < ((size_t)read_count / sizeof(jse[0])); i++)
  {
   //printf("JLinux: (%u) %u %u %d\n", i, jse[i].type, jse[i].number, jse[i].value);
   switch(jse[i].type & ~JS_EVENT_INIT)
   {
    default: break;
    case JS_EVENT_BUTTON:
	button_state[jse[i].number] = jse[i].value;	
	break;

    case JS_EVENT_AXIS:
	axis_state[jse[i].number] = jse[i].value;
	break;
   }
  }
 }

 if(evdev_fd != -1)
 {
  while((read_count = read(evdev_fd, &eve[0], sizeof(eve))) > 0)
  {
   //for(unsigned i = 0; i < ((size_t)read_count / sizeof(eve[0])); i++)
   //{
   //}
   //puts("YAY");
  }
 }
}

class JoystickDriver_Linux : public JoystickDriver
{
 public:

 JoystickDriver_Linux();
 virtual ~JoystickDriver_Linux();

 virtual unsigned NumJoysticks();                       // Cached internally on JoystickDriver instantiation.
 virtual Joystick *GetJoystick(unsigned index);
 virtual void UpdateJoysticks(void);

 private:
 std::vector<Joystick_Linux *> joys;
};

static void FreeNamelist(struct dirent **namelist, int namelist_num)
{
 if(namelist_num > 0)
 {
  for(int i = 0; i < namelist_num; i++)
  {
   free(namelist[i]); 
  }
 }

 if(namelist)
 {
  free(namelist);
 }
}

static int evdev_filter(const struct dirent *de)
{
 unsigned num;
 int ccount = 0;

 if(sscanf(de->d_name, "event%u%n", &num, &ccount) >= 1 && de->d_name[ccount] == 0)
  return 1;

 return 0;
}

const char* FindSysFSInputBase(void)
{
 static const char* p[] = { "/sys/subsystem/input", "/sys/bus/input", "/sys/block/input", "/sys/class/input" };
 struct stat stat_buf;

 for(size_t i = 0; i < sizeof(p) / sizeof(p[0]); i++)
 {
  if(!stat(p[i], &stat_buf))
  {
   //printf("%s\n", p[i]);
   return p[i];
  }
  else if(errno != ENOENT && errno != ENOTDIR)
  {
   ErrnoHolder ene(errno);

   throw MDFN_Error(ene.Errno(), _("stat() failed: %s"), ene.StrError());
  }
 }

 throw MDFN_Error(0, _("Couldn't find input subsystem under /sys."));
}

std::string FindSysFSInputDeviceByJSDev(const char* jsdev_name)
{
 std::string ret;
 const char* input_subsys_path = FindSysFSInputBase();
 char buf[256];
 char* tmp;

 snprintf(buf, sizeof(buf), "%s/%s", input_subsys_path, jsdev_name);
 if(!(tmp = realpath(buf, NULL)))
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("realpath(\"%s\") failed: %s"), buf, ene.StrError());
 }

 for(;;)
 {
  char* p = strrchr(tmp, '/');
  unsigned idx;

  if(!p)
   throw MDFN_Error(0, _("Couldn't find parent input subsystem device of joystick device \"%s\"."), jsdev_name);

  if(sscanf(p, "/input%u", &idx) == 1)
   break;

  *p = 0;
 }

 try { ret = tmp; free(tmp); } catch(...) { free(tmp); throw; }

 //printf("%s\n", ret.c_str());

 return ret;
}

std::string FindEVDevFullPath(const char* sysfs_input_dev_path)
{
 struct dirent **namelist = NULL;
 int namelist_num = 0;
 std::string ret = "";

 namelist_num = scandir(sysfs_input_dev_path, &namelist, evdev_filter, versionsort);
 if(namelist_num > 0)
 {
  try { ret = std::string("/dev/input") + std::string("/") + std::string(namelist[0]->d_name); } catch(...) { FreeNamelist(namelist, namelist_num); throw; }
 }
 FreeNamelist(namelist, namelist_num);
 namelist = NULL;

 //printf("%s\n", ret.c_str());

 return ret;
}

static uint64 GetBVPV(const std::string& sysfs_input_dev_path)
{
 uint64 ret = 0;

 for(unsigned i = 0; i < 4; i++)
 {
  static const char* fns[4] = { "/id/bustype", "/id/vendor", "/id/product", "/id/version" };
  const std::string idpath = sysfs_input_dev_path + fns[i];
  FileStream fp(idpath, FileStream::MODE_READ);
  std::string lb;
  unsigned t = 0;

  fp.get_line(lb);
  if(sscanf(lb.c_str(), "%x", &t) != 1)
   throw MDFN_Error(0, _("Bad data in \"%s\"."), idpath.c_str());
  if(t > 0xFFFF)
  {
   printf("Data read from \"%s\" has value(0x%x) larger than 0xFFFF\n", idpath.c_str(), t);
   t &= 0xFFFF;
  }
  ret <<= 16;
  ret |= t;
 }

 return ret;
}

static int jsdev_filter(const struct dirent *de)
{
 unsigned num;
 int ccount = 0;

 if(sscanf(de->d_name, "js%u%n", &num, &ccount) >= 1 && de->d_name[ccount] == 0)
  return 1;

 return 0;
}

JoystickDriver_Linux::JoystickDriver_Linux()
{
 struct dirent **inputdir_namelist = NULL;
 struct dirent **basedir_namelist = NULL;
 struct dirent **namelist = NULL;
 int inputdir_namelist_num = 0;
 int basedir_namelist_num = 0;
 int namelist_num = 0;
 const char *base_path;

 inputdir_namelist_num = scandir("/dev/input", &inputdir_namelist, jsdev_filter, versionsort);
 basedir_namelist_num = scandir("/dev", &basedir_namelist, jsdev_filter, versionsort);

 if(basedir_namelist_num > inputdir_namelist_num)
 {
  namelist_num = basedir_namelist_num;
  namelist = basedir_namelist;
  base_path = "/dev";
 }
 else
 {
  namelist_num = inputdir_namelist_num;
  namelist = inputdir_namelist;
  base_path = "/dev/input";
 }

 if(namelist_num > 0)
 {
  for(int i = 0; i < namelist_num; i++)
  {
   char jsdev_path[256];
   Joystick_Linux *jslin = NULL;

   snprintf(jsdev_path, sizeof(jsdev_path), "%s/%s", base_path, namelist[i]->d_name);

   try
   {
    const std::string sysfs_input_dev_path = FindSysFSInputDeviceByJSDev(namelist[i]->d_name);
    const std::string evdev_path = FindEVDevFullPath(sysfs_input_dev_path.c_str());
    const uint64 bvpv = GetBVPV(sysfs_input_dev_path);

    jslin = new Joystick_Linux(jsdev_path, (evdev_path.size() > 0) ? evdev_path.c_str() : NULL, bvpv);
    joys.push_back(jslin);
   }
   catch(std::exception &e)
   {
    MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
    if(jslin)
    {
     delete jslin;
     jslin = NULL;
    }
   }
  }
 }

 namelist = NULL;
 if(inputdir_namelist)
 {
  FreeNamelist(inputdir_namelist, inputdir_namelist_num);
  inputdir_namelist = NULL;
 }

 if(basedir_namelist)
 {
  FreeNamelist(basedir_namelist, basedir_namelist_num);
  basedir_namelist = NULL;
 }
}

JoystickDriver_Linux::~JoystickDriver_Linux()
{
 bool any_rumble_used = false;

 /*
  Try to work around bugs in the Linux kernel that can lead to a kernel panic.
  (and turns rumble off on the controllers in the process)
 */
 for(unsigned int n = 0; n < joys.size(); n++)
 {
  if(joys[n]->RumbleUsed())
  {
   any_rumble_used = true;
   break;
  }
 }

 if(any_rumble_used)
 {
  usleep(20000);

  for(unsigned int n = 0; n < joys.size(); n++)
  {
   if(joys[n]->RumbleUsed())
    joys[n]->SetRumble(1, 1);
  }

  usleep(50000);

  for(unsigned int n = 0; n < joys.size(); n++)
  {
   if(joys[n]->RumbleUsed())
    joys[n]->SetRumble(0, 0);
  }

  usleep(50000);
 }

 for(unsigned int n = 0; n < joys.size(); n++)
 {
  delete joys[n];
 }
}

unsigned JoystickDriver_Linux::NumJoysticks(void)
{
 return joys.size();
}

Joystick *JoystickDriver_Linux::GetJoystick(unsigned index)
{
 return joys[index];
}

void JoystickDriver_Linux::UpdateJoysticks(void)
{
 for(unsigned int n = 0; n < joys.size(); n++)
 {
  joys[n]->UpdateInternal();
 }
}

JoystickDriver *JoystickDriver_Linux_New(void)
{
 return new JoystickDriver_Linux();
}
