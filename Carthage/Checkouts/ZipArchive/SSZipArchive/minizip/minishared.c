#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <fcntl.h>

#include "zlib.h"
#include "ioapi.h"

#ifdef _WIN32
#  include <direct.h>
#  include <io.h>
#else
#  include <unistd.h>
#  include <utime.h>
#  include <sys/types.h>
#  include <sys/stat.h>
#endif

#include "minishared.h"

#ifdef _WIN32
#  define USEWIN32IOAPI
#  include "iowin32.h"
#endif

uint32_t get_file_date(const char *path, uint32_t *dos_date)
{
    int ret = 0;
#ifdef _WIN32
    FILETIME ftm_local;
    HANDLE find = NULL;
    WIN32_FIND_DATAA ff32;

    find = FindFirstFileA(path, &ff32);
    if (find != INVALID_HANDLE_VALUE)
    {
        FileTimeToLocalFileTime(&(ff32.ftLastWriteTime), &ftm_local);
        FileTimeToDosDateTime(&ftm_local, ((LPWORD)dos_date) + 1, ((LPWORD)dos_date) + 0);
        FindClose(find);
        ret = 1;
    }
#else
    struct stat s;
    struct tm *filedate = NULL;
    time_t tm_t = 0;

    memset(&s, 0, sizeof(s));

    if (strcmp(path, "-") != 0)
    {
        size_t len = strlen(path);
        char *name = (char *)malloc(len + 1);
        strncpy(name, path, len + 1);
        name[len] = 0;
        if (name[len - 1] == '/')
            name[len - 1] = 0;

        /* Not all systems allow stat'ing a file with / appended */
        if (stat(name, &s) == 0)
        {
            tm_t = s.st_mtime;
            ret = 1;
        }
        free(name);
    }

    filedate = localtime(&tm_t);
    *dos_date = tm_to_dosdate(filedate);
#endif
    return ret;
}

void change_file_date(const char *path, uint32_t dos_date)
{
#ifdef _WIN32
    HANDLE handle = NULL;
    FILETIME ftm, ftm_local, ftm_create, ftm_access, ftm_modified;

    handle = CreateFileA(path, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (handle != INVALID_HANDLE_VALUE)
    {
        GetFileTime(handle, &ftm_create, &ftm_access, &ftm_modified);
        DosDateTimeToFileTime((WORD)(dos_date >> 16), (WORD)dos_date, &ftm_local);
        LocalFileTimeToFileTime(&ftm_local, &ftm);
        SetFileTime(handle, &ftm, &ftm_access, &ftm);
        CloseHandle(handle);
    }
#else
    struct utimbuf ut;
    ut.actime = ut.modtime = dosdate_to_time_t(dos_date);
    utime(path, &ut);
#endif
}

int invalid_date(const struct tm *ptm)
{
#define datevalue_in_range(min, max, value) ((min) <= (value) && (value) <= (max))
    return (!datevalue_in_range(0, 207, ptm->tm_year) ||
            !datevalue_in_range(0, 11, ptm->tm_mon) ||
            !datevalue_in_range(1, 31, ptm->tm_mday) ||
            !datevalue_in_range(0, 23, ptm->tm_hour) ||
            !datevalue_in_range(0, 59, ptm->tm_min) ||
            !datevalue_in_range(0, 59, ptm->tm_sec));
#undef datevalue_in_range
}

// Conversion without validation
void dosdate_to_raw_tm(uint64_t dos_date, struct tm *ptm)
{
    uint64_t date = (uint64_t)(dos_date >> 16);

    ptm->tm_mday = (uint16_t)(date & 0x1f);
    ptm->tm_mon = (uint16_t)(((date & 0x1E0) / 0x20) - 1);
    ptm->tm_year = (uint16_t)(((date & 0x0FE00) / 0x0200) + 80);
    ptm->tm_hour = (uint16_t)((dos_date & 0xF800) / 0x800);
    ptm->tm_min = (uint16_t)((dos_date & 0x7E0) / 0x20);
    ptm->tm_sec = (uint16_t)(2 * (dos_date & 0x1f));
    ptm->tm_isdst = -1;
}

int dosdate_to_tm(uint64_t dos_date, struct tm *ptm)
{
    dosdate_to_raw_tm(dos_date, ptm);

    if (invalid_date(ptm))
    {
        // Invalid date stored, so don't return it.
        memset(ptm, 0, sizeof(struct tm));
        return -1;
    }
    return 0;
}

time_t dosdate_to_time_t(uint64_t dos_date)
{
    struct tm ptm;
    dosdate_to_raw_tm(dos_date, &ptm);
    return mktime(&ptm);
}

uint32_t tm_to_dosdate(const struct tm *ptm)
{
    struct tm fixed_tm;

    /* Years supported:
    * [00, 79]      (assumed to be between 2000 and 2079)
    * [80, 207]     (assumed to be between 1980 and 2107, typical output of old
                     software that does 'year-1900' to get a double digit year)
    * [1980, 2107]  (due to the date format limitations, only years between 1980 and 2107 can be stored.)
    */

    memcpy(&fixed_tm, ptm, sizeof(struct tm));
    if (fixed_tm.tm_year >= 1980) /* range [1980, 2107] */
        fixed_tm.tm_year -= 1980;
    else if (fixed_tm.tm_year >= 80) /* range [80, 99] */
        fixed_tm.tm_year -= 80;
    else /* range [00, 79] */
        fixed_tm.tm_year += 20;

    if (invalid_date(ptm))
        return 0;

    return (uint32_t)(((fixed_tm.tm_mday) + (32 * (fixed_tm.tm_mon + 1)) + (512 * fixed_tm.tm_year)) << 16) |
        ((fixed_tm.tm_sec / 2) + (32 * fixed_tm.tm_min) + (2048 * (uint32_t)fixed_tm.tm_hour));
}

int makedir(const char *newdir)
{
    char *buffer = NULL;
    char *p = NULL;
    int len = (int)strlen(newdir);

    if (len <= 0)
        return 0;

    buffer = (char*)malloc(len + 1);
    if (buffer == NULL)
    {
        printf("Error allocating memory\n");
        return -1;
    }

    strcpy(buffer, newdir);

    if (buffer[len - 1] == '/')
        buffer[len - 1] = 0;

    if (MKDIR(buffer) == 0)
    {
        free(buffer);
        return 1;
    }

    p = buffer + 1;
    while (1)
    {
        char hold;
        while (*p && *p != '\\' && *p != '/')
            p++;
        hold = *p;
        *p = 0;

        if ((MKDIR(buffer) == -1) && (errno == ENOENT))
        {
            printf("couldn't create directory %s (%d)\n", buffer, errno);
            free(buffer);
            return 0;
        }

        if (hold == 0)
            break;

        *p++ = hold;
    }

    free(buffer);
    return 1;
}

FILE *get_file_handle(const char *path)
{
    FILE *handle = NULL;
#if defined(WIN32)
    wchar_t *pathWide = NULL;
    int pathLength = 0;

    pathLength = MultiByteToWideChar(CP_UTF8, 0, path, -1, NULL, 0) + 1;
    pathWide = (wchar_t*)calloc(pathLength, sizeof(wchar_t));
    MultiByteToWideChar(CP_UTF8, 0, path, -1, pathWide, pathLength);
    handle = _wfopen((const wchar_t*)pathWide, L"rb");
    free(pathWide);
#else
    handle = fopen64(path, "rb");
#endif

    return handle;
}

int check_file_exists(const char *path)
{
    FILE *handle = get_file_handle(path);
    if (handle == NULL)
        return 0;
    fclose(handle);
    return 1;
}

int is_large_file(const char *path)
{
    FILE* handle = NULL;
    uint64_t pos = 0;

    handle = get_file_handle(path);
    if (handle == NULL)
        return 0;

    fseeko64(handle, 0, SEEK_END);
    pos = ftello64(handle);
    fclose(handle);

    printf("file : %s is %lld bytes\n", path, pos);

    return (pos >= UINT32_MAX);
}

void display_zpos64(uint64_t n, int size_char)
{
    /* To avoid compatibility problem we do here the conversion */
    char number[21] = { 0 };
    int offset = 19;
    int pos_string = 19;
    int size_display_string = 19;

    while (1)
    {
        number[offset] = (char)((n % 10) + '0');
        if (number[offset] != '0')
            pos_string = offset;
        n /= 10;
        if (offset == 0)
            break;
        offset--;
    }

    size_display_string -= pos_string;
    while (size_char-- > size_display_string)
        printf(" ");
    printf("%s", &number[pos_string]);
}
