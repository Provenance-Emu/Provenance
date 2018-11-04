/*
	hacked from http://collaboration.cmc.ec.gc.ca/science/rpn/biblio/ddj/Website/articles/DDJ/1992/9212/9212i/9212i.htm
	Is this bsd + adv license?

*/

#include "types.h"
#include "cdromfs_imp.h"


/* cdromcat -- A simple program to interpret the CDROM filesystem, and return.
 * the contents of the file (directories are formatted and printed, files are
 * returned untranslated).  */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "cdromfs.h"

/* volume descriptor types -- type field of each descriptor */
  #define VD_PRIMARY 1
  #define VD_END 255

  /* ISO 9660 primary descriptor */
  #define ISODCL(from, to) (to - from + 1)

  #define ISO_STANDARD_ID "CD001"

  struct iso_primary_descriptor {
       char type                      [ISODCL (  1,     1)];
       char id                        [ISODCL (  2,     6)];
       char version                   [ISODCL (  7,     7)];
       char reserved1                 [ISODCL (  8,     8)];
       char system_id                 [ISODCL (  9,    40)]; /* achars */
       char volume_id                 [ISODCL ( 41,    72)]; /* dchars */
       char reserved2                 [ISODCL ( 73,    80)];
       char volume_space_size         [ISODCL ( 81,    88)];
       char reserved3                 [ISODCL ( 89,   120)];
       char volume_set_size           [ISODCL (121,   124)];
       char volume_sequence_number    [ISODCL (125,   128)];
       char logical_block_size        [ISODCL (129,   132)];
       char path_table_size           [ISODCL (133,   140)];
       char type_1_path_table         [ISODCL (141,   144)];
       char opt_type_1_path_table     [ISODCL (145,   148)];
       char type_m_path_table         [ISODCL (149,   152)];
       char opt_type_m_path_table     [ISODCL (153,   156)];
       char root_directory_record     [ISODCL (157,   190)];
       char volume_set_id             [ISODCL (191,   318)]; /* dchars */
       char publisher_id              [ISODCL (319,   446)]; /* achars */
       char preparer_id               [ISODCL (447,   574)]; /* achars */
       char application_id            [ISODCL (575,   702)]; /* achars */
       char copyright_file_id         [ISODCL (703,   739)]; /* dchars */
       char abstract_file_id          [ISODCL (740,   776)]; /* dchars */
       char bibliographic_file_id     [ISODCL (777,   813)]; /* dchars */
       char creation_date             [ISODCL (814,   830)];
       char modification_date         [ISODCL (831,   847)];
       char expiration_date           [ISODCL (848,   864)];
       char effective_date            [ISODCL (865,   881)];
       char file_structure_version    [ISODCL (882,   882)];
       char reserved4                 [ISODCL (883,   883)];
       char application_data          [ISODCL (884,  1395)];
       char reserved5                 [ISODCL (1396,  2048)];

  };

  
  /* High Sierra format primary descriptor */
  #define HSFDCL(from, to) (to - from + 1)

  #define HSF_STANDARD_ID "CDROM"

  struct hsf_primary_descriptor {
       char volume_lbn                [HSFDCL (  1,     8)];
       char type                      [HSFDCL (  9,     9)];
       char id                        [HSFDCL ( 10,    14)];
       char version                   [HSFDCL ( 15,    15)];
       char reserved1                 [HSFDCL ( 16,    16)];
       char system_id                 [HSFDCL ( 17,    48)]; /* achars */
       char volume_id                 [HSFDCL ( 49,    80)]; /* dchars */
       char reserved2                 [HSFDCL ( 81,    88)];
       char volume_space_size         [HSFDCL ( 89,    96)];
       char reserved3                 [HSFDCL ( 97,   128)];
       char volume_set_size           [HSFDCL (129,   132)];
       char volume_sequence_number    [HSFDCL (133,   136)];
       char logical_block_size        [HSFDCL (137,   140)];
       char path_table_size           [HSFDCL (141,   148)];
       char manditory_path_table_lsb  [HSFDCL (149,   152)];
       char opt_path_table_lsb_1      [HSFDCL (153,   156)];
       char opt_path_table_lsb_2      [HSFDCL (157,   160)];
       char opt_path_table_lsb_3      [HSFDCL (161,   164)];
       char manditory_path_table_msb  [HSFDCL (165,   168)];
       char opt_path_table_msb_1      [HSFDCL (169,   172)];
       char opt_path_table_msb_2      [HSFDCL (173,   176)];
       char opt_path_table_msb_3      [HSFDCL (177,   180)];
       char root_directory_record     [HSFDCL (181,   214)];
       char volume_set_id             [HSFDCL (215,   342)]; /* dchars */
       char publisher_id              [HSFDCL (343,   470)]; /* achars */
       char preparer_id               [HSFDCL (471,   598)]; /* achars */
       char application_id            [HSFDCL (599,   726)]; /* achars */
       char copyright_file_id         [HSFDCL (727,   758)]; /* dchars */
       char abstract_file_id          [HSFDCL (759,   790)]; /* dchars */
       char creation_date             [HSFDCL (791,   806)];
       char modification_date         [HSFDCL (807,   822)];
       char expiration_date           [HSFDCL (823,   838)];
       char effective_date            [HSFDCL (839,   854)];
       char file_structure_version    [HSFDCL (855,   855)];
       char reserved4                 [HSFDCL (856,   856)];
       char application_data          [HSFDCL (857,  1368)];
       char reserved5                 [HSFDCL (1369,  2048)];
  };

   /* CDROM file system directory entries */

  /* file flags: */
  #define CD_VISABLE  0x01 /* file name is hidden or visable to user */
  #define CD_DIRECTORY  0x02 /* file is a directory and contains entries */
  #define CD_ASSOCIATED  0x04/* file is opaque to filesystem, visable
                                to system implementation */
  #define CD_EAHSFRECORD 0x04 /* file has HSF extended attribute record
                                 fmt */
  #define CD_PROTECTION  0x04 /* used extended attributes for protection */
  #define CD_ANOTHEREXTNT 0x80 /* file has at least one more extent */

  struct iso_directory_record {
       char length         [ISODCL  (1, 1)];
       char ext_attr_length         [ISODCL (2, 2)];
       char extent         [ISODCL  (3, 10)];
       char size           [ISODCL  (11, 18)];
       char date           [ISODCL  (19, 25)];
       char flags          [ISODCL  (26, 26)];
       char file_unit_size      [ISODCL (27, 27)];
       char interleave          [ISODCL (28, 28)];
       char volume_sequence_number  [ISODCL (29, 32)];
       char name_len           [ISODCL  (33, 33)];
       /*char name           [0];*/
	   char* name() { return (char*)this+sizeof(*this); }

  };

struct hsf_directory_record {

    char length         [HSFDCL (1, 1)];
    char ext_attr_length        [HSFDCL (2, 2)];
    char extent         [HSFDCL (3, 10)];
    char size           [HSFDCL (11, 18)];
    char date           [HSFDCL (19, 24)];
    char flags          [HSFDCL (25, 25)];
    char reserved1          [HSFDCL (26, 26)];
    char interleave_size        [HSFDCL (27, 27)];
    char interleave         [HSFDCL (28, 28)];
    char volume_sequence_number [HSFDCL (29, 32)];
    char name_len           [HSFDCL (33, 33)];
    /*char name           [0];*/
	char* name() { return (char*)this+sizeof(*this); }
};

/* per filesystem information */
struct fs {
    char *name; /* kind of cdrom filesystem */
	cdimage* fd;     /* open file descriptor */
    int lbs;    /* logical block size */
    int type;   /* which flavor */
};

union fsdir {
    struct iso_directory_record iso_dir;
    struct hsf_directory_record hsf_dir;
};

/* filesystem directory entry */
struct directent {
    union  {
		struct iso_directory_record iso_dir;
		struct hsf_directory_record hsf_dir;
	} fsd;
    /* actually, name contains name, reserved field, and extensions area */
    char name[255 - sizeof(union fsdir)/*32*/];
};

/* filesystem volume descriptors */
union voldesc {
    struct iso_primary_descriptor  iso_desc;
    struct hsf_primary_descriptor  hsf_desc;
};

char *iso_astring(char *, int len);
double cdrom_time(struct cdromtime *, int);
void printdirent(FILE* w, struct directent *, struct fs *, bool&);
void printdirents(FILE* w, struct directent *, struct fs *);
void printdirentheader(char *p);
int searchdirent(struct directent *, struct directent *, struct directent *,
    struct fs *);
	void extractdirent(struct directent *, struct fs *, data_callback* dcb, void* dcbctx);
int lookup(struct directent *, struct directent *, char *, struct fs *);
/* "fetch directory value" */
#define FDV(b, f, t)    (((t) == ISO) ? (b)->fsd.iso_dir.##f \
                : (b)->fsd.hsf_dir.##f)
/* "fetch primary descriptor value" */
#define FPDV(b, f, t)   (((t) == ISO) ? (b)->iso_desc.##f \
                : (b)->hsf_desc.##f)

/* ----------- Filesystem primatives ------------------- */
/* Check for the presence of a cdrom filesystem. If present, pass back
 * parameters for initialization, otherwise, pass back error. */
int
iscdromfs(struct directent *dp, struct fs *fs, int scan_from) {
    char buffer[CDROM_LSECSZ];
    union voldesc *vdp = (union voldesc *) buffer;
    /* locate at the beginning of the descriptor table */
    fs->fd->seek((scan_from + VD_LSN)*CDROM_LSECSZ);
    /* walk descriptor table */
    for(;;) {
        unsigned char type;
        /* obtain a descriptor */
        fs->fd->read(buffer, sizeof(buffer));
        /* determine ISO or HSF format of CDROM */
        if (fs->type == 0) {
            if (strncmp (vdp->iso_desc.id, ISO_STANDARD_ID,
                sizeof(vdp->iso_desc.id)) == 0)
                fs->type = ISO;
            if (strncmp (vdp->hsf_desc.id, HSF_STANDARD_ID,
                sizeof(vdp->hsf_desc.id)) == 0)
                fs->type = HSF;
        }
        /* if determined, obtain root directory entry */
        if (fs->type) {
            type = ISO_BY(FPDV(vdp, type, fs->type));
            if (type == VD_PRIMARY) {
                memcpy (
				dp,FPDV(vdp, root_directory_record, fs->type),
                 sizeof (union fsdir));
            fs->lbs =
                  ISO_HWD(FPDV(vdp, logical_block_size, fs->type));
            }
        }
        /* terminating volume */
        if (type == VD_END)
            break;
    }
    fs->name = cdromfmtnames[fs->type];
    return (fs->type);
}
/* Obtain a "logical", i.e. relative to the directory entries beginning
 * (or extent), block from the CDROM. */
int
getblkdirent(struct directent *dp, char *contents, long lbn, struct fs *fs) {
    long    filesize = ISO_WD(FDV(dp, size, fs->type)),
        extent = ISO_WD(FDV(dp, extent, fs->type));
    if (lbntob(fs, lbn) > roundup(filesize, fs->lbs))
        return (0);
    /* perform logical to physical translation */
    (void) fs->fd->seek(lbntob(fs, extent + lbn));
    /* obtain block */
    return (fs->fd->read(contents, fs->lbs) == fs->lbs);
}
/* Search the contents of this directory entry, known to be a directory itself,
 * looking for a component. If found, return directory entry associated with
 * the component. */
int
searchdirent(struct directent *dp, struct directent *fdp,
    struct directent *compdp, struct fs *fs) {
    struct directent *ldp;
    long    filesize =  ISO_WD(FDV(dp, size, fs->type)),
        comp_namelen =  ISO_BY(FDV(compdp, name_len, fs->type)),
        lbn = 0, cnt;
    char    *buffer = (char *) malloc(fs->lbs);
    while (getblkdirent(dp, buffer, lbn, fs)) {
        cnt = filesize > fs->lbs ? fs->lbs : filesize;
        filesize -= cnt;
        ldp = (struct directent *) buffer;
        /* have we a record to match? */
        while (cnt > sizeof (union fsdir)) {
            long    entlen, namelen;
            /* match against component's name and name length */
            entlen = ISO_BY(FDV(ldp, length, fs->type));
            namelen = ISO_BY(FDV(ldp, name_len, fs->type));
			if (entlen >= comp_namelen + sizeof(union fsdir) && namelen == comp_namelen
                && strncmp(FDV(ldp,name(),fs->type),
                FDV(compdp,name(),fs->type), namelen) == 0) {
                memcpy (fdp, ldp, entlen);
                memcpy (compdp, ldp, entlen);
                free(buffer);
                return 1;
            } else {
                cnt -= entlen;
                ldp = (struct directent *)
                    (((char *) ldp) + entlen);
            }
        }
        if (filesize == 0) break;
        lbn++;
    }
    free(buffer);
    return 0;
}
/* Lookup the pathname by interpreting the directory structure of the CDROM
 * element by element, returning a directory entry if found. Name translation
 * occurs here, out of the null terminated path name string. This routine
 * works by recursion. */
int
lookup(struct directent *dp, struct directent *fdp, char *pathname,
    struct fs *fs) {
    struct directent *ldp;
    struct directent thiscomp;
    char *nextcomp;
    unsigned len;
    /* break off the next component of the pathname */
    if ((nextcomp = strrchr(pathname, '/'))  == NULL)
        nextcomp = strrchr(pathname, '\0');
    /* construct an entry for this component to match */
    ISO_BY(FDV(&thiscomp, name_len, fs->type)) = len = nextcomp - pathname;
    memcpy(thiscomp.name, pathname, len);
    /* attempt a match, returning component if found */
    if (searchdirent(dp, fdp, &thiscomp, fs)){
        /* if no more components, return found value */
        if (*nextcomp == '\0')
            return 1;
        /* otherwise, if this component is a directory,
         * recursively satisfy lookup */
        else if (ISO_BY(FDV(dp, flags, fs->type)) & CD_DIRECTORY)
            return (lookup(&thiscomp, fdp, nextcomp + 1, fs));
    }
    /* if no match return fail */
    else
        return(0);
}
/* --------------- object output routines for application ------------ */
/* Extract the entire contents of a directory entry and write this on
 * standard output. */
void
extractdirent(struct directent *dp, struct fs *fs, data_callback* dcb, void* dcbctx) {
    long    filesize = ISO_WD(FDV(dp, size, fs->type)),
        lbn = 0, cnt;
    char    *buffer = (char *) malloc(fs->lbs);
    /* iterate over all contents of the directory entry */
    while (getblkdirent(dp, buffer, lbn, fs)) {
        /* write out the valid portion of this logical block */
        cnt = filesize > fs->lbs ? fs->lbs : filesize;
        dcb(dcbctx, buffer,  cnt);
        /* next one? */
        lbn++;
        filesize -= cnt;
        if (filesize == 0) break;
    }
    free(buffer);
}
/* Print directory header */
void
printdirentheader(char *path) {
    printf("Directory(%s):\n", path);
    printf("Flags:\tsize date sysa name\n");
}
/* Print all entries in the directory. */
void
printdirents(FILE* w, struct directent *dp, struct fs *fs) {
    struct directent *ldp;
    long    filesize = ISO_WD(FDV(dp, size, fs->type)),
        lbn = 0, cnt;
	bool first = true;
    char    *buffer = (char *) malloc(fs->lbs);
    while (getblkdirent(dp, buffer, lbn, fs)) {
        long    entlen, namelen;
        cnt = filesize > fs->lbs ? fs->lbs : filesize;
        filesize -= cnt;
        ldp = (struct directent *) buffer;
        entlen = ISO_BY(FDV(ldp, length, fs->type));
        namelen = ISO_BY(FDV(ldp, name_len, fs->type));
        /* have we a record to match? */
        while (cnt > sizeof (union fsdir) && entlen && namelen) {
            printdirent(w, ldp, fs, first);
            /* next entry? */
            cnt -= entlen;
            ldp = (struct directent *) (((char *) ldp) + entlen);
            entlen = ISO_BY(FDV(ldp, length, fs->type));
            namelen = ISO_BY(FDV(ldp, name_len, fs->type));
        }
        if (filesize == 0) break;
        lbn++;
    }
    free(buffer);
}

char __212[32];

/* print CDROM file modes */
char* prmodes(int f) {
	memset(__212, 0, sizeof(__212));
	char* p = __212;

    int i;
    for(i=0; i < 8; i++) {
        if(CD_FLAGBITS[i] == ' ')
            continue;
        if(f & (1<<i))
            *p++=(CD_FLAGBITS[i]);
        /*else
            *p++=('-');*/
    }

	return __212;
}
/* Print a directent on output, formatted. */
#define HN(name, val, lst) fprintf(w, "%s\"%s\":%0.f", !lst?", " : "", name, (double)(val))
#define HS(name, val, lst) fprintf(w, "%s\"%s\":\"%s\"", !lst?", " : " ", name, val)

void
printdirent(FILE* w, struct directent *dp, struct fs *fs, bool& first) {
    unsigned extattlen;
    unsigned fbname, name_len, entlen, enttaken;

	entlen = ISO_BY(FDV(dp, length, fs->type));
    name_len = ISO_BY(FDV(dp, name_len, fs->type));
    enttaken = sizeof(union fsdir) + name_len;

	if (enttaken & 1)
        enttaken++;
    fbname = ISO_BY(FDV(dp, name(), fs->type));
    entlen -= enttaken;

	if (name_len == 1 && fbname <= 1) 
		return;


	fprintf(w, "%s\n\t{", first ? "" : ",");
	{
		first = false;

		HS("name", iso_astring(FDV(dp, name(), fs->type), name_len), true);

		//modes
		HS("modes", prmodes(ISO_BY(FDV(dp, flags, fs->type))), false);

		// size
		HN("size", ISO_WD(FDV(dp, size, fs->type)), false);

		//lba
		HN("startFAD", 150 + ISO_WD(FDV(dp, extent, fs->type)), false);

		//time
		HN("time", cdrom_time((struct cdromtime *) FDV(dp, date, fs->type),fs->type), false);
	}
	fprintf(w, " }");
}

//cdrom_time to js timestamp
double
cdrom_time(struct cdromtime *crt, int type) {
    struct tm tm;
    static char buf[32];
    char *fmt;
    /* step 1. convert into a ANSI C time description */
    tm.tm_sec = min(crt->sec,60);
    tm.tm_min = min(crt->min,60);
    tm.tm_hour = min(crt->hour,23);
    tm.tm_mday = min(crt->day, 31);
    /* month starts with 1 */
    tm.tm_mon = crt->month - 1;
    tm.tm_year = crt->years;
    tm.tm_isdst = 0;
/* Note: not all ISO-9660 disks have correct timezone field */
#ifdef whybother
    /* ISO has time zone as 7th octet, HSF does not */
    if (type == ISO) {
        tm.tm_gmtoff = crt->tz*15*60;
        tm.tm_zone = timezone(crt->tz*15, 0);
        fmt = "%b %e %H:%M:%S %Z %Y";
    } else
#endif

	return 1000.0*mktime(&tm);
}
static char __strbuf[200];
/* turn a blank padded character field into the null terminated strings
   that POSIX/UNIX/WHATSIX likes so much */
char *iso_astring(char *sp, int len) {
    memcpy(__strbuf, sp, len);
    __strbuf[len] = 0;
    for (sp = __strbuf + len - 1; sp > __strbuf ; sp--)
        if (*sp == ' ')
            *sp = 0;
    return(__strbuf);
}





#if 0



/* user "application" program */
int
mainy(int argc, char *argv[])
{
    struct directent openfile;
    char pathname[80];
    /* open the CDROM device */
    if ((fsd.fd = open("/dev/ras2d", 0)) < 0) {
        perror("cdromcat");
        exit(1);
    }
    /* is there a filesystem we can understand here? */
    if (iscdromfs(&rootent, &fsd) == 0) {
        fprintf(stderr, "cdromcat: %s\n", fsd.name);
        exit(1);
    }
    /* print the contents of the root directory to give user a start */
    printf("Root Directory Listing:\n");
    printdirentheader("/");
    printdirents(&rootent, &fsd);
    /* print files on demand from user */
    for(;;){
        /* prompt user for name to locate */
        printf("Pathname to open? : ");
        fflush(stdout);
        /* obtain, if none, exit, else trim newline off */
        if (fgets(pathname, sizeof(pathname), stdin) == NULL)
            exit(0);
        pathname[strlen(pathname) - 1] = '\0';
        if (strlen(pathname) == 0)
            exit(0);
        /* lookup filename on CDROM */
        if (lookup(&rootent, &openfile, pathname, &fsd)){
            /* if a directory, format and list it */
            if (ISO_BY(FDV(&openfile, flags, fsd.type))
                & CD_DIRECTORY) {
                printdirentheader(pathname);
                printdirents(&openfile, &fsd);
            }
            /* if a file, print it on standard output */
            else
                extractdirent(&openfile, &fsd, 0);
        } else
            printf("Not found.\n");
    }
    /* NOTREACHED */
}

#endif


void find(FILE* w, directent* rootent, fs* fsd, char* pathname) {
	struct directent openfile;

	if (lookup(rootent, &openfile, pathname, fsd)) {
		/* if a directory, format and list it */
		if (ISO_BY(FDV(&openfile, flags, fsd->type)) & CD_DIRECTORY) {
			/*
			printdirentheader(pathname);
			*/
			fprintf(w, "[");
			printdirents(w, &openfile, fsd);
			fprintf(w, "\n]\n");
		}
		/* if a file, print it on standard output */
		else
			extractdirent(&openfile, fsd, 0, 0);
	}
	else
		printf("Not found.\n");
}


bool parse_cdfs(FILE* w, cdimage* cdio, const char* name, int offs, bool first) {
	//im
	fs fsd;
	directent rootent;

	memset(&fsd, 0, sizeof(fsd));
	memset(&rootent, 0, sizeof(rootent));

	fsd.fd = cdio;
	

	/* is there a filesystem we can understand here? */
	if (iscdromfs(&rootent, &fsd, offs) ) {
		//printdirentheader("/");
		fprintf(w, "%s\"%s\": [", first? "\n":",\n", name);
		printdirents(w, &rootent, &fsd);
		fprintf(w, "\n]");
		
		return true;
	}
	else
		return false;

}