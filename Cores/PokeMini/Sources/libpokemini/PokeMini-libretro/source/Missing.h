#if defined( VITA ) || defined( __CELLOS_LV2__ )
#include <stddef.h>
char* getcwd( char* buf, size_t size );
int chdir( const char* path);
#endif
