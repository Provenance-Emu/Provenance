#include "common.h"
#include <ctype.h>
#include <sstream>
#include <algorithm>

// given file/name.ext or file\name.ext returns file/ or file\, depending on the platform
// given name.ext returns ./ or .\, depending on the platform
string OS_dirname(string file)
{
	#if HOST_OS == OS_WINDOWS
		const char sep = '\\';
	#else
		const char sep = '/';
	#endif

	size_t last_slash = file.find_last_of(sep);

	if (last_slash == string::npos)
	{
		string local_dir = ".";
		local_dir += sep;
		return local_dir;
	}

	return file.substr(0, last_slash + 1);
}

// On windows, transform / to \\
// On linux, transform \\ to /
string normalize_path_separator(string path)
{
	#if HOST_OS == OS_WINDOWS
		std::replace( path.begin(), path.end(), '/', '\\');
	#else
		std::replace( path.begin(), path.end(), '\\', '/');
	#endif

	return path;
}

#if 0 // TODO: Move this to some tests, make it platform agnostic
namespace {
	struct OS_dirname_Test {
		OS_dirname_Test() {
			verify(OS_dirname("local/path") == "local/");
			verify(OS_dirname("local/path/two") == "local/path/");
			verify(OS_dirname("local/path/three\\a.exe") == "local/path/");
			verify(OS_dirname("local.ext") == "./");
		}
	} test1;

	struct normalize_path_separator_Test {
		normalize_path_separator_Test() {
			verify(normalize_path_separator("local/path") == "local/path");
			verify(normalize_path_separator("local\\path") == "local/path");
			verify(normalize_path_separator("local\\path\\") == "local/path/");
			verify(normalize_path_separator("\\local\\path\\") == "/local/path/");
			verify(normalize_path_separator("loc\\al\\pa\\th") == "loc/al/pa/th");
		}
	} test2;
}
#endif

Disc* load_gdi(const char* file)
{
	u32 iso_tc;
	Disc* disc = new Disc();
	
	//memset(&gdi_toc,0xFFFFFFFF,sizeof(gdi_toc));
	//memset(&gdi_ses,0xFFFFFFFF,sizeof(gdi_ses));
	core_file* t=core_fopen(file);
	if (!t)
		return 0;

	size_t gdi_len = core_fsize(t);

	char gdi_data[8193] = { 0 };

	if (gdi_len >= sizeof(gdi_data))
	{
		core_fclose(t);
		return 0;
	}

	core_fread(t, gdi_data, gdi_len);
	core_fclose(t);

	istringstream gdi(gdi_data);

	gdi >> iso_tc;
	printf("\nGDI : %d tracks\n",iso_tc);

	
	string basepath = OS_dirname(file);

	u32 TRACK=0,FADS=0,CTRL=0,SSIZE=0;
	s32 OFFSET=0;
	for (u32 i=0;i<iso_tc;i++)
	{
		string track_filename;

		//TRACK FADS CTRL SSIZE file OFFSET
		gdi >> TRACK;
		gdi >> FADS;
		gdi >> CTRL;
		gdi >> SSIZE;

		char last;

		do {
			gdi >> last;
		} while (isspace(last));
		
		if (last == '"')
		{
			gdi >> std::noskipws;
			for(;;) {
				gdi >> last;
				if (last == '"')
					break;
				track_filename += last;
			}
			gdi >> std::skipws;
		}
		else
		{
			gdi >> track_filename;
			track_filename = last + track_filename;
		}

		gdi >> OFFSET;
		
		printf("file[%d] \"%s\": FAD:%d, CTRL:%d, SSIZE:%d, OFFSET:%d\n", TRACK, track_filename.c_str(), FADS, CTRL, SSIZE, OFFSET);

		Track t;
		t.ADDR=0;
		t.StartFAD=FADS+150;
		t.EndFAD=0;		//fill it in
		t.file=0;

		if (SSIZE!=0)
		{
			string path = basepath + normalize_path_separator(track_filename);
			t.file = new RawTrackFile(core_fopen(path.c_str()),OFFSET,t.StartFAD,SSIZE);	
		}
		disc->tracks.push_back(t);
	}

	disc->FillGDSession();

	return disc;
}


Disc* gdi_parse(const char* file)
{
	size_t len=strlen(file);
	if (len>4)
	{
		if (stricmp( &file[len-4],".gdi")==0)
		{
			return load_gdi(file);
		}
	}
	return 0;
}

void iso_term()
{
}
