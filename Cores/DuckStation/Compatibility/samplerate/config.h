/* Name of package */
#define PACKAGE "libsamplerate"

/* Version number of package */
#define VERSION "0.1.9"

/* Target processor clips on negative float to int conversion. */
#define CPU_CLIPS_NEGATIVE 0

/* Target processor clips on positive float to int conversion. */
#define CPU_CLIPS_POSITIVE 0

/* Target processor is big endian. */
#define CPU_IS_BIG_ENDIAN 0

/* Target processor is little endian. */
#define CPU_IS_LITTLE_ENDIAN 1

/* Define to 1 if you have the `alarm' function. */
#define HAVE_ALARM 1

/* Define to 1 if you have the <alsa/asoundlib.h> header file. */
/* #undef HAVE_ALSA */

/* Set to 1 if you have libfftw3. */
/* #undef HAVE_FFTW3 */

/* Define if you have C99's lrint function. */
#define HAVE_LRINT 1

/* Define if you have C99's lrintf function. */
#define HAVE_LRINTF 1

/* Define if you have signal SIGALRM. */
#define HAVE_SIGALRM 1

/* Define to 1 if you have the `signal' function. */
#define HAVE_SIGNAL 1

/* Set to 1 if you have libsndfile. */
/* #undef HAVE_SNDFILE */

/* Define to 1 if you have the <stdbool.h> header file. */
#define HAVE_STDBOOL_H 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <sys/times.h> header file. */
/* #undef HAVE_SYS_TIMES_H */

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* define fast samplerate convertor */
#define ENABLE_SINC_FAST_CONVERTER 1

/* define balanced samplerate convertor */
#define ENABLE_SINC_MEDIUM_CONVERTER 1

/* define best samplerate convertor */
/* #define ENABLE_SINC_BEST_CONVERTER 1 */

/* The size of `int', as computed by sizeof. */
#define SIZEOF_INT 4

/* The size of `long', as computed by sizeof. */
// not even going to bother with 32-bit code here.
#define SIZEOF_LONG 8
