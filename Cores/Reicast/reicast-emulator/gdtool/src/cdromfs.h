#pragma once

struct cdromtime {
    unsigned char years;    /* number of years since 1900 */
    unsigned char month;    /* month of the year */
    unsigned char day;  /* day of month */
    unsigned char hour; /* hour of day */
    unsigned char min;  /* minute of the hour */
    unsigned char sec;  /* second of the minute */
    unsigned char tz;   /* timezones, in quarter hour increments */
						/* or, longitude in 3.75 of a degree */
};


typedef void data_callback(void* ctx, void* data, int size);

struct cdimage {
	virtual void seek(int to) = 0;

	virtual int read(void* to, int count) = 0 ;
	virtual ~cdimage() { }
};


bool parse_cdfs(FILE* w, cdimage* cdio, const char* prefix, int offs, bool first);