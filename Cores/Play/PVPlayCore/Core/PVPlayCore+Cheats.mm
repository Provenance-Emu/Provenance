#import <PVPlay/PVPlay.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVLogging/PVLogging.h>
#import "PS2VM.h"

#include "PH_Generic.h"
#include "PS2VM.h"
#include "CGSH_Provenance_OGL.h"

#include "big_int_full.h"

extern CGSH_Provenance_OGL *gsHandler;
extern CPH_Generic *padHandler;
extern UIView *m_view;
extern CPS2VM *_ps2VM;

@implementation PVPlayCore (Cheats)

#pragma mark - Cheats
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType: (NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled  error:(NSError**)error {
	if (code && type && enabled) {
		ELOG(@"Applying Cheat Code %s %s %d\n", code.UTF8String, type.UTF8String, enabled);
		NSArray *multipleCodes = [code componentsSeparatedByString:@"+"];
		return [self applyCheat:multipleCodes setCodeType:codeType];
	}
	return true;
}

- (BOOL)applyCheat:(NSArray *)code_strings setCodeType: (NSString *)codeType {
	cheat_t cheat;
	cheat.codecnt=0;
	cheat.code=new u32[code_strings.count];
	for (NSString *singleCode in code_strings) {
		const char *cheatCode = [[singleCode
									stringByReplacingOccurrencesOfString:@":"
									withString:@""] UTF8String];
		if (singleCode != nil && singleCode.length > 0) {
			ELOG(@"Code %s Received\n", cheatCode);
			cheat.code[cheat.codecnt++]=(u32)strtol(cheatCode, NULL, 16);
		}
	}
	if (cheat.codecnt >= 2) {
		if ([codeType isEqualToString:@"Code Breaker"]) {
			ELOG(@"Processing Code Breaker Decryption of Codes\n");
			CBBatchDecrypt(&cheat);
		} else if ([codeType isEqualToString:@"Game Shark V3"]) {
			ELOG(@"Processing Code Game Shark Decryption of Codes\n");
			gs3BatchDecrypt(&cheat);
		} else if ([codeType isEqualToString:@"Pro Action Replay V1" ]) {
			ELOG(@"Processing Code ARV1 of Codes\n");
			ar1BatchDecrypt(&cheat);
		} else if ([codeType isEqualToString:@"Pro Action Replay V2" ]) {
			ELOG(@"Processing Code ARV2 of Codes\n");
			ar2BatchDecrypt(&cheat);
		} else {
			ELOG(@"Processing RAW Codes\n");
		}
		ELOG(@"Decrypted %d Cheats\n", cheat.codecnt);
		for (int i=0; i+1 < cheat.codecnt; i+=2) {
			u32 code=(u32)cheat.code[i];
			u32 value=(u32)cheat.code[i+1];
			ELOG(@"Decrypted: %d %d\n", code, value);
			code = code & 0xFFFFFFF;
			if (code > 0 && code < PS2::EE_RAM_SIZE) {
				ELOG(@"Applying Code %d %d\n", code, value);
				std::memcpy(
					(void*)((_ps2VM->m_ee->m_ram + code) ),
								&value,
								sizeof(u32));
				ELOG(@"Code %d %d applied successfully\n", code, value);
			} else {
				ELOG(@"Code %d (of %d) invalid with value %d\n", code, PS2::EE_RAM_SIZE, value);
				return false;
			}

		}
	}
	return true;
}

/* Code Courtesy of git@github.com:pyriell/omniconvert.git Cheat Code <-> Raw converter */

typedef unsigned long long u64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

typedef signed long long s64;
typedef signed int s32;
typedef signed short s16;
typedef signed char s8;

#define NAME_MAX_SIZE		50
//Status flags for codes
#define CODE_INVALID		(1 << 0) //something is wrong with the code (uneven number of octets)
#define CODE_NO_TARGET		(1 << 1) //The target device does not support this code type
//large enough for most codes
#define MAX_CODE_STEP		25 << 1

enum {
	FLAG_DEFAULT_ON,
	FLAG_MCODE,
	FLAG_COMMENTS
};

//some of what is in these structs is device specific
//but they make handy containers for all devices.
typedef struct {
	u32		id;
	char	*name;
	u32		namemax;
	char	*comment;
	u32		commentmax;
	u8		flag[3];
	u32		codecnt;
	u32		codemax;
	u32		*code;
	u8		state;
	void	*nxt;
} cheat_t;

cheat_t * cheatInit();

#define EXPANSION_DATA_FOLDER	0x0800
#define FLAGS_FOLDER		0x5 << 20
#define FLAGS_FOLDER_MEMBER	0x4 << 20
#define FLAGS_DISC_HASH		0x7 << 20

static u32 g_folderId;

void cheatClearFolderId() {
	g_folderId = 0;
}

cheat_t * cheatInit() {
	cheat_t *cheat = (cheat_t *)malloc(sizeof(cheat_t));
	if(!cheat) {
		ELOG(@"Unable to allocate memory for code container");
		exit(1);
	}

	cheat->name = (char *)malloc(sizeof(char) * (NAME_MAX_SIZE + 1));
	if(!cheat->name) {
		ELOG(@"Unable to allocate memory for cheat name");
		exit(1);
	}
	memset(cheat->name, 0, NAME_MAX_SIZE + 1);

	cheat->comment = (char *)malloc(sizeof(char) * (NAME_MAX_SIZE + 1));
	if(!cheat->name) {
		ELOG(@"Unable to allocate memory for cheat comments");
		exit(1);
	}
	memset(cheat->comment, 0, NAME_MAX_SIZE + 1);

	cheat->commentmax = cheat->namemax = NAME_MAX_SIZE;

	cheat->flag[0] = cheat->flag[1] = cheat->flag[2] = 0;

	cheat->code		= (u32 *)malloc(sizeof(u32) * MAX_CODE_STEP);
	if(!cheat->code) {
		ELOG(@"Unable to allocate initial memory for code");
		exit(1);
	}
	cheat->state = cheat->codecnt = 0;
	cheat->codemax = MAX_CODE_STEP;
	cheat->nxt = NULL;
	return cheat;
}

void cheatAppendOctet(cheat_t *cheat, u32 octet) {
	if(cheat->codecnt + 2 >= cheat->codemax) {
		cheat->codemax	+= MAX_CODE_STEP;
		cheat->code	=  (u32 *)realloc(cheat->code, sizeof(u32) * cheat->codemax);
		if(cheat->code == NULL) {
			ELOG(@"Unable to expand code");
			exit(1);
		}
	}
	cheat->code[cheat->codecnt] = octet;
	cheat->codecnt++;
}

void cheatAppendCodeFromText(cheat_t *cheat, char *addr, char *val) {
	u32 code;
	sscanf(addr, "%08X", &code);
	cheatAppendOctet(cheat, code);
	sscanf(val, "%08X", &code);
	cheatAppendOctet(cheat, code);
}

void cheatPrependOctet(cheat_t *cheat, u32 octet) {
	int i;
	if(cheat->codecnt < 1) {
		cheatAppendOctet(cheat, octet);
		return;
	}
	cheatAppendOctet(cheat, cheat->code[cheat->codecnt - 1]);
	for(i = cheat->codecnt - 2; i > 0; i--) {
		cheat->code[i] = cheat->code[i-1];
	}
	cheat->code[0] = octet;
}

void cheatRemoveOctets(cheat_t *cheat, int start, int count) {
	if(start >= cheat->codecnt || start < 0 || count < 1) return;
	if(start + count > cheat->codecnt) {
		cheat->codecnt -= count;
		return;
	}
	int i = start + count - 1;
	int j = cheat->codecnt - i;
	start--;
	while(j--) {
		cheat->code[start++] = cheat->code[i++];
	}
	cheat->codecnt -= count;
}

void cheatDestroy(cheat_t *cheat) {
	if(cheat) {
		if(cheat->name) free(cheat->name);
		if(cheat->comment) free(cheat->comment);
		if(cheat->code) free(cheat->code);
		free(cheat);
	}
}

u32 swapbytes(unsigned int val) {
		return (val << 24) | ((val << 8) & 0xFF0000) | ((val >> 8) & 0xFF00) | (val >> 24);
}

/* armlist */
typedef struct {
	char	l_ident[12];
	u32		version;
	u32		unknown;
	u32		size;
	u32		crc;
	u32		gamecnt;
	u32		codecnt;
} list_t;

/* Arc Four */

typedef struct {
	u8	perm[256];
	u8	index1;
	u8	index2;
} arc4_ctx_t;

void arc4_init(arc4_ctx_t *ctx, const u8 *key, int keylen);
void arc4_crypt(arc4_ctx_t *ctx, u8 *buf, int bufsize);

/* Some aliases */
#define ARC4_CTX	arc4_ctx_t
#define ARC4Init	arc4_init
#define ARC4Crypt	arc4_crypt
static __inline void swap_bytes(u8 *a, u8 *b)
{
	u8 tmp;

	tmp = *a;
	*a = *b;
	*b = tmp;
}

/*
 * Initialize an ARCFOUR context buffer using the supplied key,
 * which can have arbitrary length.
 */
void arc4_init(arc4_ctx_t *ctx, const u8 *key, int keylen)
{
	u8 j;
	int i;

	/* Initialize context with identity permutation */
	for (i = 0; i < 256; i++)
		ctx->perm[i] = (u8)i;
	ctx->index1 = 0;
	ctx->index2 = 0;

	/* Randomize the permutation using key data */
	for (j = i = 0; i < 256; i++) {
		j += ctx->perm[i] + key[i % keylen];
		swap_bytes(&ctx->perm[i], &ctx->perm[j]);
	}
}

/*
 * Encrypt data using the supplied ARCFOUR context buffer.
 * Since ARCFOUR is a stream cypher, this function is used
 * for both encryption and decryption.
 */
void arc4_crypt(arc4_ctx_t *ctx, u8 *buf, int bufsize)
{
	int i;
	u8 j;

	for (i = 0; i < bufsize; i++) {
		/* Update modification indicies */
		ctx->index1++;
		ctx->index2 += ctx->perm[ctx->index1];

		/* Modify permutation */
		swap_bytes(&ctx->perm[ctx->index1], &ctx->perm[ctx->index2]);

		/* Encrypt/decrypt next byte */
		j = ctx->perm[ctx->index1] + ctx->perm[ctx->index2];
		buf[i] ^= ctx->perm[j];
	}
}

/* Action Replay 2 */

#define AR1_SEED	0x05100518

u8 g_seed[4];

const u8 tbl_[4][32] = {
	{
		// seed table #0
		0x00, 0x1F, 0x9B, 0x69, 0xA5, 0x80, 0x90, 0xB2,
		0xD7, 0x44, 0xEC, 0x75, 0x3B, 0x62, 0x0C, 0xA3,
		0xA6, 0xE4, 0x1F, 0x4C, 0x05, 0xE4, 0x44, 0x6E,
		0xD9, 0x5B, 0x34, 0xE6, 0x08, 0x31, 0x91, 0x72,
	},
	{
		// seed table #1
		0x00, 0xAE, 0xF3, 0x7B, 0x12, 0xC9, 0x83, 0xF0,
		0xA9, 0x57, 0x50, 0x08, 0x04, 0x81, 0x02, 0x21,
		0x96, 0x09, 0x0F, 0x90, 0xC3, 0x62, 0x27, 0x21,
		0x3B, 0x22, 0x4E, 0x88, 0xF5, 0xC5, 0x75, 0x91,
	},
	{
		// seed table #2
		0x00, 0xE3, 0xA2, 0x45, 0x40, 0xE0, 0x09, 0xEA,
		0x42, 0x65, 0x1C, 0xC1, 0xEB, 0xB0, 0x69, 0x14,
		0x01, 0xD2, 0x8E, 0xFB, 0xFA, 0x86, 0x09, 0x95,
		0x1B, 0x61, 0x14, 0x0E, 0x99, 0x21, 0xEC, 0x40,
	},
	{
		// seed table #3
		0x00, 0x25, 0x6D, 0x4F, 0xC5, 0xCA, 0x04, 0x39,
		0x3A, 0x7D, 0x0D, 0xF1, 0x43, 0x05, 0x71, 0x66,
		0x82, 0x31, 0x21, 0xD8, 0xFE, 0x4D, 0xC2, 0xC8,
		0xCC, 0x09, 0xA0, 0x06, 0x49, 0xD5, 0xF1, 0x83,
	}
};

u8 nibble_flip(u8 byte) {
	return (byte << 4) | (byte >> 4);
}

u32 ar2decrypt(u32 code, u8 type, u8 seed) {
	if (type == 7) {
		if (seed & 1) type = 1;
		else return ~code;
	}

	u8 tmp[4];
	*(u32*)tmp = code;

	switch (type) {
		case 0:
			tmp[3] ^= tbl_[0][seed];
			tmp[2] ^= tbl_[1][seed];
			tmp[1] ^= tbl_[2][seed];
			tmp[0] ^= tbl_[3][seed];
			break;
		case 1:
			tmp[3] = nibble_flip(tmp[3]) ^ tbl_[0][seed];
			tmp[2] = nibble_flip(tmp[2]) ^ tbl_[2][seed];
			tmp[1] = nibble_flip(tmp[1]) ^ tbl_[3][seed];
			tmp[0] = nibble_flip(tmp[0]) ^ tbl_[1][seed];
			break;
		case 2:
			tmp[3] += tbl_[0][seed];
			tmp[2] += tbl_[1][seed];
			tmp[1] += tbl_[2][seed];
			tmp[0] += tbl_[3][seed];
			break;
		case 3:
			tmp[3] -= tbl_[3][seed];
			tmp[2] -= tbl_[2][seed];
			tmp[1] -= tbl_[1][seed];
			tmp[0] -= tbl_[0][seed];
			break;
		case 4:
			tmp[3] = (tmp[3] ^ tbl_[0][seed]) + tbl_[0][seed];
			tmp[2] = (tmp[2] ^ tbl_[3][seed]) + tbl_[3][seed];
			tmp[1] = (tmp[1] ^ tbl_[1][seed]) + tbl_[1][seed];
			tmp[0] = (tmp[0] ^ tbl_[2][seed]) + tbl_[2][seed];
			break;
		case 5:
			tmp[3] = (tmp[3] - tbl_[1][seed]) ^ tbl_[0][seed];
			tmp[2] = (tmp[2] - tbl_[2][seed]) ^ tbl_[1][seed];
			tmp[1] = (tmp[1] - tbl_[3][seed]) ^ tbl_[2][seed];
			tmp[0] = (tmp[0] - tbl_[0][seed]) ^ tbl_[3][seed];
			break;
		case 6:
			tmp[3] += tbl_[0][seed];
			tmp[2] -= tbl_[1][(seed + 1) & 0x1F];
			tmp[1] += tbl_[2][(seed + 2) & 0x1F];
			tmp[0] -= tbl_[3][(seed + 3) & 0x1F];
			break;
	}

	return *(u32*)tmp;
}

u32 ar2encrypt(u32 code, u8 type, u8 seed) {
	if (type == 7) {
		if (seed & 1) type = 1;
		else return ~code;
	}

	u8 tmp[4];
	*(u32*)tmp = code;

	switch (type) {
		case 0:
			tmp[3] ^= tbl_[0][seed];
			tmp[2] ^= tbl_[1][seed];
			tmp[1] ^= tbl_[2][seed];
			tmp[0] ^= tbl_[3][seed];
			break;
		case 1:
			tmp[3] = nibble_flip(tmp[3] ^ tbl_[0][seed]);
			tmp[2] = nibble_flip(tmp[2] ^ tbl_[2][seed]);
			tmp[1] = nibble_flip(tmp[1] ^ tbl_[3][seed]);
			tmp[0] = nibble_flip(tmp[0] ^ tbl_[1][seed]);
			break;
		case 2:
			tmp[3] -= tbl_[0][seed];
			tmp[2] -= tbl_[1][seed];
			tmp[1] -= tbl_[2][seed];
			tmp[0] -= tbl_[3][seed];
			break;
		case 3:
			tmp[3] += tbl_[3][seed];
			tmp[2] += tbl_[2][seed];
			tmp[1] += tbl_[1][seed];
			tmp[0] += tbl_[0][seed];
			break;
		case 4:
			tmp[3] = (tmp[3] - tbl_[0][seed]) ^ tbl_[0][seed];
			tmp[2] = (tmp[2] - tbl_[3][seed]) ^ tbl_[3][seed];
			tmp[1] = (tmp[1] - tbl_[1][seed]) ^ tbl_[1][seed];
			tmp[0] = (tmp[0] - tbl_[2][seed]) ^ tbl_[2][seed];
			break;
		case 5:
			tmp[3] = (tmp[3] ^ tbl_[0][seed]) + tbl_[1][seed];
			tmp[2] = (tmp[2] ^ tbl_[1][seed]) + tbl_[2][seed];
			tmp[1] = (tmp[1] ^ tbl_[2][seed]) + tbl_[3][seed];
			tmp[0] = (tmp[0] ^ tbl_[3][seed]) + tbl_[0][seed];
			break;
		case 6:
			tmp[3] -= tbl_[0][seed];
			tmp[2] += tbl_[1][(seed + 1) & 0x1F];
			tmp[1] -= tbl_[2][(seed + 2) & 0x1F];
			tmp[0] += tbl_[3][(seed + 3) & 0x1F];
			break;
	}

	return *(u32*)tmp;
}

//I keep the specific seed for this device separate from other seeds.
void ar2SetSeed(u32 key) {
	key = swapbytes(key);
	memcpy(g_seed, &key, 4);
}

u32 ar2GetSeed() {
	u32 key;
	memcpy(&key, g_seed, 4);
	key = swapbytes(key);
}

//Batch decrypt an array of u32s
void ar2BatchDecryptArr(u32 *code, u32 *size) {
	u32 i, j;

	for(i = 0; i < *size; i+=2) {
		code[i] = ar2decrypt(code[i], g_seed[0], g_seed[1]);
		code[i+1] = ar2decrypt(code[i+1], g_seed[2], g_seed[3]);
	}
}

//Batch decrypt a cheat struct
void ar2BatchDecrypt(cheat_t *cheat) {
	u32 i;
	u32 *code = cheat->code;
	for(i = 0; i < cheat->codecnt; i+=2) {
		code[i] = ar2decrypt(code[i], g_seed[0], g_seed[1]);
		code[i+1] = ar2decrypt(code[i+1], g_seed[2], g_seed[3]);
	}
}

//Deal with AR1 encryption
void ar1BatchDecrypt(cheat_t *cheat) {
	int i;
	u32 hold	= ar2GetSeed();
	u32 num 	= cheat->codecnt;
	u32 *code 	= cheat->code;
	ar2SetSeed(AR1_SEED);
	for(i = 0; i < num; i+=2) {
		code[i] = ar2decrypt(code[i], g_seed[0], g_seed[1]);
		code[i+1] = ar2decrypt(code[i+1], g_seed[2], g_seed[3]);
	}
	ar2SetSeed(hold);
}

void ar1BatchEncrypt(cheat_t *cheat) {
	int i;
	u32 hold	= ar2GetSeed();
	u32 num 	= cheat->codecnt;
	u32 *code 	= cheat->code;
	ar2SetSeed(AR1_SEED);
	for(i = 0; i < num; i+=2) {
		code[i] = ar2encrypt(code[i], g_seed[0], g_seed[1]);
		code[i+1] = ar2encrypt(code[i+1], g_seed[2], g_seed[3]);
	}
	ar2SetSeed(hold);
}

/* Code Breaker */

// V1 seed tables
static const u32 seedtable[3][16] = {
	{
		0x0A0B8D9B, 0x0A0133F8, 0x0AF733EC, 0x0A15C574,
		0x0A50AC20, 0x0A920FB9, 0x0A599F0B, 0x0A4AA0E3,
		0x0A21C012, 0x0A906254, 0x0A31FD54, 0x0A091C0E,
		0x0A372B38, 0x0A6F266C, 0x0A61DD4A, 0x0A0DBF92
	},
	{
		0x00288596, 0x0037DD28, 0x003BEEF1, 0x000BC822,
		0x00BC935D, 0x00A139F2, 0x00E9BBF8, 0x00F57F7B,
		0x0090D704, 0x001814D4, 0x00C5848E, 0x005B83E7,
		0x00108CF7, 0x0046CE5A, 0x003A5BF4, 0x006FAFFC
	},
	{
		0x1DD9A10A, 0xB95AB9B0, 0x5CF5D328, 0x95FE7F10,
		0x8E2D6303, 0x16BB6286, 0xE389324C, 0x07AC6EA8,
		0xAA4811D8, 0x76CE4E18, 0xFE447516, 0xF9CD94D0,
		0x4C24DEDB, 0x68275C4E, 0x72494382, 0xC8AA88E8
	}
};

/*
 * Encrypts a V1 code.
 */
void CB1EncryptCode(u32 *addr, u32 *val)
{
	u32 tmp;
	u8 cmd = *addr >> 28;

	tmp = *addr & 0xFF000000;
	*addr = ((*addr & 0xFF) << 16) | ((*addr >> 8) & 0xFFFF);
	*addr = (tmp | ((*addr + seedtable[1][cmd]) & 0x00FFFFFF)) ^ seedtable[0][cmd];

	if (cmd > 2) *val = *addr ^ (*val + seedtable[2][cmd]);
}

/*
 * Decrypts a V1 code.
 */
void CB1DecryptCode(u32 *addr, u32 *val)
{
	u32 tmp;
	u8 cmd = *addr >> 28;

	if (cmd > 2) *val = (*addr ^ *val) - seedtable[2][cmd];

	tmp = *addr ^ seedtable[0][cmd];
	*addr = tmp - seedtable[1][cmd];
	*addr = (tmp & 0xFF000000) | ((*addr & 0xFFFF) << 8) | ((*addr >> 16) & 0xFF);
}


/**
 * The new CB V7 encryption...
 */

// Default seed tables (1280 bytes total)
static const u8 defseeds[5][256] = {
	{
		0x84, 0x01, 0x21, 0xA4, 0xFA, 0x4D, 0x50, 0x8D, 0x75, 0x33, 0xC5, 0xF7, 0x4A, 0x6D, 0x7C, 0xA6,
		0x1C, 0xF8, 0x40, 0x18, 0xA1, 0xB3, 0xA2, 0xF9, 0x6A, 0x19, 0x63, 0x66, 0x29, 0xAE, 0x10, 0x75,
		0x84, 0x7D, 0xEC, 0x6A, 0xF9, 0x2D, 0x8E, 0x33, 0x44, 0x5C, 0x33, 0x6D, 0x78, 0x3E, 0x1B, 0x6C,
		0x02, 0xE0, 0x7D, 0x77, 0x1D, 0xB1, 0x61, 0x2A, 0xCD, 0xC1, 0x38, 0x53, 0x1F, 0xA1, 0x6E, 0x3D,
		0x03, 0x0D, 0x05, 0xDC, 0x50, 0x19, 0x85, 0x89, 0x9B, 0xF1, 0x8A, 0xC2, 0xD1, 0x5C, 0x22, 0xC4,
		0x11, 0x29, 0xF6, 0x13, 0xEC, 0x06, 0xE4, 0xBD, 0x08, 0x9E, 0xB7, 0x8D, 0x72, 0x92, 0x10, 0x3C,
		0x41, 0x4E, 0x81, 0x55, 0x08, 0x9C, 0xA3, 0xBC, 0xA1, 0x79, 0xB0, 0x7A, 0x94, 0x3A, 0x39, 0x95,
		0x7A, 0xC6, 0x96, 0x21, 0xB0, 0x07, 0x17, 0x5E, 0x53, 0x54, 0x08, 0xCF, 0x85, 0x6C, 0x4B, 0xBE,
		0x30, 0x82, 0xDD, 0x1D, 0x3A, 0x24, 0x3C, 0xB2, 0x67, 0x0C, 0x36, 0x03, 0x51, 0x60, 0x3F, 0x67,
		0xF1, 0xB2, 0x77, 0xDC, 0x12, 0x9D, 0x7B, 0xCE, 0x65, 0xF8, 0x75, 0xEA, 0x23, 0x63, 0x99, 0x54,
		0x37, 0xC0, 0x3C, 0x42, 0x77, 0x12, 0xB7, 0xCA, 0x54, 0xF1, 0x26, 0x1D, 0x1E, 0xD1, 0xAB, 0x2C,
		0xAF, 0xB6, 0x91, 0x2E, 0xBD, 0x84, 0x0B, 0xF2, 0x1A, 0x1E, 0x26, 0x1E, 0x00, 0x12, 0xB7, 0x77,
		0xD6, 0x61, 0x1C, 0xCE, 0xA9, 0x10, 0x19, 0xAA, 0x88, 0xE6, 0x35, 0x29, 0x32, 0x5F, 0x57, 0xA7,
		0x94, 0x93, 0xA1, 0x2B, 0xEB, 0x9B, 0x17, 0x2A, 0xAA, 0x60, 0xD5, 0x19, 0xB2, 0x4E, 0x5A, 0xE2,
		0xC9, 0x4A, 0x00, 0x68, 0x6E, 0x59, 0x36, 0xA6, 0xA0, 0xF9, 0x19, 0xA2, 0xC7, 0xC9, 0xD4, 0x29,
		0x5C, 0x99, 0x3C, 0x5C, 0xE2, 0xCB, 0x94, 0x40, 0x8B, 0xF4, 0x3B, 0xD2, 0x38, 0x7D, 0xBF, 0xD0
	},
	{
		0xCC, 0x6D, 0x5D, 0x0B, 0x70, 0x25, 0x5D, 0x68, 0xFE, 0xBE, 0x6C, 0x3F, 0xA4, 0xD9, 0x95, 0x5F,
		0x30, 0xAE, 0x34, 0x39, 0x00, 0x89, 0xDC, 0x5A, 0xC8, 0x82, 0x24, 0x3A, 0xFC, 0xDA, 0x3C, 0x1F,
		0x73, 0x3F, 0x63, 0xAA, 0x53, 0xBD, 0x4E, 0xB5, 0x33, 0x48, 0x59, 0xC1, 0xB7, 0xE0, 0x0C, 0x99,
		0xEC, 0x3B, 0x32, 0x26, 0xB3, 0xB1, 0xE2, 0x8E, 0x54, 0x41, 0x55, 0xDB, 0x1D, 0x90, 0x0B, 0x48,
		0xF3, 0x3F, 0xCA, 0x1F, 0x19, 0xEB, 0x7F, 0x56, 0x52, 0xD7, 0x20, 0x67, 0x59, 0x4F, 0x4E, 0xDC,
		0xBB, 0x6A, 0x8E, 0x45, 0x88, 0x0B, 0x93, 0xAC, 0xCD, 0x0E, 0x29, 0x18, 0x7A, 0x16, 0x8D, 0x8D,
		0xC2, 0x88, 0x6A, 0x9D, 0x39, 0xF4, 0x93, 0x14, 0xCD, 0xE0, 0x6B, 0xC7, 0x28, 0x21, 0x5C, 0x97,
		0x70, 0x7C, 0xAB, 0x53, 0x46, 0x33, 0x03, 0x18, 0xDF, 0x91, 0xFE, 0x06, 0xC0, 0xFF, 0xA2, 0x58,
		0xF3, 0xB0, 0x6B, 0x9B, 0x71, 0x91, 0x23, 0xDA, 0x92, 0x67, 0x14, 0x34, 0x9F, 0xA5, 0xAF, 0x65,
		0x62, 0xE8, 0x7F, 0x79, 0x35, 0x32, 0x29, 0x3E, 0x4F, 0xDC, 0xC7, 0x8E, 0xF1, 0x21, 0x9D, 0x3B,
		0x61, 0xFC, 0x0B, 0x02, 0xEC, 0xE4, 0xA7, 0xEA, 0x77, 0xE7, 0x21, 0x63, 0x97, 0x7F, 0x23, 0x8A,
		0x8B, 0xBE, 0x4E, 0x90, 0xC0, 0x89, 0x04, 0x44, 0x90, 0x57, 0x41, 0xB5, 0x74, 0xAD, 0xB1, 0xE9,
		0xF3, 0x91, 0xC7, 0x27, 0x3E, 0x00, 0x81, 0x99, 0xEE, 0x38, 0xF5, 0x32, 0x4F, 0x27, 0x4F, 0x64,
		0x39, 0x3D, 0xD3, 0x0B, 0x99, 0xD5, 0x99, 0xD6, 0x10, 0x4B, 0x43, 0x17, 0x38, 0x34, 0x54, 0x63,
		0x19, 0x36, 0xBD, 0x15, 0xB1, 0x06, 0x1E, 0xDE, 0x1B, 0xAF, 0xEB, 0xFA, 0x56, 0xB8, 0x8D, 0x9D,
		0x14, 0x1A, 0xA6, 0x49, 0x56, 0x19, 0xCA, 0xC1, 0x40, 0x6D, 0x71, 0xDE, 0x68, 0xC1, 0xC3, 0x4A
	},
	{
		0x69, 0x31, 0x5C, 0xAB, 0x7F, 0x5B, 0xE9, 0x81, 0x32, 0x58, 0x32, 0x0A, 0x97, 0xF3, 0xC7, 0xCF,
		0xBB, 0x1D, 0xCF, 0x0E, 0x83, 0x35, 0x4C, 0x58, 0xCE, 0xF7, 0x8A, 0xE4, 0xB0, 0xE4, 0x83, 0x48,
		0x81, 0x77, 0x7C, 0x3F, 0xBC, 0x27, 0x3A, 0x1B, 0xA4, 0xE9, 0x06, 0xA4, 0x15, 0xAB, 0x90, 0x10,
		0x7D, 0x74, 0xDA, 0xFC, 0x36, 0x09, 0xCC, 0xF7, 0x12, 0xB6, 0xF4, 0x94, 0xE9, 0x8B, 0x6A, 0x3B,
		0x5E, 0x71, 0x46, 0x3E, 0x0B, 0x78, 0xAD, 0x3B, 0x94, 0x5B, 0x89, 0x85, 0xA3, 0xE0, 0x01, 0xEB,
		0x84, 0x41, 0xAA, 0xD7, 0xB3, 0x17, 0x16, 0xC3, 0x6C, 0xB1, 0x81, 0x73, 0xEC, 0xE4, 0x6E, 0x09,
		0x56, 0xEE, 0x7A, 0xF6, 0x75, 0x6A, 0x73, 0x95, 0x8D, 0xDA, 0x51, 0x63, 0x8B, 0xBB, 0xE0, 0x4D,
		0xF8, 0xA0, 0x27, 0xF2, 0x9F, 0xC8, 0x15, 0x5A, 0x23, 0x85, 0x58, 0x04, 0x4A, 0x57, 0x28, 0x20,
		0x6D, 0x9D, 0x85, 0x83, 0x3C, 0xBF, 0x02, 0xB0, 0x96, 0xE8, 0x73, 0x6F, 0x20, 0x6E, 0xB0, 0xE4,
		0xC6, 0xFA, 0x71, 0xA6, 0x5D, 0xC5, 0xA0, 0xA3, 0xF8, 0x5C, 0x99, 0xCB, 0x9C, 0x04, 0x3A, 0xB2,
		0x04, 0x8D, 0xA2, 0x9D, 0x32, 0xF0, 0xBD, 0xAA, 0xEA, 0x81, 0x79, 0xE2, 0xA1, 0xBA, 0x89, 0x12,
		0xD5, 0x9F, 0x81, 0xEB, 0x63, 0xE7, 0xE5, 0xD4, 0xE9, 0x0E, 0x30, 0xBC, 0xCB, 0x70, 0xDD, 0x51,
		0x77, 0xC0, 0x80, 0xB3, 0x49, 0x03, 0x9A, 0xB8, 0x8C, 0xA7, 0x63, 0x62, 0x8F, 0x72, 0x5C, 0xA6,
		0xA0, 0xCF, 0x4F, 0xB4, 0x86, 0xFD, 0x49, 0xFA, 0x4A, 0x85, 0xDB, 0xFE, 0x61, 0xB7, 0x3A, 0xD7,
		0x83, 0x70, 0x57, 0x49, 0x83, 0xA7, 0x10, 0x73, 0x74, 0x37, 0x87, 0xFD, 0x6B, 0x28, 0xB7, 0x31,
		0x1E, 0x54, 0x1C, 0xE9, 0xD0, 0xB1, 0xCA, 0x76, 0x3B, 0x21, 0xF7, 0x67, 0xBB, 0x48, 0x69, 0x39
	},
	{
		0x8D, 0xD1, 0x8C, 0x7B, 0x83, 0x8C, 0xA8, 0x18, 0xA7, 0x4A, 0x14, 0x03, 0x88, 0xB3, 0xCE, 0x74,
		0xBF, 0x5B, 0x87, 0x67, 0xA7, 0x85, 0x6B, 0x62, 0x96, 0x7C, 0xA9, 0xA6, 0xF6, 0x9E, 0xF4, 0x73,
		0xC5, 0xC4, 0xB0, 0x2B, 0x73, 0x2E, 0x36, 0x77, 0xDF, 0xBA, 0x57, 0xFF, 0x7F, 0xE9, 0x84, 0xE1,
		0x8D, 0x7B, 0xA2, 0xEF, 0x4F, 0x10, 0xF3, 0xD3, 0xE8, 0xB4, 0xBA, 0x20, 0x28, 0x79, 0x18, 0xD6,
		0x0F, 0x1C, 0xAA, 0xBD, 0x0E, 0x45, 0xF7, 0x6C, 0x68, 0xB9, 0x29, 0x40, 0x1A, 0xCF, 0xB6, 0x0A,
		0x13, 0xF8, 0xC0, 0x9C, 0x87, 0x10, 0x36, 0x14, 0x73, 0xA1, 0x75, 0x27, 0x14, 0x55, 0xAF, 0x78,
		0x9A, 0x08, 0xC9, 0x05, 0xF2, 0xEC, 0x24, 0x1B, 0x07, 0x4A, 0xDC, 0xF6, 0x48, 0xC6, 0x25, 0xCD,
		0x12, 0x1D, 0xAF, 0x51, 0x8F, 0xE9, 0xCA, 0x2C, 0x80, 0x57, 0x78, 0xB7, 0x96, 0x07, 0x19, 0x77,
		0x6E, 0x16, 0x45, 0x47, 0x8E, 0x9C, 0x18, 0x55, 0xF1, 0x72, 0xB3, 0x8A, 0xEA, 0x4E, 0x8D, 0x90,
		0x2E, 0xBC, 0x08, 0xAC, 0xF6, 0xA0, 0x5C, 0x16, 0xE3, 0x7A, 0xEE, 0x67, 0xB8, 0x58, 0xDC, 0x16,
		0x40, 0xED, 0xF9, 0x18, 0xB3, 0x0E, 0xD8, 0xEE, 0xE1, 0xFA, 0xC3, 0x9F, 0x82, 0x99, 0x32, 0x41,
		0x34, 0xBE, 0xC9, 0x50, 0x36, 0xE5, 0x66, 0xAA, 0x0D, 0x43, 0xF0, 0x3F, 0x26, 0x7C, 0xF3, 0x87,
		0x26, 0xA4, 0xF5, 0xF8, 0xA0, 0x32, 0x46, 0x74, 0x2E, 0x5A, 0xE2, 0xE7, 0x6B, 0x02, 0xA8, 0xD0,
		0xCF, 0xB8, 0x33, 0x15, 0x3B, 0x4F, 0xC7, 0x7A, 0xE8, 0x3D, 0x75, 0xD2, 0xFE, 0x42, 0x22, 0x22,
		0xA8, 0x21, 0x33, 0xFB, 0xB0, 0x87, 0x92, 0x99, 0xCA, 0xD7, 0xD7, 0x88, 0xAC, 0xE4, 0x75, 0x83,
		0x56, 0xBF, 0xCE, 0xED, 0x4F, 0xF6, 0x22, 0x07, 0xCA, 0xBC, 0xD2, 0xEF, 0x1B, 0x75, 0xD6, 0x2D
	},
	{
		0xD2, 0x4F, 0x76, 0x51, 0xEB, 0xA1, 0xAD, 0x84, 0xD6, 0x19, 0xE6, 0x97, 0xD9, 0xD3, 0x58, 0x6B,
		0xFB, 0xB8, 0x20, 0xFD, 0x49, 0x56, 0x1B, 0x50, 0x61, 0x10, 0x57, 0xB8, 0x78, 0x07, 0xC1, 0x4A,
		0xA2, 0xEA, 0x47, 0x80, 0x00, 0x4A, 0xB3, 0x4E, 0x6F, 0x1A, 0xC1, 0xD5, 0x22, 0xF8, 0x54, 0x2F,
		0x33, 0xE5, 0x7F, 0xB4, 0x13, 0x02, 0xA3, 0xA1, 0x8B, 0x1C, 0x6F, 0x19, 0xD6, 0x42, 0xB3, 0x24,
		0x4B, 0x04, 0x30, 0x10, 0x02, 0x23, 0x6F, 0x10, 0x03, 0x4B, 0x0E, 0x33, 0x55, 0x22, 0xA4, 0x78,
		0xEC, 0xD2, 0x4A, 0x11, 0x8B, 0xFC, 0xFF, 0x14, 0x7A, 0xED, 0x06, 0x47, 0x86, 0xFC, 0xF0, 0x03,
		0x0F, 0x75, 0x07, 0xE4, 0x9A, 0xD3, 0xBB, 0x0D, 0x97, 0x1F, 0x6F, 0x80, 0x62, 0xA6, 0x9E, 0xC6,
		0xB1, 0x10, 0x81, 0xA1, 0x6D, 0x55, 0x0F, 0x9E, 0x1B, 0xB7, 0xF5, 0xDC, 0x62, 0xA8, 0x63, 0x58,
		0xCF, 0x2F, 0x6A, 0xAD, 0x5E, 0xD3, 0x3F, 0xBD, 0x8D, 0x9B, 0x2A, 0x8B, 0xDF, 0x60, 0xB9, 0xAF,
		0xAA, 0x70, 0xB4, 0xA8, 0x17, 0x99, 0x72, 0xB9, 0x88, 0x9D, 0x3D, 0x2A, 0x11, 0x87, 0x1E, 0xF3,
		0x9D, 0x33, 0x8D, 0xED, 0x52, 0x60, 0x36, 0x71, 0xFF, 0x7B, 0x37, 0x84, 0x3D, 0x27, 0x9E, 0xD9,
		0xDF, 0x58, 0xF7, 0xC2, 0x58, 0x0C, 0x9D, 0x5E, 0xEE, 0x23, 0x83, 0x70, 0x3F, 0x95, 0xBC, 0xF5,
		0x42, 0x86, 0x91, 0x5B, 0x3F, 0x77, 0x31, 0xD2, 0xB7, 0x09, 0x59, 0x53, 0xF5, 0xF2, 0xE5, 0xF1,
		0xDC, 0x92, 0x83, 0x14, 0xC1, 0xA2, 0x25, 0x62, 0x13, 0xFD, 0xD4, 0xC5, 0x54, 0x9D, 0x9C, 0x27,
		0x6C, 0xC2, 0x75, 0x8B, 0xBC, 0xC7, 0x4E, 0x0A, 0xF6, 0x5C, 0x2F, 0x12, 0x8E, 0x25, 0xBB, 0xF2,
		0x5F, 0x89, 0xAA, 0xEA, 0xD9, 0xCD, 0x05, 0x74, 0x20, 0xD6, 0x17, 0xED, 0xF0, 0x66, 0x6C, 0x7B
	}
};

// Default ARCFOUR key (20 bytes)
static const u32 defkey[5] = {
	0xD0DBA9D7, 0x13A0A96C, 0x80410DF0, 0x2CCDBE1F, 0xE570A86B
};

// RSA parameters
static const u64 rsa_modulus = 18446744073709551605ULL; // = 0xFFFFFFFFFFFFFFF5
static const u64 rsa_dec_key = 11;
/*
 * This is how I calculated the encryption key e from d:
 * (some number theory)
 *
 *	d = 11
 *	n = 18446744073709551605
 *	e = d^(-1) mod phi(n)
 *
 *	n factored:
 *	n = 5 * 2551 * 1446236305269271
 *	  = p*q*r, only single prime factors
 *
 *	phi(n) = phi(p*q*r)
 *	       = phi(p) * phi(q) * phi(r), phi(p) = p - 1
 *	       = (p-1)*(q-1)*(r-1)
 *	       = (5-1) * (2551-1) * (1446236305269271-1)
 *	       = 4 * 2550 * 1446236305269270
 *	       = 14751610313746554000
 *
 *	e = 11^(-1) mod 14751610313746554000
 *	e = 2682110966135737091
 */
static const u64 rsa_enc_key = 2682110966135737091ULL;

static u8 seeds[5][256];	// Current set of seeds
static u32 key[5];		// Current ARCFOUR key
static u32 oldkey[5];		// Backup of ARCFOUR key
static ARC4_CTX ctx;		// ARCFOUR context
static int v7enc;		// Flag: Use V7 encryption?
static int v7init;		// Flag: V7 encryption already initialized?
static int beefcodf;		// Flag: Is it BEEFC0DF?
//u32 unkwn;

u32 MulInverse(u32 word);
u32 MulEncrypt(u32 a, u32 b);
u32 MulDecrypt(u32 a, u32 b);
void RSACrypt(u32 *addr, u32 *val, u64 rsakey);
void CB7Beefcode(int init, u32 val);
void CB7EncryptCode(u32 *addr, u32 *val);
void CB7DecryptCode(u32 *addr, u32 *val);
int CB7SelfTest(void);
void CBReset(void);
void CBEncryptCode(u32 *addr, u32 *val);
void CBDecryptCode(u32 *addr, u32 *val);

/*
 * Computes the multiplicative inverse of @word, modulo (2^32).
 * I think this is borrowed from IDEA. ;)
 */
u32 MulInverse(u32 word)
{
	// Original MIPS R5900 coding converted to C
	u32 a0, a1, a2, a3;
	u32 v0, v1;
	u32 t1;

	if (word == 1) return 1;

	a2 = (0 - word) % word;
	if (!a2) return 1;

	t1 = 1;
	a3 = word;
	a0 = 0 - (0xFFFFFFFF / word);

	do {
		v0 = a3 / a2;
		v1 = a3 % a2;
		a1 = a2;
		a3 = a1;
		a1 = a0;
		a2 = v1;
		v0 = v0 * a1;
		a0 = t1 - v0;
		t1 = a1;
	} while (a2);

	return t1;
}

/*
 * Multiplication, modulo (2^32)
 */
u32 MulEncrypt(u32 a, u32 b)
{
	return (a * (b | 1));
}

/*
 * Multiplication with multiplicative inverse, modulo (2^32)
 */
u32 MulDecrypt(u32 a, u32 b)
{
	return (a * MulInverse(b | 1));
}

/*
 * RSA encryption/decryption
 *
 * NOTE: Uses the excellent BIG_INT library by
 * Alexander Valyalkin (valyala@gmail.com)
 */
void RSACrypt(u32 *addr, u32 *val, u64 rsakey)
{
	big_int *code, *exp, *mod;
	int cmp_flag;

	// Setup big_int number for code
	code = big_int_create(2);
	code->len = 2;
	code->num[0] = *val;
	code->num[1] = *addr;

	// Setup modulus
	mod = big_int_create(2);
	mod->len = 2;
	*(u64*)mod->num = rsa_modulus;

	// Exponentiation is only invertible if code < modulus
	big_int_cmp(code, mod, &cmp_flag);
	if (cmp_flag < 0) {
		// Setup exponent
		exp = big_int_create(2);
		exp->len = 2;
		*(u64*)exp->num = rsakey;

		// Encryption: c = m^e mod n
		// Decryption: m = c^d mod n
		big_int_powmod(code, exp, mod, code);

		// Save result
		*addr = code->num[1];
		*val  = code->num[0];

		// Deallocate big_int number
		big_int_destroy(exp);
	}

	big_int_destroy(code);
	big_int_destroy(mod);
}

/*
 * Used to generate/change the encryption key and seeds.
 * "Beefcode" is the new V7+ seed code:
 * BEEFC0DE VVVVVVVV, where VVVVVVVV = val.
 */
void CB7Beefcode(int init, u32 val)
{
	int i;
	u8 *p = (u8*)&val; // Easy access to all bytes of val

	// Setup key and seeds
	if (init) {
		beefcodf = 0;
		//unkwn = 0;
		memcpy(key, defkey, sizeof(defkey));

		if (val) {
			memcpy(seeds, defseeds, sizeof(defseeds));
			key[0] = (seeds[3][p[3]] << 24) | (seeds[2][p[2]] << 16) | (seeds[1][p[1]] << 8) | seeds[0][p[0]];
			key[1] = (seeds[0][p[3]] << 24) | (seeds[3][p[2]] << 16) | (seeds[2][p[1]] << 8) | seeds[1][p[0]];
			key[2] = (seeds[1][p[3]] << 24) | (seeds[0][p[2]] << 16) | (seeds[3][p[1]] << 8) | seeds[2][p[0]];
			key[3] = (seeds[2][p[3]] << 24) | (seeds[1][p[2]] << 16) | (seeds[0][p[1]] << 8) | seeds[3][p[0]];
		} else {
			memset(seeds, 0, sizeof(seeds));
		}
	} else {
		if (val) {
			key[0] = (seeds[3][p[3]] << 24) | (seeds[2][p[2]] << 16) | (seeds[1][p[1]] << 8) | seeds[0][p[0]];
			key[1] = (seeds[0][p[3]] << 24) | (seeds[3][p[2]] << 16) | (seeds[2][p[1]] << 8) | seeds[1][p[0]];
			key[2] = (seeds[1][p[3]] << 24) | (seeds[0][p[2]] << 16) | (seeds[3][p[1]] << 8) | seeds[2][p[0]];
			key[3] = (seeds[2][p[3]] << 24) | (seeds[1][p[2]] << 16) | (seeds[0][p[1]] << 8) | seeds[3][p[0]];
		} else {
			memset(seeds, 0, sizeof(seeds));
			key[0] = 0;
			key[1] = 0;
			key[2] = 0;
			key[3] = 0;
		}
	}

	// Use key to encrypt seeds with ARCFOUR algorithm
	for (i = 0; i < 5; i++) {
		// Setup ARCFOUR context with key
		ARC4Init(&ctx, (u8*)key, 20);
		// Encrypt seeds
		ARC4Crypt(&ctx, &seeds[i][0], 256);
		// Encrypt original key for next round
		ARC4Crypt(&ctx, (u8*)key, 20);
	}

	// Backup key
	memcpy(oldkey, key, sizeof(key));
}

/*
 * Encrypts a V7+ code.
 */
void CB7EncryptCode(u32 *addr, u32 *val)
{
	int i;
	u32 code[2];
	u32 oldaddr, oldval;

	oldaddr = *addr;
	oldval  = *val;

	// Step 1: Multiplication, modulo (2^32)
	*addr = MulEncrypt(*addr, oldkey[0] - oldkey[1]);
	*val  = MulEncrypt(*val,  oldkey[2] + oldkey[3]);

	// Step 2: ARCFOUR
	code[0] = *addr;
	code[1] = *val;
	ARC4Init(&ctx, (u8*)key, 20);
	ARC4Crypt(&ctx, (u8*)code, 8);
	*addr = code[0];
	*val  = code[1];

	// Step 3: RSA
	RSACrypt(addr, val, rsa_enc_key);

	// Step 4: Encryption loop of 64 cycles, using the generated seeds
	for (i = 0; i <= 63; i++) {
		*addr = ((*addr + ((u32*)seeds[2])[i]) ^ ((u32*)seeds[0])[i]) - (*val ^ ((u32*)seeds[4])[i]);
		*val  = ((*val - ((u32*)seeds[3])[i]) ^ ((u32*)seeds[1])[i]) + (*addr ^ ((u32*)seeds[4])[i]);
	}

	// BEEFC0DE
	if ((oldaddr & 0xFFFFFFFE) == 0xBEEFC0DE) {
		CB7Beefcode(0, oldval);
		//beefcodf = 1;
		return;
	}

	// BEEFC0DF
	if (beefcodf) {
		code[0] = oldaddr;
		code[1] = oldval;
		ARC4Init(&ctx, (u8*)code, 8);
		ARC4Crypt(&ctx, (u8*)seeds, sizeof(seeds));
		beefcodf = 0;
		//unkwn = 0;
		return;
	}
}

/*
 * Decrypts a V7+ code.
 */
void CB7DecryptCode(u32 *addr, u32 *val)
{
	int i;
	u32 code[2];

	// Step 1: Decryption loop of 64 cycles, using the generated seeds
	for (i = 63; i >= 0; i--) {
		*val  = ((*val - (*addr ^ ((u32*)seeds[4])[i])) ^ ((u32*)seeds[1])[i]) + ((u32*)seeds[3])[i];
		*addr = ((*addr + (*val ^ ((u32*)seeds[4])[i])) ^ ((u32*)seeds[0])[i]) - ((u32*)seeds[2])[i];
	}

	// Step 2: RSA
	RSACrypt(addr, val, rsa_dec_key);

	// Step 3: ARCFOUR
	code[0] = *addr;
	code[1] = *val;
	ARC4Init(&ctx, (u8*)key, 20);
	ARC4Crypt(&ctx, (u8*)code, 8);
	*addr = code[0];
	*val  = code[1];

	// Step 4: Multiplication with multiplicative inverse, modulo (2^32)
	*addr = MulDecrypt(*addr, oldkey[0] - oldkey[1]);
	*val  = MulDecrypt(*val,  oldkey[2] + oldkey[3]);

	// BEEFC0DF
	if (beefcodf) {
		code[0] = *addr;
		code[1] = *val;
		ARC4Init(&ctx, (u8*)code, 8);
		ARC4Crypt(&ctx, (u8*)seeds, sizeof(seeds));
		beefcodf = 0;
		//unkwn = 0;
		return;
	}

	// BEEFC0DE
	if ((*addr & 0xFFFFFFFE) == 0xBEEFC0DE) {
		CB7Beefcode(0, *val);
		//beefcodf = 1;
		return;
	}
}

/*
 * Checks if V7 encryption/decryption works properly.
 */
#define NUM_TESTCODES	3

int CB7SelfTest(void)
{
	static const u32 testcodes[NUM_TESTCODES*2] = {
		0x000FFFFE, 0x0000007D,
		0x90175B28, 0x0C061A24,
		0x20323260, 0xFFFFFFFF
	};
	u32 addr, val;
	int i;

	// Generate some random seeds
	CB7Beefcode(1, (u32)rand());
	CB7Beefcode(0, (u32)rand());

	// Check if D(E(M)) = M
	for (i = 0; i < NUM_TESTCODES; i++) {
		addr = testcodes[i*2];
		val  = testcodes[i*2+1];

		CB7EncryptCode(&addr, &val);
		CB7DecryptCode(&addr, &val);

		if ((addr != testcodes[i*2]) || (val != testcodes[i*2+1]))
			return -1;
	}

	return 0;
}


/**
 * Common functions for both V1 and V7.
 */

/*
 * Resets the CB encryption.  Must be called before processing
 * a code list using CBEncryptCode() or CBDecryptCode()!
 */
void CBReset(void)
{
	// Clear flags
	v7enc = 0;
	v7init = 0;
	beefcodf = 0;
}

/*
 * Set common CB V7 encryption (B4336FA9 4DFEFB79) which is used by CMGSCCC.com
 */
void CBSetCommonV7(void)
{
	v7enc = 1;
	CB7Beefcode(1, 0);
	v7init = 1;
	beefcodf = 0;
}

/*
 * Used to encrypt a list of CB codes (V1 + V7).
 */
void CBEncryptCode(u32 *addr, u32 *val)
{
	u32 oldaddr, oldval;

	oldaddr = *addr;
	oldval  = *val;

	if (v7enc)
		CB7EncryptCode(addr, val);
	else
		CB1EncryptCode(addr, val);

	if ((oldaddr & 0xFFFFFFFE) == 0xBEEFC0DE) {
		if (!v7init) {
			// Init seeds
			CB7Beefcode(1, oldval);
			v7init = 1;
		} else {
			// Change original seeds
			CB7Beefcode(0, oldval);
		}
		v7enc = 1;
		beefcodf = oldaddr & 1;
	}
}

/*
 * Used to decrypt a list of CB codes (V1 + V7).
 */
void CBDecryptCode(u32 *addr, u32 *val)
{
	if (v7enc)
		CB7DecryptCode(addr, val);
	else
		CB1DecryptCode(addr, val);

	if ((*addr & 0xFFFFFFFE) == 0xBEEFC0DE) {
		if (!v7init) {
			// Init seeds
			CB7Beefcode(1, *val);
			v7init = 1;
		} else {
			// Change original seeds
			CB7Beefcode(0, *val);
		}
		v7enc = 1;
		beefcodf = *addr & 1;
	}
}

/*
 * Wrapper functions for encrypting and decrypting batches of code lines,
 * i.e. an entire cheat.
 */
void CBBatchDecrypt(cheat_t *cheat) {
	int i, was_beefcode = 0, num = 0;
	u32 *code = cheat->code;
	for(i = 0; i < cheat->codecnt; i+=2) {
		CBDecryptCode(&code[i], &code[i+1]);
	}
}

/* Game Shark */

//mask for the msb/sign bit
#define SMASK 0x80000000

//mask for the lower bits of a word.
#define LMASK 0x7FFFFFFF

//Size of the state vector
#define MT_STATE_SIZE	624

//Magical Mersenne masks
#define MT_MASK_B		0x9D2C5680
#define MT_MASK_C		0xEFC60000

//Offset for recurrence relationship
#define MT_REC_OFFSET	397
#define MT_BREAK_OFFSET	227

#define MT_MULTIPLIER	69069

enum {
	GS3_CRYPT_X1,
	GS3_CRYPT_2,
	GS3_CRYPT_1,
	GS3_CRYPT_3,
	GS3_CRYPT_4 = GS3_CRYPT_3,
	GS3_CRYPT_X2 = GS3_CRYPT_3
};

//maximum number of crypt tables required for encryption
#define GS3_NUM_TABLES 4

#define BYTES_TO_WORD(a,b,c,d) ((a << 24) | (b << 16) | (c << 8) | d)
#define BYTES_TO_HALF(a,b) ((a << 8) | b)
#define GETBYTE(word, num) ((word >> ((num-1) << 3)) & 0xFF)
#define DECRYPT_MASK 0xF1FFFFFF

typedef struct {
	int size;
	unsigned char table[0x100];	//Lock in to the maximum table size rather than malloc.
} t_crypt_table;

static int passcount = MT_STATE_SIZE;
static u32 gs3_mtStateTbl_code[MT_STATE_SIZE] = { 0 };
static u32 gs3_mtStateTbl_p2m[MT_STATE_SIZE] = { 0 };
static u32 gs3_decision_matrix[2] = { 0, 0x9908B0DF };
static u16 gs3_hseeds[3] = {0x6C27, 0x1D38, 0x7FE1};
//static int gs3_tbl_size[GS3_NUM_TABLES] = { 0x40, 0x39, 0x19, 0x100 };
static t_crypt_table gs3_encrypt_seeds[GS3_NUM_TABLES] = { { 0x40, {0} }, { 0x39, {0} },  { 0x19, {0} }, { 0x100, {0} } };
static t_crypt_table gs3_decrypt_seeds[GS3_NUM_TABLES] = { { 0x40, {0} }, { 0x39, {0} },  { 0x19, {0} }, { 0x100, {0} } };
static u8 gs3_init = 0;
static u8 gs3_linetwo = 0;
static u8 gs3_xkey;		//key for second line of two line code types

/***************************************************************
Gameshark Version 5+ Routines

While Gameshark versions 3 and up all use the same encryption,
Version 5 introduced a verification system for the codes.  The
verification consists of a prefixed code line, beginning with
"76" that contains the CCITT 16-bit CRC of all the lines in the
code.  The lines are summed as they appear, to the outside world
i.e. in a big endian byte order.

The verification lines are unnecessary (so far as I know).  You
can just as easily use raw codes or encrypted codes without
them.

There is another verifier that begins with a "77".  This is
for the automatic mode, and helps identify the game.  It is
probably a CRC of the ELF Header, or as quickly as detection
attempts are made, the SYSTEM.CNF file.  I attempted to use
the feature with only the code file included on the disc
(official codes), and detection always failed with version 5
software.  These verifiers are wholly unnecessary, and
building them may be a complete waste of time, if the feature
doesn't even work properly.

The routines have the "gs3" prefix only for simplicity's sake.
***************************************************************/

u16 ccitt_table[256];
u16 ccitt_poly = 0x1021;
u8 gs3Version5 = 0;

void gs3SetVersion5(u8 flag) {
	gs3Version5 = flag;
}

u8 gs3IsVersion5() {
	return gs3Version5;
}

void gs3CcittBuildSeeds (void){
	short tmp;
	int i, j;
	for(i = 0; i < 256; i++) {
		tmp = 0;
		tmp = i << 8;
		for(j = 0; j < 8; j++) {
			if((tmp & 0x8000) > 0) {
				tmp = ((tmp << 1) ^ ccitt_poly) & 0xFFFF;
			}
			else {
				tmp <<= 1;
			}

		}
		ccitt_table[i] = tmp&0xFFFF;
	}
	return;
}

u16 gs3CcittCrc(const u8 *bytes, const int bytecount) {
	if (bytecount == 0) return 0;
	unsigned short crc;
	int j;
	crc = 0;
	for(j = 0; j < bytecount; j++) {
		crc = ((crc << 8) ^ ccitt_table[((crc >> 8) ^ (0xff & bytes[j]))]);
	}
	return crc;
}

unsigned short gs3GenCrc (u32 const *code, const int count) {
	u32 *swap = (u32*)malloc(sizeof(u32) * count);
	u8 *bytes;
	u16 crc;
	int i;

	if(!swap) return 0;

	for(i = 0; i < count; i++) {
		swap[i] = swapbytes(code[i]);
	}
	bytes = (u8 *)swap;
	crc = gs3CcittCrc(bytes, count << 2);
	free(swap);
	return crc;
}

/***************************************************************
End Version 5+ Routines.
***************************************************************/

/**
	*  Fire also implements their own bogus version of a CRC32.  I've never seen this
	*  variation before.  This is used in cheat update files and save archives.
	*  Cheat files are GS5+, but this has been in the save files for a long time.
	*
*/

#define GS3_POLY 	0x04C11DB7

u32 gs3_crc32tab[256];

void gs3GenCrc32Tab() {
	u32 crc, i, j;
	for(i = 0; i < 256; i++) {
		crc = i << 24;
		for(j = 0; j < 8; j++) {
			crc = (crc & SMASK) == 0 ? crc << 1 : (crc << 1) ^ GS3_POLY;
		}
		gs3_crc32tab[i] = crc;
	}
}

u32 gs3Crc32(u8 *data, u32 size) {
	u32 i, crc = 0;
	if(size == 0 || size == 0xFFFFFFFF) return 0;
	for(i = 0; i < size; i++) {
		crc = (crc << 8) ^ gs3_crc32tab[((crc >> 24) ^ data[i])];
	}
	return crc;
}

u32 gs3GenCrc32(u8 *data, u32 size) {
	gs3GenCrc32Tab();
	return gs3Crc32(data, size);
}

/***************************************************************
End CRC32
***************************************************************/

/***************************************************************
Encryption/Decryption Seed Table Routines.
The encryption is based on MTCrypt.
***************************************************************/

/*
Initializes the state table for the adapted Mersenne Twist.
Arguments:	seed - a seed value (either from the static table or from a code)
*/
void gs3InitMtStateTbl(u32 *mtStateTbl, u32 seed) {
	u32 wseed, ms, ls;
	u32 mask = 0xFFFF0000;
	int i;
	wseed = seed;
	for(i = 0; i < MT_STATE_SIZE; i++) {
		ms = (wseed & mask);
		wseed = wseed * MT_MULTIPLIER + 1;
		ls = wseed & mask;
		mtStateTbl[i] = (ls >> 16) | ms;
		wseed = wseed * MT_MULTIPLIER + 1;
	}
	passcount = MT_STATE_SIZE;
	return;
}
/*
The whole thing is basically an adapted Mersenne Twist algorithm.  This just shuffles around the
state table at a given point, and returns a non-random value for use in shuffling the byte
seed tables.  The byte seed tables are used in encryption/decryption.

Arguments:	none.

Returns:  Integer value.
*/
unsigned int gs3GetMtNum(u32 *mtStateTbl) {
	u32 *tbl = mtStateTbl;
	u32 tmp;
	int i, off = MT_REC_OFFSET;

	if(passcount >= MT_STATE_SIZE) {
		if(passcount == MT_STATE_SIZE + 1) { gs3InitMtStateTbl(mtStateTbl, 0x1105); }
		for(i = 0; i < MT_STATE_SIZE - 1; i++) {
			if(i == MT_BREAK_OFFSET) off = -1 * MT_BREAK_OFFSET;
			tmp = (*tbl & SMASK) | (*(tbl+1) & LMASK);
			*tbl = (tmp >> 1) ^ *(tbl+off) ^ gs3_decision_matrix[tmp & 1];
			tbl++;
		}
		tmp = (*mtStateTbl & LMASK) | ((*(mtStateTbl + MT_STATE_SIZE - 1)) & SMASK);
		tbl = mtStateTbl + MT_STATE_SIZE - 1;
		*tbl = (tmp >> 1) ^ *(mtStateTbl+MT_REC_OFFSET-1) ^ gs3_decision_matrix[tmp & 1];
		passcount = 0;
	}

	tmp = *(mtStateTbl + passcount);
	tmp ^= tmp >> 11;
	tmp ^= (tmp << 7) & MT_MASK_B;
	tmp ^= (tmp << 15) & MT_MASK_C;
	passcount++;
	return (tmp >> 18) ^ tmp;
}

/*
Builds byte seed tables.

Arguments:	tbl - pointer to the table to be built.
			seed - a halfword seed used to build the word table.
			size - size of the byte seed table being built.
*/
void gs3BuildByteSeedTbl(u8 *tbl, const u16 seed, const int size) {
	int i, idx1, idx2;
	u8 tmp;

	if(size > 0) {
		//initialize the table with a 0 to size sequence.
		for(i = 0; i < size; i++) {
			tbl[i] = i;
		}
		//Build the word seed table from seed.
		gs3InitMtStateTbl(gs3_mtStateTbl_code, seed);
		//essentially pass through the table twice, swapping based on returned word values.
		i = size << 1;
		while(i--) {
			idx1 = gs3GetMtNum(gs3_mtStateTbl_code) % size;
			idx2 = gs3GetMtNum(gs3_mtStateTbl_code) % size;
			tmp = tbl[idx1];
			tbl[idx1] = tbl[idx2];
			tbl[idx2] = tmp;
		}
	}
	else {
		//this should really never happen.
		gs3InitMtStateTbl(gs3_mtStateTbl_code, seed);
	}
	return;
}

/*
This reverses the byte seed tables for use in decryption.

Arguments:  dest - pointer to the destination crypt table.
			src - pointer to the source crypt table.
			size - size of both tables.
*/

void gs3ReverseSeeds(u8 *dest, const u8 * src, const int size) {
	int i;
	for(i = 0; i < size; i++) {
		dest[src[i]] = i;
	}
	return;
}
/*
Build the byte seed tables using the halfword values passed.  This will either be from
a code with key type = 7, or the default halfword seeds.  Only one of them will actually
be used in generating the byte tables, seed2 and 3 just build the return value.

Arguments:  seed1, seed2, seed3 - the three halfword seeds required.
Returns: a byte value (in an int) based on the seeds provided.
*/

unsigned int gs3BuildSeeds(const u16 seed1, const u16 seed2, const u16 seed3) {
	int i, shift;
	for(i = 0; i < GS3_NUM_TABLES; i++) {
		shift= 5 - i;
		shift = shift < 3 ? 0 : shift;
		gs3BuildByteSeedTbl(gs3_encrypt_seeds[i].table, seed1 >> shift, gs3_encrypt_seeds[i].size);
		gs3ReverseSeeds(gs3_decrypt_seeds[i].table,
			gs3_encrypt_seeds[i].table, gs3_decrypt_seeds[i].size);
	}
	return (((((seed1 >> 8) | 1) + seed2 - seed3) - (((seed2 >> 8) & 0xFF) >> 2))
				+ (seed1 & 0xFC) + (seed3 >> 8) + 0xFF9A) & 0xFF;
}

/*
Initialize the encryption tables using the default halfword seeds.
This should be called prior to using the encryption routines, to reset the tables' states.
*/
void gs3Init() {
	int i;
	if(!gs3_init) gs3CcittBuildSeeds();
	gs3BuildSeeds(gs3_hseeds[0], gs3_hseeds[1], gs3_hseeds[2]);
	gs3_init = 1;
	return;
}

/*
Update the encryption seeds.  For some reason, this doesn't replace the halfword seeds.
It just feeds the code [XXXX][YYYY] [ZZZZ][IGNORED] into the seed build routine.
Also for some reason, it stores the return value from BuildSeeds back in the 3rd byte of
the code address.

Arguments:  u32 seeds[2] - A pointer to a code.
Returns: 0 on success, 1 otherwise.
*/

int gs3Update(unsigned int seeds[2]) {
	unsigned short *seed = (unsigned short *)seeds;
	*seeds = (gs3BuildSeeds(seed[0], seed[1], seed[2]) << 16) | (*seeds & 0xFF00FFFF);
	return 0;
}
/***************************************************************
Encryption/Decryption Routines.
***************************************************************/

/*
Decrypt a single line.  Key indicators are built into the individual codes.
*/

u8 gs3Decrypt(u32* address, u32* value) {
	u32 command, tmp = 0, tmp2 = 0, mask = 0;
	u8 flag, *seedtbl, key;
	int size, i = 0;

	//First, check to see if this is the second line
	//  of a two-line code type.
	if(gs3_linetwo) {
		switch(gs3_xkey) {
		case 1:
		case 2: {  //key x1 - second line for key 1 and 2.
			seedtbl = gs3_decrypt_seeds[GS3_CRYPT_X1].table;
			size = gs3_decrypt_seeds[GS3_CRYPT_X1].size;
			for(i = 0; i < size; i++) {
				flag =  i < 32 ?
					((*value ^ (gs3_hseeds[1] << 13)) >> i) & 1 :
					(((*address ^ gs3_hseeds[1] << 2)) >> (i - 32)) & 1;
				if(flag > 0) {
					if(seedtbl[i] < 32) {
						tmp2 |= (1 << seedtbl[i]);
					}
					else {
						tmp |= (1 << (seedtbl[i] - 32));
					}
				}
			}
			*address = tmp ^ (gs3_hseeds[2] << 3);
			*value = tmp2 ^ gs3_hseeds[2];
			gs3_linetwo = 0;
			return 0;
		}
		case 3:
		case 4: {  //key x2 - second line for key 3 and 4.
			seedtbl = gs3_decrypt_seeds[GS3_CRYPT_X2].table;
			tmp = *address ^ (gs3_hseeds[1] << 3);
			*address = BYTES_TO_WORD(seedtbl[GETBYTE(tmp, 4)], seedtbl[GETBYTE(tmp, 3)],
					seedtbl[GETBYTE(tmp, 2)], seedtbl[GETBYTE(tmp, 1)])
					^ (gs3_hseeds[2] << 16);
			tmp = *value ^ (gs3_hseeds[1] << 9);
			*value = BYTES_TO_WORD(seedtbl[GETBYTE(tmp, 4)], seedtbl[GETBYTE(tmp, 3)],
					seedtbl[GETBYTE(tmp, 2)], seedtbl[GETBYTE(tmp, 1)])
					^ (gs3_hseeds[2] << 5);
			gs3_linetwo = 0;
			return 0;
		}
		default: {
			gs3_linetwo = 0;
			return 0;
		}
		}
	}

	//Now do normal encryptions.
	command = *address & 0xFE000000;
	key = (*address >> 25) & 0x7;
	if(command >= 0x30000000 && command <= 0x6FFFFFFF) {
		gs3_linetwo = 1;
		gs3_xkey = key;
	}

	if((command >> 28) == 7) return 0;  //do nothing on verifier lines.

	switch(key) {
		case 0: //Key 0.  Raw.
			break;
		case 1: {  //Key 1.  This key is used for codes built into GS/XP cheat discs.
					//  You typically cannot see these codes.
			seedtbl = gs3_decrypt_seeds[GS3_CRYPT_1].table;
			size = gs3_decrypt_seeds[GS3_CRYPT_1].size;
			tmp = (*address & 0x01FFFFFF) ^ (gs3_hseeds[1] << 8);
			mask = 0;
			for(i = 0; i < size; i++) {
				mask |= ((tmp & (1 << i)) >> i) << seedtbl[i];
			}
			*address = ((mask ^ gs3_hseeds[2]) | command) & DECRYPT_MASK;
			break;
		}
		case 2: {  //Key 2.  The original encryption used publicly.  Fell into disuse
					//around August, 2004.
			seedtbl = gs3_decrypt_seeds[GS3_CRYPT_2].table;
			size = gs3_decrypt_seeds[GS3_CRYPT_2].size;
			*address = (*address & 0x01FFFFFF) ^ (gs3_hseeds[1] << 1);
			tmp = tmp2 = 0;
			for(i = 0; i < size; i++) {
				flag = (i < 32) ? ((*value  ^ (gs3_hseeds[1] << 16)) >> i) & 1 :
					(*address >> (i - 32)) & 1;
				if(flag > 0) {
					if(seedtbl[i] < 32) {
						tmp2 |= (1 << seedtbl[i]);
					}
					else {
						tmp |= (1 << (seedtbl[i] - 32));
					}
				}
			}
			*address = ((tmp ^ (gs3_hseeds[2] << 8)) | command) & DECRYPT_MASK;
			*value = tmp2 ^ gs3_hseeds[2];
			break;
		}
		case 3: {  //Key 3.  Unused publicly.
			seedtbl = gs3_decrypt_seeds[GS3_CRYPT_3].table;
			tmp = *address ^ (gs3_hseeds[1] << 8);
			*address = ((BYTES_TO_HALF(seedtbl[GETBYTE(tmp, 1)], seedtbl[GETBYTE(tmp, 2)])
				| (tmp & 0xFFFF0000)) ^ (gs3_hseeds[2] << 4)) & DECRYPT_MASK;
			break;
		}
		case 4: {  //Key 4.  Second encryption used publicly.
			seedtbl = gs3_decrypt_seeds[GS3_CRYPT_4].table;
			tmp = *address ^ (gs3_hseeds[1] << 8);
			*address = ((BYTES_TO_HALF(seedtbl[GETBYTE(tmp, 2)], seedtbl[GETBYTE(tmp, 1)])
					| (tmp & 0xFFFF0000)) ^ (gs3_hseeds[2] << 4)) & DECRYPT_MASK;
			tmp = *value ^ (gs3_hseeds[1] << 9);
			*value = BYTES_TO_WORD(seedtbl[GETBYTE(tmp, 4)], seedtbl[GETBYTE(tmp, 3)],
						seedtbl[GETBYTE(tmp, 2)], seedtbl[GETBYTE(tmp, 1)])
						^ (gs3_hseeds[2] << 5);
			break;
		}
		case 5:
		case 6:	//Key 5 and Key 6 appear to be nonexistent routines.  Entering codes that use
			//  key 6 into GSv3 and XPv4 result in code entries that cannot be activated except
			//  with much effort and luck.
			break;
		case 7: { //seed refresh
			u32 code[2] = { *address, *value };
			gs3Update(code);
			break;
		}
		default:
			break;
	}
	return 0;
};
/*
Encrypt a single line.  The key indicator is passed, however an allowance
has been made for a per-code specification using bits 25-27 as in encrypted codes.
*/
u8 gs3Encrypt(u32* address, u32* value, u8 key)
{
	u32 command = *address & 0xFE000000;
	u32 tmp = 0, tmp2 = 0, mask = 0;
	u8 flag, *seedtbl;
	int size, i = 0;
	if (!(key > 0 && key < 8)) {
		key = ((*address) >> 25) & 0x7;
	}

	//First, check to see if this is the second line
	//  of a two-line code type.
	if(gs3_linetwo) {
		switch(gs3_xkey) {
		case 1:
		case 2: { //key x1 - second line for key 1 and 2.
			seedtbl	= gs3_encrypt_seeds[GS3_CRYPT_X1].table;
			size	= gs3_encrypt_seeds[GS3_CRYPT_X1].size;
			*address = *address ^ (gs3_hseeds[2] << 3);
			*value = *value ^ gs3_hseeds[2];
			for(i = 0; i < size; i++) {
				flag = (i < 32) ? (*value >> i) & 1 : (*address >> (i - 32)) & 1;
				if(flag > 0) {
					if(seedtbl[i] < 32) {
						tmp2 |= (1 << seedtbl[i]);
					}
					else {
						tmp |= (1 << (seedtbl[i] - 32));
					}
				}
			}
			*address = tmp ^ (gs3_hseeds[1] << 2);
			*value = tmp2 ^ (gs3_hseeds[1] << 13);
			gs3_linetwo = 0;
			return 0;
		}
		case 3:
		case 4: {  //key x2 - second line for key 3 and 4.
			seedtbl	= gs3_encrypt_seeds[GS3_CRYPT_X2].table;
			tmp = *address ^ (gs3_hseeds[2] << 16);
			*address = BYTES_TO_WORD(seedtbl[GETBYTE(tmp, 4)], seedtbl[GETBYTE(tmp, 3)],
					seedtbl[GETBYTE(tmp, 2)], seedtbl[GETBYTE(tmp, 1)])
					^ (gs3_hseeds[1] << 3);
			tmp = *value ^ (gs3_hseeds[2] << 5);
			*value = BYTES_TO_WORD(seedtbl[GETBYTE(tmp, 4)], seedtbl[GETBYTE(tmp, 3)],
					seedtbl[GETBYTE(tmp, 2)], seedtbl[GETBYTE(tmp, 1)])
					^ (gs3_hseeds[1] << 9);
			gs3_linetwo = 0;
			return 0;
		}
		default: {
			gs3_linetwo = 0;
			return 0;
		}
		}
	}

	if(command >= 0x30000000 && command <= 0x6FFFFFFF) {
		gs3_linetwo = 1;
		gs3_xkey = key;
	}

	switch(key) {
		case 0: //Raw
			break;
		case 1: {//Key 1.  This key is used for codes built into GS/XP cheat discs.
					//  You typically cannot see these codes.
			seedtbl	= gs3_encrypt_seeds[GS3_CRYPT_1].table;
			size = gs3_encrypt_seeds[GS3_CRYPT_1].size;
			tmp = (*address & 0x01FFFFFF) ^ gs3_hseeds[2];
			mask = 0;
			for(i = 0; i < size; i++) {
				mask |= ((tmp & (1 << i)) >> i) << seedtbl[i];
			}
			*address =  ((mask  ^ (gs3_hseeds[1] << 8)))  | command;
			break;
		}

		case 2: {  //Key 2.  The original encryption used publicly.  Fell into disuse
			seedtbl	= gs3_encrypt_seeds[GS3_CRYPT_2].table;
			size	= gs3_encrypt_seeds[GS3_CRYPT_2].size;
			*address = (*address ^ (gs3_hseeds[2] << 8)) & 0x01FFFFFF;
			*value ^= gs3_hseeds[2];
			tmp = tmp2 = 0;
			for(i = 0; i < 0x39; i++) {
				flag = (i < 32) ? (*value >> i) & 1 : (*address >> (i - 32)) & 1;
				if(flag > 0) {
					if(seedtbl[i] < 32) {
						tmp2 |= (1 << seedtbl[i]);
					}
					else {
						tmp |= (1 << (seedtbl[i] - 32));
					}
				}
			}
			*address = (tmp ^ (gs3_hseeds[1] << 1)) | command;
			*value = tmp2 ^ (gs3_hseeds[1] << 16);
			break;
		}
		case 3: {  //Key 3.  Unused publicly.
			seedtbl	= gs3_encrypt_seeds[GS3_CRYPT_3].table;
			tmp = (*address & 0xF1FFFFFF) ^ (gs3_hseeds[2] << 4);
			*address = ((BYTES_TO_HALF(seedtbl[GETBYTE(tmp, 1)], seedtbl[GETBYTE(tmp, 2)])
					| (tmp & 0xFFFF0000)) ^ (gs3_hseeds[1] << 8));
			break;
		}
		case 4: {  //Key 4.  Second encryption used publicly.
			seedtbl	= gs3_encrypt_seeds[GS3_CRYPT_4].table;
			tmp = (*address & 0xF1FFFFFF) ^ (gs3_hseeds[2] << 4);
			*address = ((BYTES_TO_HALF(seedtbl[GETBYTE(tmp, 2)], seedtbl[GETBYTE(tmp, 1)])
					| (tmp & 0xFFFF0000)) ^ (gs3_hseeds[1] << 8));
			tmp = *value ^ (gs3_hseeds[2] << 5);
			*value = BYTES_TO_WORD(seedtbl[GETBYTE(tmp, 4)], seedtbl[GETBYTE(tmp, 3)],
						seedtbl[GETBYTE(tmp, 2)], seedtbl[GETBYTE(tmp, 1)]) ^ (gs3_hseeds[1] << 9);
			break;
		}
		case 5:
		case 6:
			break;
		case 7: {//seed refresh.
			u32 code[2] = { *address, *value };
			gs3Update(code);
			break;
		}
		default:
			break;
	}
	//add key to the code
	*address |= (key << 25);
	return 0;
}

/*
Decrypt a batch of codes (lines).
*/
void gs3BatchDecrypt(cheat_t *cheat) {
	int i, j;
	for(i = 0; i < cheat->codecnt;) {
		if((cheat->code[i] >> 28) == 7 && !gs3_linetwo) {  //if the code starts with 7, it's a verifier, unless it's line two of two-line code type.
			cheatRemoveOctets(cheat, i+1, 2);
		} else {
			gs3Decrypt(&cheat->code[i], &cheat->code[i+1]);
			i+=2;
		}
	}
}

/*
Encrypt a batch of codes (lines).
*/
void gs3BatchEncrypt(cheat_t *cheat, u8 key) {
	int i;
	for(i = 0; i < cheat->codecnt; i+=2) {
		gs3Encrypt(&cheat->code[i], &cheat->code[i+1], key);
	}
	return;
}

/*
Create a verifier for version 5 codes if necessary.
*/
void gs3CreateVerifier(u32 *address, u32 *value, u32 *codes, int size) {
	u16 crc = gs3GenCrc(codes, size);
	*value = 0;
	*address = 0x76000000 | crc << 4;
	return;
}

void gs3AddVerifier(cheat_t *cheat) {
	int i;
	u32 addr, val;
	gs3CreateVerifier(&addr, &val, cheat->code, cheat->codecnt);
	cheatPrependOctet(cheat, val);
	cheatPrependOctet(cheat, addr);
	return;
}

void gs3CryptFileData(u8 *data, u32 size) {
	u32 i;
	gs3InitMtStateTbl(gs3_mtStateTbl_p2m, size);
	for(i = 0; i < size; i++) {
		data[i] ^= gs3GetMtNum(gs3_mtStateTbl_p2m);
	}
}

@end
