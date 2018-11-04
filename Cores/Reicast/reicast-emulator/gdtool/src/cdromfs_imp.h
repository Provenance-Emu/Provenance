#pragma once
#include "cdromfs.h"


/* cdromfs.h: various definitions for CDROM filesystems. */

#define VD_LSN        16  /* first logical sector of volume descriptor table */
#define CDROM_LSECSZ  2048 /* initial logical sector size of a CDROM */

#define HSF 1
#define ISO 2

char *cdromfmtnames[] = {
    "unknown format",
    "High Sierra",
    "ISO - 9660"
};
char *voltypenames[] = {
    "Boot Record",
    "Standard File Structure",
    "Coded Character Set File Structure",
    "Unspecified File Structure",
};
/* rude translation routines for interpreting strings, words, halfwords */
#define ISO_AS(s)   (iso_astring(s, sizeof(s)))
#define ISO_WD(s)   (*(unsigned *)(s))
#define ISO_HWD(s)  (*(unsigned short *)(s))
#define ISO_BY(s)   (*(unsigned char *)(s))

#define NVOLTYPENAMES   (sizeof(voltypenames)/sizeof(char *))

#define CD_FLAGBITS "vdaEp  m"  /* file flag bits */
/* Handy macro's for block calculation */
#define lbntob(fs, n)   ((fs)->lbs * (n))
#define btolbn(fs, n)   ((fs)->lbs * (n))
#define trunc_lbn(fs, n)    ((n) - ((n) % (fs)->lbs)
#define roundup(n, d)   ((((n) + (d)) / (d)) * (d))