/*
	Command line parsing
	~yay~

	Nothing too interesting here, really
*/

#include <stdio.h>
#include <ctype.h>
#include <string.h>

#include "cfg/cfg.h"

wchar* trim_ws(wchar* str)
{
	if (str==0 || strlen(str)==0)
		return 0;

	while(*str)
	{
		if (!isspace(*str))
			break;
		str++;
	}

	size_t l=strlen(str);
	
	if (l==0)
		return 0;

	while(l>0)
	{
		if (!isspace(str[l-1]))
			break;
		str[l-1]=0;
		l--;
	}

	if (l==0)
		return 0;

	return str;
}

int setconfig(wchar** arg,int cl)
{
	int rv=0;
	for(;;)
	{
		if (cl<1)
		{
			printf("-config : invalid number of parameters, format is section:key=value\n");
			return rv;
		}
		wchar* sep=strstr(arg[1],":");
		if (sep==0)
		{
			printf("-config : invalid parameter %s, format is section:key=value\n",arg[1]);
			return rv;
		}
		wchar* value=strstr(sep+1,"=");
		if (value==0)
		{
			printf("-config : invalid parameter %s, format is section:key=value\n",arg[1]);
			return rv;
		}

		*sep++=0;
		*value++=0;

		wchar* sect=trim_ws(arg[1]);
		wchar* key=trim_ws(sep);
		value=trim_ws(value);

		if (sect==0 || key==0)
		{
			printf("-config : invalid parameter, format is section:key=value\n");
			return rv;
		}

		const wchar* constval = value;
		if (constval==0)
			constval="";
		printf("Virtual cfg %s:%s=%s\n",sect,key,value);

		cfgSetVirtual(sect,key,value);
		rv++;

		if (cl>=3 && stricmp(arg[2],",")==0)
		{
			cl-=2;
			arg+=2;
			rv++;
			continue;
		}
		else
			break;
	}
	return rv;
}

#ifndef _ANDROID
#include "version.h"
#else
#define REICAST_VERSION "r7-android-tmp"
#endif

#if !defined(DEF_CONSOLE)
#if defined(linux) || defined(_ANDROID)
#define DEF_CONSOLE
#endif
#endif

#if defined(_WIN32)
#include <conio.h>
#endif

void cli_pause()
{
#ifdef DEF_CONSOLE
	return;
#endif

#if defined(_WIN32)
	printf("\nPress a key to exit.\n");
	_getch();
#else
	printf("\nPress enter to exit.\n");
	char c = getchar();
#endif
}



int showhelp(wchar** arg,int cl)
{
	printf("\nAvailable commands :\n");

	printf("-config	section:key=value [, ..]: add a virtual config value\n Virtual config values won't be saved to the .cfg file\n unless a different value is written to em\nNote :\n You can specify many settings in the xx:yy=zz , gg:hh=jj , ...\n format.The spaces between the values and ',' are needed.\n");
	printf("\n-help: show help info\n");
	printf("\n-version: show current version #\n\n");

	cli_pause();
	return 0;
}


int showversion(wchar** arg,int cl)
{
	printf("\nReicast Version: # %s built on %s \n", REICAST_VERSION, __DATE__);

	cli_pause();
	return 0;
}

bool ParseCommandLine(int argc,wchar* argv[])
{
	int cl=argc-2;
	wchar** arg=argv+1;
	while(cl>=0)
	{
		if (stricmp(*arg,"-help")==0 || stricmp(*arg,"--help")==0)
		{
			showhelp(arg,cl);
			return true;
		}
		if (stricmp(*arg,"-version")==0 || stricmp(*arg,"--version")==0)
		{
			showversion(arg,cl);
			return true;
		}
		else if (stricmp(*arg,"-config")==0 || stricmp(*arg,"--config")==0)
		{
			int as=setconfig(arg,cl);
			cl-=as;
			arg+=as;
		}
		else
		{
			char* extension = strrchr(*arg, '.');

			if (extension
				&& (stricmp(extension, ".cdi") == 0 || stricmp(extension, ".chd") == 0
					|| stricmp(extension, ".gdi") == 0 || stricmp(extension, ".lst") == 0))
			{
				printf("Using '%s' as cd image\n", *arg);
				cfgSetVirtual("config", "image", *arg);
			}
			else if (extension && stricmp(extension, ".elf") == 0)
			{
				printf("Using '%s' as reios elf file\n", *arg);
				cfgSetVirtual("config", "reios.enabled", "1");
				cfgSetVirtual("reios", "ElfFile", *arg);
			}
			else
			{
				printf("wtf %s is supposed to do ?\n",*arg);
			}
		}
		arg++;
		cl--;
	}
	printf("\n");
	return false;
}
