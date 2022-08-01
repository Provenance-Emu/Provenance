EVDEV-JOYSTICK
--------------

This program is based on G25manage, located at:
  https://github.com/VDrift/vdrift/tree/master/tools/G25manage

It is developed by Stephen Anthony, and released under the GPL/v2.

evdev-joystick is used to set the deadzone for Linux 'evdev' joystick devices.
Currently, other than G25manage there is no other standalone program available
to perform such calibration.  This program was originally developed for Stella
(https://stella-emu.github.io), an Atari 2600 emulator, and as such much of
this document refers to Stella.  The program itself can be used to calibrate
any joystick for any application, though, and is not specific to Stella.


Short Explanation (Stella users with Stelladaptor, 2600-daptor, etc.)
-----------------

1)  Decompress the archive
2)  Build the application by typing 'make'
3)  Install it by typing 'sudo make install'
4)  Unplug your 'daptor device, re-plug them, and play a game.


Long Explanation (For the curious, or if something doesn't work, etc.)
----------------

1)  Decompress the archive
2)  Build the application by typing 'make'

3)  Type './evdev-joystick --l'.  For me, it produces output as follows:

/dev/input/by-id/usb-Microsoft_Inc._Controller_101F9B0-event-joystick
/dev/input/by-id/usb-Microchip_Technology_Inc._2600-daptor_II-event-joystick
/dev/input/by-id/usb-RetroUSB.com_SNES_RetroPort-event-joystick

4)  Make note of the name of the device.  For 2600-daptor II users, this
    would be:

/dev/input/by-id/usb-Microchip_Technology_Inc._2600-daptor_II-event-joystick

5)  Check the current deadzone (known as 'flatness') by typing:
      'evdev-joystick --s <NAME_OF_DEVICE>'
    Again, for me, this will output the following:

  Absolute axis 0x00 (0) (X Axis) (min: 0, max: 4095, flatness: 128 (=0.00%), fuzz: 15)
  Absolute axis 0x01 (1) (Y Axis) (min: 0, max: 4095, flatness: 128 (=0.00%), fuzz: 15)
  Absolute axis 0x02 (2) (Z Axis) (min: 0, max: 15, flatness: 0 (=0.00%), fuzz: 0)

6)  Notice that the flatness/deadzone for axes 0 & 1 is 128.

7)  Now, we change the deadzone by typing 'evdev-joystick --s <NAME_OF_DEVICE> --d 0'

8)  Now check the current deadzone again by typing:
      'evdev-joystick --s <NAME_OF_DEVICE>'

  Absolute axis 0x00 (0) (X Axis) (min: 0, max: 4095, flatness: 0 (=0.00%), fuzz: 15)
  Absolute axis 0x01 (1) (Y Axis) (min: 0, max: 4095, flatness: 0 (=0.00%), fuzz: 15)
  Absolute axis 0x02 (2) (Z Axis) (min: 0, max: 15, flatness: 0 (=0.00%), fuzz: 0)

9)  Note that the 'flatness' has changed to 0?  If so, then the program is
    working as intended.

10) Note that there are other options to the program.  You can change the
    'fuzz' value, change attributes for only certain axis, etc.  See the
    options by typing 'evdev-joystick'.

11) Once you're certain that the application is working, type 'sudo make install'
    to install it.


RULES File
----------

Included in the archive is a udev .rules file that will automatically run
evdev-joystick with the correct parameters for a Stelladaptor, 2600-daptor,
and 2600-daptor II.  If you have another joystick you wish to modify,
simply add the proper entry to the .rules file.  Note that it is necessary
to add all joysticks (where you want to change the deadzone) to this file,
since the settings are lost when the device is unplugged and plugged in again.
When using a .rules file, the system will automatically re-run evdev-joystick
and set your deadzone values again.
