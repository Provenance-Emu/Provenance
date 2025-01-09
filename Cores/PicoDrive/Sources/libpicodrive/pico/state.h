#include <stdlib.h>

typedef size_t (arearw)(void *p, size_t _size, size_t _n, void *file);
typedef size_t (areaeof)(void *file);
typedef int    (areaseek)(void *file, long offset, int whence);
typedef int    (areaclose)(void *file);

int PicoStateFP(void *afile, int is_save,
  arearw *read, arearw *write, areaeof *eof, areaseek *seek);
