/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *fs
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

/****************************************************************/
/*			FCE Ultra				*/
/*								*/
/*	This file contains routines for reading/writing the     */
/*	configuration file.					*/
/*								*/
/****************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../types.h"
#include "../../driver.h"
#include "../../utils/xstring.h"
#include "config.h"

static int FReadString(FILE *fp, char *str, int n)
{
 int x=0,z;
 for(;;)
 {
  z=fgetc(fp);
  str[x]=z;
  x++;  
  if(z<=0) break;
  if(x>=n) return 0;
 }
 if(z<0) return 0;
 return 1;
}

#include <map>
#include <string>
typedef std::map<std::string,std::string> CFGMAP;
static CFGMAP cfgmap;

static void cfg_Parse(FILE *fp)
{
	//yes... it is a homebrewed key-value-pair parser
	std::string key,value;
	enum {
		NEWLINE, KEY, SEPARATOR, VALUE, COMMENT
	} state = NEWLINE;
	bool bail = false;
	for(;;)
	{
		int c = fgetc(fp);
		bool iswhitespace, iscommentchar, isnewline;
		if(c == -1)
			goto bail;
		iswhitespace = (c==' '||c=='\t');
		iscommentchar = (c=='#');
		isnewline = (c==10||c==13);
		switch(state)
		{
		case NEWLINE:
			if(iswhitespace) goto done;
			if(iscommentchar) goto docomment;
			if(isnewline) goto done;
			key = "";
			value = "";
			goto dokey; 
			break;
		case COMMENT:
			docomment:
			state = COMMENT;
			if(isnewline) state = NEWLINE;
			break;
		case KEY:
			dokey: //dookie
			state = KEY;
			if(iswhitespace) goto doseparator;
			if(isnewline) goto commit;
			key += c;
			break;
		case SEPARATOR:
			doseparator:
			state = SEPARATOR;
			if(isnewline) goto commit;
			if(!iswhitespace) goto dovalue;
			break;
		case VALUE:
			dovalue:
			state = VALUE;
			if(isnewline) goto commit;
			value += c;
		}
		goto done;

		bail:
		bail = true;
		if(state == VALUE) goto commit;
		commit:
		cfgmap[key] = value;
		state = NEWLINE;
		if(bail) break;
		done: ;
	}
}

static void cfg_Save(FILE *fp)
{
	for(CFGMAP::iterator it(cfgmap.begin()); it != cfgmap.end(); it++)
	{
		if(it->first.size()>30 || it->second.size()>30)
		{
			int zzz=9;
		}
		fprintf(fp,"%s %s\n",it->first.c_str(),it->second.c_str());
	}
}


static void GetValueR(FILE *fp, char *str, void *v, int c)
{
	char buf[256];
	int s;

	while(FReadString(fp,buf,256))
	{
		fread(&s,1,4,fp);

		if(!strcmp(str, buf))
		{
			if(!c)	// String, allocate some memory.
			{
				if(!(*(char **)v=(char*)malloc(s)))
					goto gogl;
				
				fread(*(char **)v,1,s,fp);
				continue;
			}
			else if(s>c || s<c)
			{
				gogl:
				fseek(fp,s,SEEK_CUR);
				continue;
			}
		
			fread((uint8*)v,1,c,fp);
		}
		else
		{
			fseek(fp,s,SEEK_CUR);
		}
	}

	fseek(fp,4,SEEK_SET);
}

void SetValueR(FILE *fp, const char *str, void *v, int c)
{
	fwrite(str,1,strlen(str)+1,fp);
	fwrite((uint8*)&c,1,4,fp);
	fwrite((uint8*)v,1,c,fp);
}

/**
* Parses a c onfiguration structure and saves information from the structure into a file.
*
* @param cfgst The configuration structure.
* @param fp File handle.
**/
void SaveParse(const CFGSTRUCT *cfgst, FILE *fp)
{
	int x=0;

	while(cfgst[x].ptr)
	{

		//structure contains another embedded structure.
		//recurse.
		if(!cfgst[x].name) {
			SaveParse((CFGSTRUCT*)cfgst[x].ptr, fp);
			x++;
			continue;
		}

		if(cfgst[x].len)
		{
			// Plain data
			SetValueR(fp,cfgst[x].name,cfgst[x].ptr,cfgst[x].len);
		}
		else
		{
			// String
			if(*(char **)cfgst[x].ptr)
			{
				// Only save it if there IS a string.
				unsigned int len = strlen(*(char **)cfgst[x].ptr);
				SetValueR(fp,cfgst[x].name,*(char **)cfgst[x].ptr, len + 1);
			}
		}

		x++;
	}
}

/**
* Parses information from a file into a configuration structure.
*
* @param cfgst The configuration structure.
* @param fp File handle.
**/
void LoadParse(CFGSTRUCT *cfgst, FILE *fp)
{
	int x = 0;

	while(cfgst[x].ptr)
	{
		if(!cfgst[x].name)     // Link to new config structure
		{
			LoadParse((CFGSTRUCT*)cfgst[x].ptr, fp);
			x++;
			continue;
		}

		GetValueR(fp, cfgst[x].name, cfgst[x].ptr, cfgst[x].len);
		x++;
	} 
}


static void cfg_OldToNew(const CFGSTRUCT *cfgst)
{
	int x=0;

	while(cfgst[x].ptr)
	{
		//structure contains another embedded structure. recurse.
		if(!cfgst[x].name) {
			cfg_OldToNew((CFGSTRUCT*)cfgst[x].ptr);
			x++;
			continue;
		}

		if(cfgst[x].len)
		{
			//binary data
			cfgmap[cfgst[x].name] = BytesToString(cfgst[x].ptr,cfgst[x].len);
		}
		else
		{
			//string data
			if(*(char**)cfgst[x].ptr)
				cfgmap[cfgst[x].name] = *(char**)cfgst[x].ptr;
			else cfgmap[cfgst[x].name] = "";
		}

		x++;
	}
}

void cfg_NewToOld(CFGSTRUCT *cfgst)
{
	int x=0;

	while(cfgst[x].ptr)
	{
		//structure contains another embedded structure. recurse.
		if(!cfgst[x].name) {
			cfg_NewToOld((CFGSTRUCT*)cfgst[x].ptr);
			x++;
			continue;
		}

		//if the key was not found, skip it
		if(cfgmap.find(std::string(cfgst[x].name)) == cfgmap.end())
		{
			x++;
			continue;
		}

		if(cfgst[x].len)
		{
			//binary data
			if(!StringToBytes(cfgmap[cfgst[x].name],cfgst[x].ptr,cfgst[x].len))
				FCEUD_PrintError("Config error: error parsing parameter");
		}
		else
		{
			//string data
			if(*(char*)cfgst[x].ptr)
				free(cfgst[x].ptr);
			std::string& str = cfgmap[cfgst[x].name];
			if(str == "")
				*(char**)cfgst[x].ptr = 0;
			else
				*(char**)cfgst[x].ptr = strdup(cfgmap[cfgst[x].name].c_str());
		}

		x++;
	}
}

//saves the old fceu98 format
void SaveFCEUConfig_old(const char *filename, const CFGSTRUCT *cfgst)
{
	FILE *fp = fopen(filename,"wb");

	if(fp==NULL)
	{
		return;
	}

	SaveParse(cfgst, fp);

	fclose(fp);
}

void SaveFCEUConfig(const char *filename, const CFGSTRUCT *cfgst)
{
	FILE *fp = fopen(filename,"wb");

	if(fp==NULL)
		return;
	fclose(fp);		//adelikat:  Adding this so it will let go of the file handle without having to close the emulator!
	fp = fopen(filename,"wb");
	cfg_OldToNew(cfgst);
	cfg_Save(fp);
	fclose(fp);
}

//loads the old fceu98 format
void LoadFCEUConfig_old(const char *filename, CFGSTRUCT *cfgst)
{
	FILE *fp = fopen(filename,"rb");

	if(fp==NULL)
		return;

	LoadParse(cfgst,fp);

	fclose(fp);
}

void LoadFCEUConfig(const char *filename, CFGSTRUCT *cfgst)
{
	FILE *fp = fopen(filename,"rb");

	cfgmap.clear();

	//make sure there is a version key set
	cfgmap["!version"] = "1";

	if(fp==NULL)
		return;

	cfg_Parse(fp);
	cfg_NewToOld(cfgst);

	fclose(fp);
}
