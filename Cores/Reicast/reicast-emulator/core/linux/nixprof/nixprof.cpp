#include "types.h"

#if FEAT_HAS_NIXPROF
#include "cfg/cfg.h"

#include <inttypes.h>

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/types.h>
#include <stdio.h>
#include <memory.h>
#include <signal.h>
//#include <sys/ucontext.h>
#include <stdio.h>
#include <signal.h>
//#include <execinfo.h>
#include <sys/syscall.h>
#include <sys/stat.h>

#include <poll.h>
#include <termios.h>
//#include <curses.h>
#include <fcntl.h>
#include <semaphore.h>
#include <stdarg.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/mman.h>
#include <sys/time.h>
#include "hw/sh4/dyna/blockmanager.h"
#include <set>
#include "deps/libelf/elf.h"
#include "profiler/profiler.h"

#include "linux/context.h"

/** 
@file      CallStack_Android.h 
@brief     Getting the callstack under Android 
@author    Peter Holtwick 
*/ 
#include <unwind.h> 
#include <stdio.h> 
#include <string.h> 

static int tick_count=0;
static pthread_t proft;
static pthread_t thread[2];
static void*     prof_address[2];
static u32 prof_wait;

static u8* syms_ptr;
static int syms_len;

void sample_Syms(u8* data,u32 len)
{
	syms_ptr=data;
	syms_len=len;
}

void prof_handler (int sn, siginfo_t * si, void *ctxr)
{
	rei_host_context_t ctx;
	context_from_segfault(&ctx, ctxr);
	
	int thd=-1;
	if (pthread_self()==thread[0]) thd=0;
	else if (pthread_self()==thread[1]) thd=1;
	else return;

	prof_address[thd] = (void*)ctx.pc;
}



void install_prof_handler(int id)
{
	struct sigaction act, segv_oact;
	memset(&act, 0, sizeof(act));
	act.sa_sigaction = prof_handler;
	sigemptyset(&act.sa_mask);
	act.sa_flags = SA_SIGINFO | SA_RESTART;
	sigaction(SIGPROF, &act, &segv_oact);

	thread[id]=pthread_self();
}

static void prof_head(FILE* out, const char* type, const char* name)
{
	fprintf(out,"==xx==xx==\n%s:%s\n",type,name);
}

static void prof_head(FILE* out, const char* type, int d)
{
	fprintf(out,"==xx==xx==\n%s:%d\n",type,d);
}

static void elf_syms(FILE* out,const char* libfile)
{
	struct stat statbuf;

	printf("LIBFILE \"%s\"\n", libfile);
	int fd = open(libfile, O_RDONLY, 0);

	if (!fd)
	{
		printf("Failed to open file \"%s\"\n", libfile);
		return;
	}
	if (fstat(fd, &statbuf) < 0)
	{
		printf("Failed to fstat file \"%s\"\n", libfile);
		return;
	}

	{
		void* data = mmap(0, statbuf.st_size, PROT_READ, MAP_SHARED, fd, 0);
		close(fd);

		if (data == (void*)-1)
		{
			printf("Failed to mmap file \"%s\"\n", libfile);
			return;
		}

		//printf("MMap: %08p, %08X\n",data,statbuf.st_size);

		int dynsym=-1;
		int dynstr=-1;
		int strtab=-1;
		int symtab=-1;

		if (elf_checkFile(data)>=0)
		{
			int scnt=elf_getNumSections(data);

			for (int si=0;si<scnt;si++)
			{
				uint32_t section_type = elf_getSectionType(data, si);
				uint64_t section_link = elf_getSectionLink(data, si);
				switch (section_type) {
				case SHT_DYNSYM:
					fprintf(stderr, "DYNSYM");
					dynsym = si;
					if (section_link < scnt)
						dynstr = section_link;
					break;
				case SHT_SYMTAB:
					fprintf(stderr, "SYMTAB");
					symtab = si;
					if (section_link < scnt)
						strtab = section_link;
					break;
				default:
					break;;
				}
			}
		}
		else
		{
			printf("Invalid elf file\n");
		}

		// Use SHT_SYMTAB if available insteaf of SHT_DYNSYM
		// (there is more info here):
		if (symtab >= 0 && strtab >= 0)
		{
			dynsym = symtab;
			dynstr = strtab;
		}

		if (dynsym >= 0)
		{
			prof_head(out,"libsym",libfile);
			// printf("Found dymsym %d, and dynstr %d!\n",dynsym,dynstr);
			elf_symbol* sym=(elf_symbol*)elf_getSection(data,dynsym);
			elf64_symbol* sym64 = (elf64_symbol*) sym;

			bool elf32 = ((struct Elf32_Header*)data)->e_ident[EI_CLASS] == ELFCLASS32;
			size_t symbol_size = elf32 ? sizeof(elf_symbol) : sizeof(elf64_symbol);
			int symcnt = elf_getSectionSize(data,dynsym) / symbol_size;

			for (int i=0; i < symcnt; i++)
			{
				uint64_t st_value =  elf32 ? sym[i].st_value : sym64[i].st_value;
				uint32_t st_name  =  elf32 ? sym[i].st_name  : sym64[i].st_name;
				uint16_t st_shndx =  elf32 ? sym[i].st_shndx : sym64[i].st_shndx;
				uint16_t st_type  = (elf32 ? sym[i].st_info  : sym64[i].st_info) & 0xf;
				uint64_t st_size  =  elf32 ? sym[i].st_size  : sym64[i].st_size;
				if (st_type == STT_FUNC && st_value && st_name && st_shndx)
				{
					char* name=(char*)elf_getSection(data,dynstr);// sym[i].st_shndx
					// printf("Symbol %d: %s, %08" PRIx64 ", % " PRIi64 " bytes\n",
						// i, name + st_name, st_value, st_size);
					//PRIx64 & friends not in android ndk (yet?)
					fprintf(out,"%08x %d %s\n", (int)st_value, (int)st_size, name + st_name);
				}
			}
		}
		else
		{
			printf("No dynsym\n");
		}

		munmap(data,statbuf.st_size);
	}
}

static volatile bool prof_run;

// This is not used:
static int str_ends_with(const char * str, const char * suffix)
{
	if (str == NULL || suffix == NULL)
		return 0;

	size_t str_len = strlen(str);
	size_t suffix_len = strlen(suffix);

	if (suffix_len > str_len)
		return 0;

	return 0 == strncmp(str + str_len - suffix_len, suffix, suffix_len);
}

void sh4_jitsym(FILE* out);

static void* profiler_main(void *ptr)
{
	FILE* prof_out;
	char line[512];

	sprintf(line, "/%d.reprof", tick_count);

		string logfile=get_writable_data_path(line);


		printf("Profiler thread logging to -> %s\n", logfile.c_str());

		prof_out = fopen(logfile.c_str(), "wb");
		if (!prof_out)
		{
			printf("Failed to open profiler file\n");
			return 0;
		}

		set<string> libs;

		prof_head(prof_out, "vaddr", "");
		FILE* maps = fopen("/proc/self/maps", "r");
		while (!feof(maps))
		{
			fgets(line, 512, maps);
			fputs(line, prof_out);

			if (strstr(line, ".so"))
			{
				char file[512];
				file[0] = 0;
				sscanf(line, "%*x-%*x %*s %*x %*x:%*x %*d %s\n", file);
				if (strlen(file))
					libs.insert(file);
			}
		}

		//Write map file
		prof_head(prof_out, ".map", "");
		fwrite(syms_ptr, 1, syms_len, prof_out);

		//write exports from .so's
		for (set<string>::iterator it = libs.begin(); it != libs.end(); it++)
		{
			elf_syms(prof_out, it->c_str());
		}

		//Write shrec syms file !
		prof_head(prof_out, "jitsym", "SH4");
		
		#if FEAT_SHREC != DYNAREC_NONE
		sh4_jitsym(prof_out);
		#endif

		//Write arm7rec syms file ! -> to do
		//prof_head(prof_out,"jitsym","ARM7");

		prof_head(prof_out, "samples", prof_wait);

		do
		{
			tick_count++;
			// printf("Sending SIGPROF %08X %08X\n",thread[0],thread[1]);
			for (int i = 0; i < 2; i++) pthread_kill(thread[i], SIGPROF);
			// printf("Sent SIGPROF\n");
			usleep(prof_wait);
			// fwrite(&prof_address[0],1,sizeof(prof_address[0])*2,prof_out);
			fprintf(prof_out, "%p %p\n", prof_address[0], prof_address[1]);

			if (!(tick_count % 10000))
			{
				printf("Profiler: %d ticks, flushing ..\n", tick_count);
				fflush(prof_out);
			}
		} while (prof_run);

		fclose(maps);
		fclose(prof_out);
    
    return 0;
}

bool sample_Switch(int freq)
{
	if (prof_run) {
		sample_Stop();
	} else {
		sample_Start(freq);
	}
	return prof_run;
}

void sample_Start(int freq)
{
	if (prof_run)
		return;
	prof_wait = 1000000 / freq;
	printf("sampling profiler: starting %d Hz %d wait\n", freq, prof_wait);
	prof_run = true;
	pthread_create(&proft, NULL, profiler_main, 0);
}

void sample_Stop()
{
	if (prof_run)
	{
		prof_run = false;
		pthread_join(proft, NULL);
	}
	printf("sampling profiler: stopped\n");
}
#endif
