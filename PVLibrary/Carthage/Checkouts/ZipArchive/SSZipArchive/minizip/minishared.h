#ifndef _MINISHARED_H
#define _MINISHARED_H

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
#  define MKDIR(d) _mkdir(d)
#  define CHDIR(d) _chdir(d)
#else
#  define MKDIR(d) mkdir(d, 0775)
#  define CHDIR(d) chdir(d)
#endif

/***************************************************************************/

/* Get a file's date and time in dos format */
uint32_t get_file_date(const char *path, uint32_t *dos_date);

/* Sets a file's date and time in dos format */
void change_file_date(const char *path, uint32_t dos_date);

/* Convert dos date/time format to struct tm */
int dosdate_to_tm(uint64_t dos_date, struct tm *ptm);

/* Convert dos date/time format to time_t */
time_t dosdate_to_time_t(uint64_t dos_date);

/* Convert struct tm to dos date/time format */
uint32_t tm_to_dosdate(const struct tm *ptm);

/* Create a directory and all subdirectories */
int makedir(const char *newdir);

/* Check to see if a file exists */
int check_file_exists(const char *path);

/* Check to see if a file is over 4GB and needs ZIP64 extension */
int is_large_file(const char *path);

/* Print a 64-bit number for compatibility */
void display_zpos64(uint64_t n, int size_char);

/***************************************************************************/

#ifdef __cplusplus
}
#endif

#endif /* _MINISHARED_H */