#include <stdlib.h>
#include <stdio.h>
#include <time.h>

int main (void)
{
  struct tm	locTime;
  time_t	sysTime;
  char	*build;

  time(&sysTime);
  locTime = *localtime(&sysTime);

  if ((build = getenv("BUILD_NUMBER")) != NULL) {
    printf("#define BUILD_NUMBER		%s\n", build);
    printf("#define BUILD_NUMBER_STR	\"%s\"\n", build);
  } else {
    unsigned short magic;
    magic = (locTime.tm_yday << 7) |
            (locTime.tm_hour << 2) |
            (locTime.tm_min / 15);
    printf("#define BUILD_NUMBER		%d\n", magic);
    printf("#define BUILD_NUMBER_STR	\"%d\"\n", magic);
  }

  return 0;
}
