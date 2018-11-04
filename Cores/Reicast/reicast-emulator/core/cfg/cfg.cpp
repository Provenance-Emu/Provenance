/*
	Config file crap
	Supports various things, as virtual config entries and such crap
	Works surprisingly well considering how old it is ...
*/

#define _CRT_SECURE_NO_DEPRECATE (1)
#include <errno.h>
#include "cfg.h"
#include "ini.h"

string cfgPath;
bool save_config = true;

ConfigFile cfgdb;

void savecfgf()
{
	FILE* cfgfile = fopen(cfgPath.c_str(),"wt");
	if (!cfgfile)
	{
		printf("Error : Unable to open file for saving \n");
	}
	else
	{
		cfgdb.save(cfgfile);
		fclose(cfgfile);
	}
}
void  cfgSaveStr(const wchar * Section, const wchar * Key, const wchar * String)
{
	cfgdb.set(string(Section), string(Key), string(String));
	if(save_config)
	{
		savecfgf();
	}
	//WritePrivateProfileString(Section,Key,String,cfgPath);
}
//New config code

/*
	I want config to be really flexible .. so , here is the new implementation :

	Functions :
	cfgLoadInt  : Load an int , if it does not exist save the default value to it and return it
	cfgSaveInt  : Save an int
	cfgLoadStr  : Load a str , if it does not exist save the default value to it and return it
	cfgSaveStr  : Save a str
	cfgExists   : Returns true if the Section:Key exists. If Key is null , it retuns true if Section exists

	Config parameters can be read from the config file , and can be given at the command line
	-cfg section:key=value -> defines a value at command line
	If a cfgSave* is made on a value defined by command line , then the command line value is replaced by it

	cfg values set by command line are not written to the cfg file , unless a cfgSave* is used

	There are some special values , all of em are on the emu namespace :)

	These are readonly :

	emu:AppPath		: Returns the path where the emulator is stored
	emu:PluginPath	: Returns the path where the plugins are loaded from
	emu:DataPath	: Returns the path where the bios/data files are

	emu:FullName	: str,returns the emulator's name + version string (ex."nullDC v1.0.0 Private Beta 2 built on {datetime}")
	emu:ShortName	: str,returns the emulator's name + version string , short form (ex."nullDC 1.0.0pb2")
	emu:Name		: str,returns the emulator's name (ex."nullDC")

	These are read/write
	emu:Caption		: str , get/set the window caption
*/

///////////////////////////////
/*
**	This will verify there is a working file @ ./szIniFn
**	- if not present, it will write defaults
*/

bool cfgOpen()
{
	const char* filename = "/emu.cfg";
	string config_path_read = get_readonly_config_path(filename);
	cfgPath = get_writable_config_path(filename);

	FILE* cfgfile = fopen(config_path_read.c_str(),"r");
	if(cfgfile != NULL) {
		cfgdb.parse(cfgfile);
		fclose(cfgfile);
	}
	else
	{
		// Config file can't be opened
		int error_code = errno;
		printf("Warning: Unable to open the config file '%s' for reading (%s)\n", config_path_read.c_str(), strerror(error_code));
		if (error_code == ENOENT || cfgPath != config_path_read)
		{
			// Config file didn't exist
			printf("Creating new empty config file at '%s'\n", cfgPath.c_str());
			savecfgf();
		}
		else
		{
			// There was some other error (may be a permissions problem or something like that)
			save_config = false;
		}
	}

	return true;
}

//Implementations of the interface :)
//Section must be set
//If key is 0 , it looks for the section
//0 : not found
//1 : found section , key was 0
//2 : found section & key
s32  cfgExists(const wchar * Section, const wchar * Key)
{
	if(cfgdb.has_entry(string(Section), string(Key)))
	{
		return 2;
	}
	else
	{
		return (cfgdb.has_section(string(Section)) ? 1 : 0);
	}
}
void  cfgLoadStr(const wchar * Section, const wchar * Key, wchar * Return,const wchar* Default)
{
	string value = cfgdb.get(Section, Key, Default);
	// FIXME: Buffer overflow possible
	strcpy(Return, value.c_str());
}

string  cfgLoadStr(const wchar * Section, const wchar * Key, const wchar* Default)
{
	if(!cfgdb.has_entry(string(Section), string(Key)))
	{
		cfgSaveStr(Section, Key, Default);
	}
	return cfgdb.get(string(Section), string(Key), string(Default));
}

//These are helpers , mainly :)
void  cfgSaveInt(const wchar * Section, const wchar * Key, s32 Int)
{
	cfgdb.set_int(string(Section), string(Key), Int);
	if(save_config)
	{
		savecfgf();
	}
}

s32  cfgLoadInt(const wchar * Section, const wchar * Key,s32 Default)
{
	if(!cfgdb.has_entry(string(Section), string(Key)))
	{
		cfgSaveInt(Section, Key, Default);
	}
	return cfgdb.get_int(string(Section), string(Key), Default);
}

s32  cfgGameInt(const wchar * Section, const wchar * Key,s32 Default)
{
    if(cfgdb.has_entry(string(Section), string(Key)))
    {
        return cfgdb.get_int(string(Section), string(Key), Default);
    }
    return Default;
}

void  cfgSaveBool(const wchar * Section, const wchar * Key, bool BoolValue)
{
	cfgdb.set_bool(string(Section), string(Key), BoolValue);
	if(save_config)
	{
		savecfgf();
	}
}

bool  cfgLoadBool(const wchar * Section, const wchar * Key,bool Default)
{
	if(!cfgdb.has_entry(string(Section), string(Key)))
	{
		cfgSaveBool(Section, Key, Default);
	}
	return cfgdb.get_bool(string(Section), string(Key), Default);
}

void cfgSetVirtual(const wchar * Section, const wchar * Key, const wchar * String)
{
	cfgdb.set(string(Section), string(Key), string(String), true);
}
