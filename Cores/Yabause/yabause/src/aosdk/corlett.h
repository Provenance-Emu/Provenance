//
// Audio Overload
// Emulated music player
//
// (C) 2000-2008 Richard F. Bannister
//

// corlett.h

#define MAX_UNKNOWN_TAGS			32

typedef struct {
	char lib[256];
	char libaux[8][256];
	
	char inf_title[256];
	char inf_copy[256];
	char inf_artist[256];
	char inf_game[256];
	char inf_year[256];
	char inf_length[256];
	char inf_fade[256];

	char inf_refresh[256];
	
	char tag_name[MAX_UNKNOWN_TAGS][256];
	char tag_data[MAX_UNKNOWN_TAGS][256];

	u32 *res_section;
	u32 res_size;
} corlett_t;

int corlett_decode(u8 *input, u32 input_len, u8 **output, u64 *size, corlett_t **c);
u32 psfTimeToMS(char *str);

