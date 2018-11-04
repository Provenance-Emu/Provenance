/*
 * Australian Public Licence B (OZPLB)
 * 
 * Version 1-0
 * 
 * Copyright (c) 2004 University of New South Wales
 * 
 * All rights reserved. 
 * 
 * Developed by: Operating Systems and Distributed Systems Group (DiSy)
 *               University of New South Wales
 *               http://www.disy.cse.unsw.edu.au
 * 
 * Permission is granted by University of New South Wales, free of charge, to
 * any person obtaining a copy of this software and any associated
 * documentation files (the "Software") to deal with the Software without
 * restriction, including (without limitation) the rights to use, copy,
 * modify, adapt, merge, publish, distribute, communicate to the public,
 * sublicense, and/or sell, lend or rent out copies of the Software, and
 * to permit persons to whom the Software is furnished to do so, subject
 * to the following conditions:
 * 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimers.
 * 
 *     * Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimers in the documentation and/or other materials provided
 *       with the distribution.
 * 
 *     * Neither the name of University of New South Wales, nor the names of its
 *       contributors, may be used to endorse or promote products derived
 *       from this Software without specific prior written permission.
 * 
 * EXCEPT AS EXPRESSLY STATED IN THIS LICENCE AND TO THE FULL EXTENT
 * PERMITTED BY APPLICABLE LAW, THE SOFTWARE IS PROVIDED "AS-IS", AND
 * NATIONAL ICT AUSTRALIA AND ITS CONTRIBUTORS MAKE NO REPRESENTATIONS,
 * WARRANTIES OR CONDITIONS OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO ANY REPRESENTATIONS, WARRANTIES OR CONDITIONS
 * REGARDING THE CONTENTS OR ACCURACY OF THE SOFTWARE, OR OF TITLE,
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NONINFRINGEMENT,
 * THE ABSENCE OF LATENT OR OTHER DEFECTS, OR THE PRESENCE OR ABSENCE OF
 * ERRORS, WHETHER OR NOT DISCOVERABLE.
 * 
 * TO THE FULL EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL
 * NATIONAL ICT AUSTRALIA OR ITS CONTRIBUTORS BE LIABLE ON ANY LEGAL
 * THEORY (INCLUDING, WITHOUT LIMITATION, IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHERWISE) FOR ANY CLAIM, LOSS, DAMAGES OR OTHER
 * LIABILITY, INCLUDING (WITHOUT LIMITATION) LOSS OF PRODUCTION OR
 * OPERATION TIME, LOSS, DAMAGE OR CORRUPTION OF DATA OR RECORDS; OR LOSS
 * OF ANTICIPATED SAVINGS, OPPORTUNITY, REVENUE, PROFIT OR GOODWILL, OR
 * OTHER ECONOMIC LOSS; OR ANY SPECIAL, INCIDENTAL, INDIRECT,
 * CONSEQUENTIAL, PUNITIVE OR EXEMPLARY DAMAGES, ARISING OUT OF OR IN
 * CONNECTION WITH THIS LICENCE, THE SOFTWARE OR THE USE OF OR OTHER
 * DEALINGS WITH THE SOFTWARE, EVEN IF NATIONAL ICT AUSTRALIA OR ITS
 * CONTRIBUTORS HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH CLAIM, LOSS,
 * DAMAGES OR OTHER LIABILITY.
 * 
 * If applicable legislation implies representations, warranties, or
 * conditions, or imposes obligations or liability on University of New South
 * Wales or one of its contributors in respect of the Software that
 * cannot be wholly or partly excluded, restricted or modified, the
 * liability of University of New South Wales or the contributor is limited, to
 * the full extent permitted by the applicable legislation, at its
 * option, to:
 * a.  in the case of goods, any one or more of the following:
 * i.  the replacement of the goods or the supply of equivalent goods;
 * ii.  the repair of the goods;
 * iii. the payment of the cost of replacing the goods or of acquiring
 *  equivalent goods;
 * iv.  the payment of the cost of having the goods repaired; or
 * b.  in the case of services:
 * i.  the supplying of the services again; or
 * ii.  the payment of the cost of having the services supplied again.
 * 
 * The construction, validity and performance of this licence is governed
 * by the laws in force in New South Wales, Australia.
 */
#include "elf.h"
#include <string.h>

int
elf64_checkFile(void *elfFile)
{
	struct Elf64_Header *fileHdr = (struct Elf64_Header *) elfFile;
	if (fileHdr->e_ident[EI_MAG0] != ELFMAG0
	    || fileHdr->e_ident[EI_MAG1] != ELFMAG1
	    || fileHdr->e_ident[EI_MAG2] != ELFMAG2
	    || fileHdr->e_ident[EI_MAG3] != ELFMAG3)
		return -1;	/* not an elf file */
	if (fileHdr->e_ident[EI_CLASS] != ELFCLASS64)
		return -2;	/* not 64-bit file */
#if 0
	if (fileHdr->e_ident[EI_DATA] != ELFDATA2LSB)
		return -3;	/* not big-endian file */
	if (fileHdr->e_ident[EI_VERSION] != 1)
		return -4;	/* wrong version of elf */
	if (fileHdr->e_machine != 8)
		return -5;	/* wrong architecture (not MIPS) */
	if (fileHdr->e_type != 2)
		return -6;	/* not an executable program */
	if (fileHdr->e_phentsize != sizeof(struct Elf64_Phdr))
		return -7;	/* unexpected size of program segment
				 * header */
	if (fileHdr->e_phnum == 0)
		return -8;	/* no program segments */
	if ((fileHdr->e_flags & 0x7e) != 0)
		return -9;	/* wrong flags (did you forgot to compile
				 * with -mno-abicalls?) */
#endif
	return 0;		/* elf file looks OK */
}

struct Elf64_Phdr *
elf64_getProgramSegmentTable(void *elfFile)
/*
 * Returns a pointer to the program segment table, which is an array of
 * ELF64_Phdr_t structs.  The size of the array can be found by calling
 * getNumProgramSegments. 
 */
{
	struct Elf64_Header *fileHdr = (struct Elf64_Header *) elfFile;
	return (struct Elf64_Phdr *) ((size_t)fileHdr->e_phoff + (size_t) elfFile);
}

unsigned
elf64_getNumSections(void *elfFile)
/*
 * Returns the number of program segments in this elf file. 
 */
{
	struct Elf64_Header *fileHdr = (struct Elf64_Header *) elfFile;
	return fileHdr->e_shnum;
}

char           *
elf64_getStringTable(void *elfFile, int string_segment)
{
	struct Elf64_Shdr *sections = elf64_getSectionTable((Elf64_Header*)elfFile);
	return (char *) elfFile + sections[string_segment].sh_offset;
}

char           *
elf64_getSegmentStringTable(void *elfFile)
{
	struct Elf64_Header *fileHdr = (struct Elf64_Header *) elfFile;
	if (fileHdr->e_shstrndx == 0) {
		return NULL;
	} else {
		return elf64_getStringTable(elfFile, fileHdr->e_shstrndx);
	}
}

char *
elf64_getSectionName(void *elfFile, int i)
{
	struct Elf64_Shdr *sections = elf64_getSectionTable((Elf64_Header*)elfFile);
	char           *str_table = elf64_getSegmentStringTable((Elf64_Header*)elfFile);
	if (str_table == NULL) {
		return (char*)"<corrupted>";
	} else {
		return str_table + sections[i].sh_name;
	}
}

uint64_t
elf64_getSectionSize(void *elfFile, int i)
{
	struct Elf64_Shdr *sections = elf64_getSectionTable((Elf64_Header*)elfFile);
	return sections[i].sh_size;
}

uint64_t
elf64_getSectionAddr(struct Elf64_Header *elfFile, int i)
{
	struct Elf64_Shdr *sections = elf64_getSectionTable(elfFile);
	return sections[i].sh_addr;
}

void           *
elf64_getSection(void *elfFile, int i)
{
	struct Elf64_Shdr *sections = elf64_getSectionTable((Elf64_Header*)elfFile);
	return (char *)elfFile + sections[i].sh_offset;
}

void           *
elf64_getSectionNamed(void *elfFile, char *str)
{
	int             numSections = elf64_getNumSections(elfFile);
	int             i;
	for (i = 0; i < numSections; i++) {
		if (strcmp(str, elf64_getSectionName(elfFile, i)) == 0) {
			return elf64_getSection(elfFile, i);
		}
	}
	return NULL;
}

uint16_t
elf64_getNumProgramHeaders(struct Elf64_Header *elfFile)
{
	return elfFile->e_phnum;
}

int
elf64_getSegmentType (void *elfFile, int segment)
{
	return elf64_getProgramSegmentTable(elfFile)[segment].p_type;
}

void
elf64_getSegmentInfo(void *elfFile, int segment, uint64_t *p_vaddr, 
		     uint64_t *p_paddr, uint64_t *p_filesz, uint64_t *p_offset,
		     uint64_t *p_memsz)
{
	struct Elf64_Phdr *segments;
		
	segments = elf64_getProgramSegmentTable(elfFile);
	*p_vaddr = segments[segment].p_vaddr;
	*p_paddr = segments[segment].p_paddr;
	*p_filesz = segments[segment].p_filesz;
	*p_offset = segments[segment].p_offset;
	*p_memsz = segments[segment].p_memsz;
}

uint64_t
elf64_getEntryPoint (struct Elf64_Header *elfFile)
{
	return elfFile->e_entry;
}

/*
 * Debugging functions 
 */

#if 0
/*
 * prints out some details of one elf file 
 */
void
elf64_showDetails(void *elfFile, int size, char *name)
{
	struct Elf64_Phdr *segments;
	unsigned        numSegments;
	struct Elf64_Shdr *sections;
	unsigned        numSections;
	int             i,
	                r;
	char           *str_table;

	printf("Found an elf64 file called \"%s\" located "
	       "at address 0x%lx\n", name, elfFile);

	if ((r = elf64_checkFile(elfFile)) != 0) {
		char           *magic = elfFile;
		printf("Invalid elf file (%d)\n", r);
		printf("Magic is: %02.2hhx %02.2hhx %02.2hhx %02.2hhx\n",
		       magic[0], magic[1], magic[2], magic[3]);
		return;
	}

	str_table = elf64_getSegmentStringTable(elfFile);

	printf("Got str_table... %p\n", str_table);

	/*
	 * get a pointer to the table of program segments 
	 */
	segments = elf64_getProgramSegmentTable(elfFile);
	numSegments = elf64_getNumProgramSegments(elfFile);

	sections = elf64_getSectionTable(elfFile);
	numSections = elf64_getNumSections(elfFile);

	if ((void *) sections > (void *) elfFile + size ||
	    (((uintptr_t) sections & 0xf) != 0)) {
		printf("Corrupted elfFile..\n");
		return;
	}
	printf("Sections: %p\n", sections);
	/*
	 * print out info about each section 
	 */


	/*
	 * print out info about each program segment 
	 */
	printf("Program Headers:\n");
	printf("  Type           Offset   VirtAddr   PhysAddr   "
	       "FileSiz MemSiz  Flg Align\n");
	for (i = 0; i < numSegments; i++) {

		if (segments[i].p_type != 1) {
			printf("segment %d is not loadable, "
			       "skipping\n", i);
		} else {
			printf("  LOAD           0x%06lx 0x%08lx 0x%08lx"
			       " 0x%05lx 0x%05lx %c%c%c 0x%04lx\n",
			       segments[i].p_offset, segments[i].p_vaddr,
			       segments[i].p_vaddr,
			       segments[i].p_filesz, segments[i].p_memsz,
			       segments[i].p_flags & PF_R ? 'R' : ' ',
			       segments[i].p_flags & PF_W ? 'W' : ' ',
			       segments[i].p_flags & PF_X ? 'E' : ' ',
			       segments[i].p_align);
		}
	}

	printf("Section Headers:\n");
	printf("  [Nr] Name              Type            Addr     Off\n");
	for (i = 0; i < numSections; i++) {
		if (elf_checkSection(elfFile, i) == 0) {
			printf("%-17.17s %-15.15s %08x %06x\n", elf64_getSectionName(elfFile, i), " "	/* sections[i].sh_type 
													 */ ,
			       sections[i].sh_addr, sections[i].sh_offset);
		}
	}
}
#endif
