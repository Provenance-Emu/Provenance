/**
  This program is based on G25manage, located at:
    https://github.com/VDrift/vdrift/tree/master/tools/G25manage

  This code is released under the GPLv2, and modified from the
  original by Stephen Anthony (sa666666@gmail.com).
*/

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <getopt.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <stdio.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <dirent.h>

#include <sys/ioctl.h>
#include <sys/types.h>
#include <asm/types.h>
#include <fcntl.h>

#include <linux/input.h>

/* this macro is used to tell if "bit" is set in "array"
 * it selects a byte from the array, and does a boolean AND
 * operation with a byte that only has the relevant bit set.
 * eg. to check for the 12th bit, we do (array[1] & 1<<4)
 */
#define test_bit(bit, array)    (array[bit/8] & (1<<(bit%8)))

// The default location for evdev devices in Linux
#define EVDEV_DIR "/dev/input/by-id/"

////////////////////////////////////////////////////////////////
// Function signatures; see actual functions for documentation
void help(void);
void listDevices(void);
void printAxisType(int i);
int showCalibration(const char* const evdev);
int setAxisInfo(const char* evdev, int axisindex,
                __s32 minvalue, __s32 maxvalue,
                __s32 deadzonevalue, __s32 fuzzvalue);
////////////////////////////////////////////////////////////////


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void help(void)
{
  printf("%s","Usage:\n\n"
    "  --help, --h              The message you're now reading\n"
    "  --listdevs, --l          List all joystick devices found\n"
    "  --showcal, --s [path]    Show current calibration for joystick device\n"
    "  --evdev, --e [path]      Set the joystick device to modify\n"
    "  --minimum, --m [val]     Change minimum for current joystick\n"
    "  --maximum, --M [val]     Change maximum for current joystick\n"
    "  --deadzone, --d [val]    Change deadzone for current joystick\n"
    "  --fuzz, --f [val]        Change fuzz for current joystick\n"
    "  --axis, --a [val]        The axis to modify for current joystick (by default, all axes)\n"
    "\n"
    "To see calibration information: \n"
    "  evdev-joystick [ --s /path/to/event/device/file ]\n"
    "\n"
    "To set the deadzone values:\n"
    "  evdev-joystick [ --e /path/to/event/device/file --d deadzone_value [ --a axis_index ] ]\n"
    "\n"
    "To set the minimum and maximum range values:\n"
    "  evdev-joystick [ --e /path/to/event/device/file --m minimum_value --M maximum_value [ --a axis_index ] ]\n"
    "\n"
    "Example:\n"
    "\n"
    "I want to see the calibration values of my event managed joystick:\n"
    "  evdev-joystick --s /dev/input/event6\n"
    "\n"
    "Supported Absolute axes:\n"
    "  Absolute axis 0x00 (0) (X Axis) (value: 387, min: 0, max: 16383, flatness: 1023 (=6.24%), fuzz: 63)\n"
    "  Absolute axis 0x01 (1) (Y Axis) (value: 216, min: 0, max: 255, flatness: 15 (=5.88%), fuzz: 0)\n"
    "  Absolute axis 0x02 (2) (Z Axis) (value: 0, min: 0, max: 255, flatness: 15 (=5.88%), fuzz: 0)\n"
    "  Absolute axis 0x05 (5) (Z Rate Axis) (value: 101, min: 0, max: 255, flatness: 15 (=5.88%), fuzz: 0)\n"
    "  Absolute axis 0x10 (16) (Hat zero, x axis) (value: 0, min: -1, max: 1, flatness: 0 (=0.00%), fuzz: 0)\n"
    "  Absolute axis 0x11 (17) (Hat zero, y axis) (value: 0, min: -1, max: 1, flatness: 0 (=0.00%), fuzz: 0)\n"
    "\n"
    "I want to get rid of the deadzone on all axes on my joystick:\n"
    "  evdev-joystick --e /dev/input/event6 --d 0\n"
    "\n");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void listDevices(void)
{
  DIR* dirp = opendir(EVDEV_DIR);
  struct dirent* dp;

  if(dirp == NULL)
    return;

  // Loop over dir entries using readdir
  size_t len = strlen("event-joystick");
  while((dp = readdir(dirp)) != NULL)
  {
    // Only select names that end in 'event-joystick'
    size_t devlen = strlen(dp->d_name);
    if(devlen >= len)
    {
      const char* const start = dp->d_name + devlen - len;
      if(strncmp(start, "event-joystick", len) == 0)
        printf("%s%s\n", EVDEV_DIR, dp->d_name);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void printAxisType(int i)
{
  switch(i)
  {
    case ABS_X :        printf(" (X Axis) ");             break;
    case ABS_Y :        printf(" (Y Axis) ");             break;
    case ABS_Z :        printf(" (Z Axis) ");             break;
    case ABS_RX :       printf(" (X Rate Axis) ");        break;
    case ABS_RY :       printf(" (Y Rate Axis) ");        break;
    case ABS_RZ :       printf(" (Z Rate Axis) ");        break;
    case ABS_THROTTLE : printf(" (Throttle) ");           break;
    case ABS_RUDDER :   printf(" (Rudder) ");             break;
    case ABS_WHEEL :    printf(" (Wheel) ");              break;
    case ABS_GAS :      printf(" (Accelerator) ");        break;
    case ABS_BRAKE :    printf(" (Brake) ");              break;
    case ABS_HAT0X :    printf(" (Hat zero, x axis) ");   break;
    case ABS_HAT0Y :    printf(" (Hat zero, y axis) ");   break;
    case ABS_HAT1X :    printf(" (Hat one, x axis) ");    break;
    case ABS_HAT1Y :    printf(" (Hat one, y axis) ");    break;
    case ABS_HAT2X :    printf(" (Hat two, x axis) ");    break;
    case ABS_HAT2Y :    printf(" (Hat two, y axis) ");    break;
    case ABS_HAT3X :    printf(" (Hat three, x axis) ");  break;
    case ABS_HAT3Y :    printf(" (Hat three, y axis) ");  break;
    case ABS_PRESSURE : printf(" (Pressure) ");           break;
    case ABS_DISTANCE : printf(" (Distance) ");           break;
    case ABS_TILT_X :   printf(" (Tilt, X axis) ");       break;
    case ABS_TILT_Y :   printf(" (Tilt, Y axis) ");       break;
    case ABS_MISC :     printf(" (Miscellaneous) ");      break;
    default:            printf(" (Unknown absolute feature) ");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int showCalibration(const char* const evdev)
{
  int fd = -1, axisindex;
  uint8_t abs_bitmask[ABS_MAX/8 + 1];
  double percent_deadzone;
  struct input_absinfo abs_features;

  if((fd = open(evdev, O_RDONLY)) < 0)
  {
    perror("evdev open");
    return 1;
  }

  memset(abs_bitmask, 0, sizeof(abs_bitmask));
  if (ioctl(fd, EVIOCGBIT(EV_ABS, sizeof(abs_bitmask)), abs_bitmask) < 0)
    perror("evdev ioctl");

  printf("Supported Absolute axes:\n");

  for(axisindex = 0; axisindex < ABS_MAX; ++axisindex)
  {
    if(test_bit(axisindex, abs_bitmask))
    {
      // This means that the bit is set in the axes list
      printf("  Absolute axis 0x%02x (%d)", axisindex, axisindex);
      printAxisType(axisindex);

      if(ioctl(fd, EVIOCGABS(axisindex), &abs_features))
        perror("evdev EVIOCGABS ioctl");

      percent_deadzone = (double)abs_features.flat * 100 / (double)abs_features.maximum;
      printf("(value: %d, min: %d, max: %d, flatness: %d (=%.2f%%), fuzz: %d)\n",
        abs_features.value, abs_features.minimum, abs_features.maximum,
        abs_features.flat, percent_deadzone, abs_features.fuzz);
    }
  }

  close(fd);
  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int setAxisInfo(const char* evdev, int axisindex,
                __s32 minvalue, __s32 maxvalue,
                __s32 deadzonevalue, __s32 fuzzvalue)
{
  int fd = -1;
  uint8_t abs_bitmask[ABS_MAX/8 + 1];
  double percent_deadzone;
  struct input_absinfo abs_features;

  if ((fd = open(evdev, O_RDONLY)) < 0)
  {
    perror("evdev open");
    return 1;
  }

  memset(abs_bitmask, 0, sizeof(abs_bitmask));
  if(ioctl(fd, EVIOCGBIT(EV_ABS, sizeof(abs_bitmask)), abs_bitmask) < 0)
    perror("evdev ioctl");

  int axis_first = 0, axis_last = ABS_MAX;
  if(axisindex >= 0 && axisindex < ABS_MAX)
  {
    axis_first = axisindex;
    axis_last = axisindex + 1;
  }

  for(axisindex = axis_first; axisindex < axis_last; ++axisindex)
  {
    if(test_bit(axisindex, abs_bitmask))
    {
      /* this means that the bit is set in the axes list */
      printf("  Absolute axis 0x%02x (%d)", axisindex, axisindex);
      printAxisType(axisindex);

      if(ioctl(fd, EVIOCGABS(axisindex), &abs_features))
      {
        perror("evdev EVIOCGABS ioctl");
        return 1;
      }

      if(minvalue != INT_MIN)
      {
        printf("Setting min value to : %d\n", minvalue);
        abs_features.minimum = minvalue;
      }

      if(maxvalue != INT_MIN)
      {
        printf("Setting max value to : %d\n", maxvalue);
        abs_features.maximum = maxvalue;
      }

      if(deadzonevalue != INT_MIN)
      {
        if(deadzonevalue < abs_features.minimum ||
           deadzonevalue > abs_features.maximum )
        {
          printf("Deadzone value must be between %d and %d for this axis, "
                 "value requested : %d\n",
            abs_features.minimum, abs_features.maximum, deadzonevalue);
        }

        printf("Setting deadzone value to : %d\n", deadzonevalue);
        abs_features.flat = deadzonevalue;
      }

      if(fuzzvalue != INT_MIN)
      {
        if(fuzzvalue < abs_features.minimum ||
           fuzzvalue > abs_features.maximum )
        {
          printf("Fuzz value must be between %d and %d for this axis, "
                 "value requested : %d\n",
            abs_features.minimum, abs_features.maximum, fuzzvalue);
        }

        printf("Setting fuzz value to : %d\n", fuzzvalue);
        abs_features.fuzz = fuzzvalue;
      }

      if(ioctl(fd, EVIOCSABS(axisindex), &abs_features))
      {
        perror("evdev EVIOCSABS ioctl");
        return 1;
      }
      if(ioctl(fd, EVIOCGABS(axisindex), &abs_features))
      {
        perror("evdev EVIOCGABS ioctl");
        return 1;
      }
      percent_deadzone = (double)abs_features.flat * 100 / (double)abs_features.maximum;
      printf("    (value: %d, min: %d, max: %d, flatness: %d (=%.2f%%), fuzz: %d)\n",
        abs_features.value, abs_features.minimum, abs_features.maximum,
        abs_features.flat, percent_deadzone, abs_features.fuzz);
    }
  }

  close(fd);
  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int main(int argc, char* argv[])
{
  char* evdevice = NULL;
  int c, axisindex = -1;
  __s32 min = INT_MIN, max = INT_MIN, flat = INT_MIN, fuzz = INT_MIN;

  // Show help by default
  if(argc == 1)
  {
    help();
    exit(0);
  }

  while(1)
  {
    static struct option long_options[] =
    {
      { "help",     no_argument,       0, 'h' },
      { "listdevs", no_argument,       0, 'l' },
      { "showcal",  required_argument, 0, 's' },
      { "evdev",    required_argument, 0, 'e' },
      { "minimum",  required_argument, 0, 'm' },
      { "maximum",  required_argument, 0, 'M' },
      { "deadzone", required_argument, 0, 'd' },
      { "fuzz",     required_argument, 0, 'f' },
      { "axis",     required_argument, 0, 'a' },
      { 0, 0, 0, 0 }
    };
    // getopt_long stores the option index here
    int option_index = 0;

    c = getopt_long(argc, argv, "h:l:s:e:d:m:M:f:a:", long_options, &option_index);

    // Detect the end of the options
    if(c == -1)
      break;

    switch(c)
    {
      case 0:
        // If this option set a flag, do nothing else now.
        if(long_options[option_index].flag != 0)
          break;
        printf("option %s", long_options[option_index].name);
        if(optarg)
          printf(" with arg %s", optarg);
        printf("\n");
        break;

      case 'h':
        help();
        break;

      case 'l':
        listDevices();
        break;

      case 's':
        evdevice = optarg;
        showCalibration(evdevice);
        break;

      case 'e':
        evdevice = optarg;
        printf("Event device file: %s\n", evdevice);
        break;

      case 'd':
        flat = atoi(optarg);
        printf("New dead zone value: %d\n", flat);
        break;

      case 'm':
        min = atoi(optarg);
        printf("New min value: %d\n", min);
        break;

      case 'M':
        max = atoi(optarg);
        printf("New max value: %d\n", max);
        break;

      case 'f':
        fuzz = atoi(optarg);
        printf("New fuzz value: %d\n", fuzz);
        break;

      case 'a':
        axisindex = atoi(optarg);
        printf("Axis index to deal with: %d\n", axisindex);
        break;

      case '?':
        // getopt_long already printed an error message.
        break;

      default:
        abort();
    }
  }

  // Print any remaining command line arguments (not options).
  if(optind < argc)
  {
    printf("non-option ARGV-elements: ");
    while(optind < argc)
      printf("%s ", argv[optind++]);
    putchar('\n');
  }

  if(min != INT_MIN || max != INT_MIN || flat != INT_MIN || fuzz != INT_MIN)
  {
    if(evdevice == NULL)
    {
      printf( "You must specify the event device for your joystick\n" );
      exit(1);
    }
    else
    {
      if(axisindex == -1)
      {
        if(min != INT_MIN)
          printf( "Trying to set all axes minimum to: %d\n", min);
        if(max != INT_MIN)
          printf( "Trying to set all axes maximum to: %d\n", max);
        if(flat != INT_MIN)
          printf( "Trying to set all axes deadzone to: %d\n", flat);
        if(fuzz != INT_MIN)
          printf( "Trying to set all axes fuzz to: %d\n", fuzz);
      }
      else
      {
        if(min != INT_MIN)
          printf( "Trying to set axis %d minimum to: %d\n", axisindex, min);
        if(max != INT_MIN)
          printf( "Trying to set axis %d maximum to: %d\n", axisindex, max);
        if(flat != INT_MIN)
          printf( "Trying to set axis %d deadzone to: %d\n", axisindex, flat);
        if(fuzz != INT_MIN)
          printf( "Trying to set axis %d fuzz to: %d\n", axisindex, fuzz);
      }

      setAxisInfo(evdevice, axisindex, min, max, flat, fuzz);
    }
  }

  exit(0);
}
