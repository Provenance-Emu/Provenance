#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include "linux-dist/joystick.h"

#if defined(USE_JOYSTICK)
#include <linux/joystick.h>

	const u32 joystick_map_btn_usb[JOYSTICK_MAP_SIZE]      = { DC_BTN_Y, DC_BTN_B, DC_BTN_A, DC_BTN_X, 0, 0, 0, 0, 0, DC_BTN_START };
	const u32 joystick_map_axis_usb[JOYSTICK_MAP_SIZE]     = { DC_AXIS_X, DC_AXIS_Y, 0, 0, 0, 0, 0, 0, 0, 0 };

	const u32 joystick_map_btn_xbox360[JOYSTICK_MAP_SIZE]  = { DC_BTN_A, DC_BTN_B, DC_BTN_X, DC_BTN_Y, 0, 0, 0, DC_BTN_START, 0, 0 };
	const u32 joystick_map_axis_xbox360[JOYSTICK_MAP_SIZE] = { DC_AXIS_X, DC_AXIS_Y, DC_AXIS_LT, 0, 0, DC_AXIS_RT, DC_DPAD_LEFT, DC_DPAD_UP, 0, 0 };

	const u32* joystick_map_btn = joystick_map_btn_usb;
	const u32* joystick_map_axis = joystick_map_axis_usb;

	int input_joystick_init(const char* device)
	{
		int axis_count = 0;
		int button_count = 0;
		char name[128] = "Unknown";

		printf("joystick: Trying to open device at '%s'\n", device);

		int fd = open(device, O_RDONLY);

		if(fd >= 0)
		{
			fcntl(fd, F_SETFL, O_NONBLOCK);
			ioctl(fd, JSIOCGAXES, &axis_count);
			ioctl(fd, JSIOCGBUTTONS, &button_count);
			ioctl(fd, JSIOCGNAME(sizeof(name)), &name);

			printf("joystick: Found '%s' with %d axis and %d buttons at '%s'.\n", name, axis_count, button_count, device);

			if (strcmp(name, "Microsoft X-Box 360 pad") == 0 ||
					strcmp(name, "Xbox Gamepad (userspace driver)") == 0 ||
					strcmp(name, "Xbox 360 Wireless Receiver (XBOX)") == 0)
			{
				joystick_map_btn = joystick_map_btn_xbox360;
				joystick_map_axis = joystick_map_axis_xbox360;
				printf("joystick: Using Xbox 360 map\n");
			}
		}
		else
		{
			perror("joystick open");
		}

		return fd;
	}

	bool input_joystick_handle(int fd, u32 port)
	{
		// Joystick must be connected
		if(fd < 0) {
			return false;
		}

		struct js_event JE;
		while(read(fd, &JE, sizeof(JE)) == sizeof(JE))
		if (JE.number < JOYSTICK_MAP_SIZE)
		{
			switch(JE.type & ~JS_EVENT_INIT)
			{
				case JS_EVENT_AXIS:
				{
					u32 mt = joystick_map_axis[JE.number] >> 16;
					u32 mo = joystick_map_axis[JE.number] & 0xFFFF;

					//printf("AXIS %d,%d\n",JE.number,JE.value);
					s8 v=(s8)(JE.value/256); //-127 ... + 127 range

					if (mt == 0)
					{
						kcode[port] |= mo;
						kcode[port] |= mo*2;
						if (v<-64)
						{
							kcode[port] &= ~mo;
						}
						else if (v>64)
						{
							kcode[port] &= ~(mo*2);
						}

					 //printf("Mapped to %d %d %d\n",mo,kcode[port]&mo,kcode[port]&(mo*2));
					}
					else if (mt == 1)
					{
						if (v >= 0)
						{
							v++;  //up to 255
						}
						//printf("AXIS %d,%d Mapped to %d %d %d\n",JE.number,JE.value,mo,v,v+127);
						if (mo == 0)
						{
							lt[port] = (v + 127);
						}
						else if (mo == 1)
						{
							rt[port] = (v + 127);
						}
					}
					else if (mt == 2)
					{
						//  printf("AXIS %d,%d Mapped to %d %d [%d]",JE.number,JE.value,mo,v);
						if (mo == 0)
						{
							joyx[port] = v;
						}
						else if (mo == 1)
						{
							joyy[port] = v;
						}
					}
				}
				break;

				case JS_EVENT_BUTTON:
				{
					u32 mt = joystick_map_btn[JE.number] >> 16;
					u32 mo = joystick_map_btn[JE.number] & 0xFFFF;

					// printf("BUTTON %d,%d\n",JE.number,JE.value);

					if (mt == 0)
					{
						// printf("Mapped to %d\n",mo);
						if (JE.value)
						{
							kcode[port] &= ~mo;
						}
						else
						{
							kcode[port] |= mo;
						}
					}
					else if (mt == 1)
					{
						// printf("Mapped to %d %d\n",mo,JE.value?255:0);
						if (mo==0)
						{
							lt[port] = JE.value ? 255 : 0;
						}
						else if (mo==1)
						{
							rt[port] = JE.value ? 255 : 0;
						}
					}
				}
				break;
			}
		}

		return true;
	}
#endif
