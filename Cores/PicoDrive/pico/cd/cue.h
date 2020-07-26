
typedef enum
{
	CT_UNKNOWN = 0,
	CT_ISO = 1,	/* 2048 B/sector */
	CT_BIN = 2,	/* 2352 B/sector */
	CT_MP3 = 3,
	CT_WAV = 4
} cue_track_type;

typedef struct
{
	char *fname;
	int pregap;		/* pregap for current track */
	int sector_offset;	/* in current file */
	int sector_xlength;
	cue_track_type type;
} cue_track;

typedef struct
{
	int track_count;
	cue_track tracks[0];
} cue_data_t;


cue_data_t *cue_parse(const char *fname);
void        cue_destroy(cue_data_t *data);

