#include "version.h"
#include "types.h"
#include "fceu.h"
#include "driver.h"
#include "netplay.h"

#include "oldmovie.h"
#include "movie.h"
#include "utils/xstring.h"

#include <fstream>

using namespace std;

// FCM\x1a
#define MOVIE_MAGIC             0x1a4d4346

// still at 2 since the format itself is still compatible
// to detect which version the movie was made with, check the fceu version stored in the movie header
// (e.g against FCEU_VERSION_NUMERIC)
#define MOVIE_VERSION           2

//-------
//this is just supposed to be a comment describing the disk format
//---
//struct MovieHeader
//{
//uint32 magic;						// +0
//uint32 version=2;					// +4
//uint8 flags[4];					// +8
//uint32 length_frames;				// +12
//uint32 rerecord_count;				// +16
//uint32 movie_data_size;			// +20
//uint32 offset_to_savestate;		// +24, should be 4-byte-aligned
//uint32 offset_to_movie_data;		// +28, should be 4-byte-aligned
//uint8 md5_of_rom_used[16];			// +32
//uint32 version_of_emu_used			// +48
//char name_of_rom_used[]			// +52, utf-8, null-terminated
//char metadata[];					//      utf-8, null-terminated
//uint8 padding[];
//uint8 savestate[];					//      always present, even in a "from reset" recording
//uint8 padding[];					//      used for byte-alignment
//uint8 movie_data[];
//};
//-------

static uint8 joop[4];
static uint8 joopcmd;
static uint32 framets = 0;
static uint32 frameptr = 0;
static uint8* moviedata = NULL;
static uint32 moviedatasize = 0;
static uint32 firstframeoffset = 0;
static uint32 savestate_offset = 0;

//Cache variables used for playback.
static uint32 nextts = 0;
static int32 nextd = 0;

 // turn old ucs2 metadata into utf8
void convert_metadata(char* metadata, int metadata_size, uint8* tmp, int metadata_length)
{
	 char* ptr=metadata;
	 char* ptr_end=metadata+metadata_size-1;
	 int c_ptr=0;
	 while(ptr<ptr_end && c_ptr<metadata_length)
	 {
		 uint16 c=(tmp[c_ptr<<1] | (tmp[(c_ptr<<1)+1] << 8));
		 //mbg merge 7/17/06 changed to if..elseif
		 if(c<=0x7f)
			 *ptr++ = (char)(c&0x7f);
		 else if(c<=0x7FF)
			 if(ptr+1>=ptr_end)
				 ptr_end=ptr;
			 else
			 {
				 *ptr++=(0xc0 | (c>>6));
				 *ptr++=(0x80 | (c & 0x3f));
			 }
		 else
			 if(ptr+2>=ptr_end)
				 ptr_end=ptr;
			 else
			 {
				 *ptr++=(0xe0 | (c>>12));
				 *ptr++=(0x80 | ((c>>6) & 0x3f));
				 *ptr++=(0x80 | (c & 0x3f));
			 }

		 c_ptr++;
	 }
	 *ptr='\0';
}

//backwards compat
static void FCEUI_LoadMovie_v1(char *fname, int _read_only);
//static int FCEUI_MovieGetInfo_v1(const char* fname, MOVIE_INFO* info);

//int _old_FCEUI_MovieGetInfo(const char* fname, MOVIE_INFO* info)
//{
//	//mbg: wtf?
//	//MovieFlushHeader();
//
//	// main get info part of function
//	{
//		uint32 magic;
//		uint32 version;
//		uint8 _flags[4];
//
//		FILE* fp = FCEUD_UTF8fopen(fname, "rb");
//		if(!fp)
//			return 0;
//
//		read32le(&magic, fp);
//		if(magic != MOVIE_MAGIC)
//		{
//			fclose(fp);
//			return 0;
//		}
//
//		read32le(&version, fp);
//		if(version != MOVIE_VERSION)
//		{
//			fclose(fp);
//			if(version == 1)
//				return FCEUI_MovieGetInfo_v1(fname, info);
//			else
//				return 0;
//		}
//
//		info->movie_version = MOVIE_VERSION;
//
//		fread(_flags, 1, 4, fp);
//
//		info->flags = _flags[0];
//		read32le(&info->num_frames, fp);
//		read32le(&info->rerecord_count, fp);
//
//		if(access(fname, W_OK))
//			info->read_only = 1;
//		else
//			info->read_only = 0;
//
//		fseek(fp, 12, SEEK_CUR);			// skip movie_data_size, offset_to_savestate, and offset_to_movie_data
//
//		fread(&info->md5_of_rom_used, 1, 16, fp);
//		info->md5_of_rom_used_present = 1;
//
//		read32le(&info->emu_version_used, fp);
//
//		// I probably could have planned this better...
//		{
//			char str[256];
//			size_t r;
//			uint32 p; //mbg merge 7/17/06 change to uint32
//			int p2=0;
//			char last_c=32;
//
//			if(info->name_of_rom_used && info->name_of_rom_used_size)
//				info->name_of_rom_used[0]='\0';
//
//			r=fread(str, 1, 256, fp);
//			while(r > 0)
//			{
//				for(p=0; p<r && last_c != '\0'; ++p)
//				{
//					if(info->name_of_rom_used && info->name_of_rom_used_size && (p2 < info->name_of_rom_used_size-1))
//					{
//						info->name_of_rom_used[p2]=str[p];
//						p2++;
//						last_c=str[p];
//					}
//				}
//				if(p<r)
//				{
//					memmove(str, str+p, r-p);
//					r -= p;
//					break;
//				}
//				r=fread(str, 1, 256, fp);
//			}
//
//			p2=0;
//			last_c=32;
//
//			if(info->metadata && info->metadata_size)
//				info->metadata[0]='\0';
//
//			while(r > 0)
//			{
//				for(p=0; p<r && last_c != '\0'; ++p)
//				{
//					if(info->metadata && info->metadata_size && (p2 < info->metadata_size-1))
//					{
//						info->metadata[p2]=str[p];
//						p2++;
//						last_c=str[p];
//					}
//				}
//				if(p != r)
//					break;
//				r=fread(str, 1, 256, fp);
//			}
//
//			if(r<=0)
//			{
//				// somehow failed to read romname and metadata
//				fclose(fp);
//				return 0;
//			}
//		}
//
//		// check what hacks are necessary
//		fseek(fp, 24, SEEK_SET);			// offset_to_savestate offset
//		uint32 temp_savestate_offset;
//		read32le(&temp_savestate_offset, fp);
//		if(temp_savestate_offset != 0xFFFFFFFF)
//		{
//			if(fseek(fp, temp_savestate_offset, SEEK_SET))
//			{
//				fclose(fp);
//				return 0;
//			}
//
//			//don't really load, just load to find what's there then load backup
//			if(!FCEUSS_LoadFP(fp,SSLOADPARAM_DUMMY)) return 0;
//		}
//
//		fclose(fp);
//		return 1;
//	}
//}
/*
Backwards compat
*/


/*
struct MovieHeader_v1
{
uint32 magic;
uint32 version=1;
uint8 flags[4];
uint32 length_frames;
uint32 rerecord_count;
uint32 movie_data_size;
uint32 offset_to_savestate;
uint32 offset_to_movie_data;
uint16 metadata_ucs2[];     // ucs-2, ick!  sizeof(metadata) = offset_to_savestate - MOVIE_HEADER_SIZE
}
*/

#define MOVIE_V1_HEADER_SIZE	32

//static void FCEUI_LoadMovie_v1(char *fname, int _read_only)
//{
//	FILE *fp;
//	char *fn = NULL;
//
//	FCEUI_StopMovie();
//
//	if(!fname)
//		fname = fn = FCEU_MakeFName(FCEUMKF_MOVIE,0,0);
//
//	// check movie_readonly
//	movie_readonly = _read_only;
//	if(access(fname, W_OK))
//		movie_readonly = 2;
//
//	fp = FCEUD_UTF8fopen(fname, (movie_readonly>=2) ? "rb" : "r+b");
//
//	if(fn)
//	{
//		free(fn);
//		fname = NULL;
//	}
//
//	if(!fp) return;
//
//	// read header
//	{
//		uint32 magic;
//		uint32 version;
//		uint8 flags[4];
//		uint32 fc;
//
//		read32le(&magic, fp);
//		if(magic != MOVIE_MAGIC)
//		{
//			fclose(fp);
//			return;
//		}
//
//		read32le(&version, fp);
//		if(version != 1)
//		{
//			fclose(fp);
//			return;
//		}
//
//		fread(flags, 1, 4, fp);
//		read32le(&fc, fp);
//		read32le(&rerecord_count, fp);
//		read32le(&moviedatasize, fp);
//		read32le(&savestate_offset, fp);
//		read32le(&firstframeoffset, fp);
//		if(fseek(fp, savestate_offset, SEEK_SET))
//		{
//			fclose(fp);
//			return;
//		}
//
//		if(flags[0] & MOVIE_FLAG_NOSYNCHACK)
//			movieSyncHackOn=0;
//		else
//			movieSyncHackOn=1;
//	}
//
//	// fully reload the game to reinitialize everything before playing any movie
//	// to try fixing nondeterministic playback of some games
//	{
//		extern char lastLoadedGameName [2048];
//		extern int disableBatteryLoading, suppressAddPowerCommand;
//		suppressAddPowerCommand=1;
//		suppressMovieStop=true;
//		{
//			FCEUGI * gi = FCEUI_LoadGame(lastLoadedGameName, 0);
//			if(!gi)
//				PowerNES();
//		}
//		suppressMovieStop=false;
//		suppressAddPowerCommand=0;
//	}
//
//	if(!FCEUSS_LoadFP(fp,SSLOADPARAM_BACKUP)) return;
//
//	ResetInputTypes();
//
//	fseek(fp, firstframeoffset, SEEK_SET);
//	moviedata = (uint8*)realloc(moviedata, moviedatasize);
//	fread(moviedata, 1, moviedatasize, fp);
//
//	framecount = 0;		// movies start at frame 0!
//	frameptr = 0;
//	current = 0;
//	slots = fp;
//
//	memset(joop,0,sizeof(joop));
//	current = -1 - current;
//	framets=0;
//	nextts=0;
//	nextd = -1;
//	FCEU_DispMessage("Movie playback started.",0);
//}
//
//static int FCEUI_MovieGetInfo_v1(const char* fname, MOVIE_INFO* info)
//{
//	uint32 magic;
//	uint32 version;
//	uint8 _flags[4];
//	uint32 savestateoffset;
//	uint8 tmp[MOVIE_MAX_METADATA<<1];
//	int metadata_length;
//
//	FILE* fp = FCEUD_UTF8fopen(fname, "rb");
//	if(!fp)
//		return 0;
//
//	read32le(&magic, fp);
//	if(magic != MOVIE_MAGIC)
//	{
//		fclose(fp);
//		return 0;
//	}
//
//	read32le(&version, fp);
//	if(version != 1)
//	{
//		fclose(fp);
//		return 0;
//	}
//
//	info->movie_version = 1;
//	info->emu_version_used = 0;			// unknown
//
//	fread(_flags, 1, 4, fp);
//
//	info->flags = _flags[0];
//	read32le(&info->num_frames, fp);
//	read32le(&info->rerecord_count, fp);
//
//	if(access(fname, W_OK))
//		info->read_only = 1;
//	else
//		info->read_only = 0;
//
//	fseek(fp, 4, SEEK_CUR);
//	read32le(&savestateoffset, fp);
//
//	metadata_length = (int)savestateoffset - MOVIE_V1_HEADER_SIZE;
//	if(metadata_length > 0)
//	{
//		//int i; //mbg merge 7/17/06 removed
//
//		metadata_length >>= 1;
//		if(metadata_length >= MOVIE_MAX_METADATA)
//			metadata_length = MOVIE_MAX_METADATA-1;
//
//		fseek(fp, MOVIE_V1_HEADER_SIZE, SEEK_SET);
//		fread(tmp, 1, metadata_length<<1, fp);
//	}
//
//	// turn old ucs2 metadata into utf8
//	if(info->metadata && info->metadata_size)
//	{
//		char* ptr=info->metadata;
//		char* ptr_end=info->metadata+info->metadata_size-1;
//		int c_ptr=0;
//		while(ptr<ptr_end && c_ptr<metadata_length)
//		{
//			uint16 c=(tmp[c_ptr<<1] | (tmp[(c_ptr<<1)+1] << 8));
//			//mbg merge 7/17/06 changed to if..elseif
//			if(c<=0x7f)
//				*ptr++ = (char)(c&0x7f);
//			else if(c<=0x7FF)
//				if(ptr+1>=ptr_end)
//					ptr_end=ptr;
//				else
//			 {
//				 *ptr++=(0xc0 | (c>>6));
//				 *ptr++=(0x80 | (c & 0x3f));
//			 }
//			else
//				if(ptr+2>=ptr_end)
//					ptr_end=ptr;
//				else
//			 {
//				 *ptr++=(0xe0 | (c>>12));
//				 *ptr++=(0x80 | ((c>>6) & 0x3f));
//				 *ptr++=(0x80 | (c & 0x3f));
//			 }
//
//				c_ptr++;
//		}
//		*ptr='\0';
//	}
//
//	// md5 info not available from v1
//	info->md5_of_rom_used_present = 0;
//	// rom name used for the movie not available from v1
//	if(info->name_of_rom_used && info->name_of_rom_used_size)
//		info->name_of_rom_used[0] = '\0';
//
//	// check what hacks are necessary
//	fseek(fp, 24, SEEK_SET);			// offset_to_savestate offset
//	uint32 temp_savestate_offset;
//	read32le(&temp_savestate_offset, fp);
//	if(fseek(fp, temp_savestate_offset, SEEK_SET))
//	{
//		fclose(fp);
//		return 0;
//	}
//	if(!FCEUSS_LoadFP(fp,SSLOADPARAM_DUMMY)) return 0; // 2 -> don't really load, just load to find what's there then load backup
//
//
//	fclose(fp);
//	return 1;
//}

static int movie_readchar()
{
	if(frameptr >= moviedatasize)
	{
		return -1;
	}
	return (int)(moviedata[frameptr++]);
}


static void _addjoy()
{
	while(nextts == framets || nextd == -1)
	{
		int tmp,ti;
		uint8 d;

		if(nextd != -1)
		{
			if(nextd&0x80)
			{
				//FCEU_DoSimpleCommand(nextd&0x1F);
				int command = nextd&0x1F;
				if(command == FCEUNPCMD_RESET)
					joopcmd = MOVIECMD_RESET;
				if(command == FCEUNPCMD_POWER)
					joopcmd = MOVIECMD_POWER;
			}
			else
				joop[(nextd >> 3)&0x3] ^= 1 << (nextd&0x7);
		}


		tmp = movie_readchar();
		d = tmp;

		if(tmp < 0)
		{
			return;
		}

		nextts = 0;
		tmp >>= 5;
		tmp &= 0x3;
		ti=0;

		int tmpfix = tmp;
		while(tmp--) { nextts |= movie_readchar() << (ti * 8); ti++; }

		// This fixes a bug in movies recorded before version 0.98.11
		// It's probably not necessary, but it may keep away CRAZY PEOPLE who recorded
		// movies on <= 0.98.10 and don't work on playback.
		if(tmpfix == 1 && !nextts)
		{nextts |= movie_readchar()<<8; }
		else if(tmpfix == 2 && !nextts) {nextts |= movie_readchar()<<16; }

		if(nextd != -1)
			framets = 0;
		nextd = d;
	}

	framets++;
}


EFCM_CONVERTRESULT convert_fcm(MovieData& md, std::string fname)
{
	//convert EVEN OLDER movies to fcm
	//fname = (char*)convertToFCM(fname,buffer);

	uint32 framecount;
	uint32 rerecord_count;
	int movieConvertOffset1=0, movieConvertOffset2=0,movieSyncHackOn=0;


	EMUFILE* fp = FCEUD_UTF8_fstream(fname, "rb");
	if(!fp) return FCM_CONVERTRESULT_FAILOPEN;

	// read header
	uint32 magic = 0;
	uint32 version;
	uint8 flags[4];

	read32le(&magic, fp);
	if(magic != MOVIE_MAGIC)
	{
		delete fp;
		return FCM_CONVERTRESULT_FAILOPEN;
	}

	read32le(&version, fp);
	if(version == 1)
	{
		// attempt to load previous version's format
		//TODO
		delete fp;
		//FCEUI_LoadMovie_v1(fname, _read_only);
		return FCM_CONVERTRESULT_OLDVERSION;
	}
	else if(version == MOVIE_VERSION)
	{}
	else
	{
		// unsupported version
		delete fp;
		return FCM_CONVERTRESULT_UNSUPPORTEDVERSION;
	}


	fp->fread((char*)&flags,4);
	read32le(&framecount, fp);
	read32le(&rerecord_count, fp);
	read32le(&moviedatasize, fp);
	read32le(&savestate_offset, fp);
	read32le(&firstframeoffset, fp);

	//read header values
	fp->fread((char*)&md.romChecksum,16);
	read32le((uint32*)&md.emuVersion,fp);

	md.romFilename = readNullTerminatedAscii(fp);

	md.comments.push_back(L"author  " + mbstowcs(readNullTerminatedAscii(fp)));

		//int metadata_length = savestate_offset - MOVIE_V1_HEADER_SIZE;
	//uint8* metadata = new uint8[metadata_length];
	//char* wcmetadata = new char[metadata_length*4]; //seems to me like we support the worst case
	//fp->read((char*)metadata,metadata_length);
	//convert_metadata(wcmetadata,metadata_length*4,metadata,metadata_length);
	//md.comments.push_back(L"author " + (std::wstring)(wchar_t*)wcmetadata);

	//  FCEU_PrintError("flags[0] & MOVIE_FLAG_NOSYNCHACK=%d",flags[0] & MOVIE_FLAG_NOSYNCHACK);
	if(flags[0] & MOVIE_FLAG_NOSYNCHACK)
		movieSyncHackOn=0;
	else
		movieSyncHackOn=1;

	if(flags[0] & MOVIE_FLAG_PAL)
		md.palFlag = true;

	bool initreset = false;
	if(flags[0] & MOVIE_FLAG_FROM_POWERON)
	{
		//don't need to load a savestate
	}
	else if(flags[0] & MOVIE_FLAG_FROM_RESET)
	{
		initreset = true;
	}
	else
	{
		delete fp;
		return FCM_CONVERTRESULT_STARTFROMSAVESTATENOTSUPPORTED;
	}

	//analyze input types?
	//ResetInputTypes();

	fp->fseek(firstframeoffset,SEEK_SET);
	moviedata = (uint8*)realloc(moviedata, moviedatasize);
	fp->fread((char*)moviedata,moviedatasize);

	frameptr = 0;
	memset(joop,0,sizeof(joop));
	framets=0;
	nextts=0;
	nextd = -1;

	//prepare output structure
	md.rerecordCount = rerecord_count;
	md.records.resize(framecount);
	md.guid.newGuid();

	//begin decoding.
	//joymask is used to look for any joystick that has input.
	//if joysticks 3 or 4 have input then we will enable fourscore
	uint8 joymask[4] = {0,0,0,0};
	for(uint32 i=0;i<framecount;i++)
	{
		joopcmd = 0;
		if(i==0 && initreset)
			joopcmd = MOVIECMD_RESET;
		_addjoy();
		md.records[i].commands = joopcmd;
		for(int j=0;j<4;j++) {
			joymask[j] |= joop[j];
			md.records[i].joysticks[j] = joop[j];
		}
	}

	md.ports[2] = SIS_NONE;
	if(joymask[2] || joymask[3])
	{
		md.fourscore = true;
		md.ports[0] = md.ports[1] = SI_NONE;
	}
	else
	{
		md.fourscore = false;
		md.ports[0] = md.ports[1] = SI_GAMEPAD;
	}

	free(moviedata);
	moviedata = 0;

	delete fp;
	return FCM_CONVERTRESULT_SUCCESS;
}
