/*
 * Australian Public Licence B (OZPLB)
 * 
 * Version 1-0
 * 
 * Copyright (c) 1999-2004 University of New South Wales
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

/*
  Authors: Luke Deller, Ben Leslie
  Created: 24/Sep/1999
*/

/**
\file

\brief Generic ELF library

The ELF library is designed to make the task of parsing and getting information
out of an ELF file easier.

It provides function to obtain the various different fields in the ELF header, and
the program and segment information.

Also importantly, it provides a function elf_loadFile which will load a given
ELF file into memory.

*/

#ifndef __ELF_ELF_H__
#define __ELF_ELF_H__

#include <stdint.h>
#include <stdio.h>

#include "elf32.h"
#include "elf64.h"

struct elf_symbol {
  uint32_t st_name;               // Symbol name (string table index)
  uint32_t st_value;              // Symbol value
  uint32_t st_size;               // Symbol size
  uint8_t  st_info;               // Symbol type and binding
  uint8_t  st_other;              // No defined meaning, 0 
  uint16_t st_shndx;              // Section index
};

struct elf64_symbol {
  uint32_t      st_name;
  unsigned char st_info;
  unsigned char st_other;
  uint16_t      st_shndx;
  uint64_t      st_value;
  uint64_t      st_size;
};

/*
 * constants for Elf32_Phdr.p_flags 
 */
#define PF_X		1	/* readable segment */
#define PF_W		2	/* writeable segment */
#define PF_R		4	/* executable segment */

/*
 * constants for indexing into Elf64_Header_t.e_ident 
 */
#define EI_MAG0		0
#define EI_MAG1		1
#define EI_MAG2		2
#define EI_MAG3		3
#define EI_CLASS	4
#define EI_DATA		5
#define EI_VERSION	6

#define ELFMAG0         '\177'
#define ELFMAG1         'E'
#define ELFMAG2         'L'
#define ELFMAG3         'F'

#define ELFCLASS32      1
#define ELFCLASS64      2

#define PT_NULL 0
#define PT_LOAD 1
#define PT_DYNAMIC 2
#define PT_INTERP 3
#define PT_NOTE 4

#define ELFDATA2LSB 1
#define ELFDATA2MSB 2

/* Section Header type bits */
#define SHT_PROGBITS 1
#define SHT_SYMTAB 2
#define	SHT_NOBITS 8
#define SHT_REL 9

/* Section Header flag bits */
#define SHF_WRITE 1
#define SHF_ALLOC 2
#define SHF_EXECINSTR  4

/**/
#define ELF_PRINT_PROGRAM_HEADERS 1
#define ELF_PRINT_SECTIONS 2
#define ELF_PRINT_ALL (ELF_PRINT_PROGRAM_HEADERS | ELF_PRINT_SECTIONS)

/* Symbol types */
#define STT_FUNC 2 /* Function, code */

/**
 * Checks that elfFile points to a valid elf file. 
 *
 * @param elfFile Potential ELF file to check
 *
 * \return 0 on success. -1 if not and elf, -2 if not 32 bit.
 */
int elf_checkFile(void *elfFile);

/**
 * Determine number of sections in an ELF file.
 *
 * @param elfFile Pointer to a valid ELF header.
 *
 * \return Number of sections in the ELF file.
 */
unsigned elf_getNumSections(void *elfFile);

/**
 * Determine number of program headers in an ELF file.
 *
 * @param elfFile Pointer to a valid ELF header.
 *
 * \return Number of program headers in the ELF file.
 */
uint16_t elf_getNumProgramHeaders(void *elfFile);

/**
 * Return the base physical address of given program header in an ELF file
 *
 * @param elfFile Pointer to a valid ELF header
 * @param ph Index of the program header
 *
 * \return The memory size of the specified program header
 */
uint64_t elf_getProgramHeaderPaddr(void *elfFile, uint16_t ph);

/**
 * Return the base virtual address of given program header in an ELF file
 *
 * @param elfFile Pointer to a valid ELF header
 * @param ph Index of the program header
 *
 * \return The memory size of the specified program header
 */
uint64_t elf_getProgramHeaderVaddr(void *elfFile, uint16_t ph);

/**
 * Return the memory size of a given program header in an ELF file
 *
 * @param elfFile Pointer to a valid ELF header
 * @param ph Index of the program header
 *
 * \return The memory size of the specified program header
 */
uint64_t elf_getProgramHeaderMemorySize(void *elfFile, uint16_t ph);

/**
 * Return the file size of a given program header in an ELF file
 *
 * @param elfFile Pointer to a valid ELF header
 * @param ph Index of the program header
 *
 * \return The file size of the specified program header
 */
uint64_t elf_getProgramHeaderFileSize(void *elfFile, uint16_t ph);

/**
 * Return the start offset of he file
 *
 * @param elfFile Pointer to a valid ELF header
 * @param ph Index of the program header
 *
 * \return The offset of this program header with relation to the start
 * of the elfFile.
 */
uint64_t elf_getProgramHeaderOffset(void *elfFile, uint16_t ph);

/**
 * Return the flags for a given program header
 *
 * @param elfFile Pointer to a valid ELF header
 * @param ph Index of the program header
 *
 * \return The flags of a given program header
 */
uint32_t elf_getProgramHeaderFlags(void *elfFile, uint16_t ph);

/**
 * Return the type for a given program header
 *
 * @param elfFile Pointer to a valid ELF header
 * @param ph Index of the program header
 *
 * \return The type of a given program header
 */
uint32_t elf_getProgramHeaderType(void *elfFile, uint16_t ph);

/**
 * Return the physical translation of a physical address, with respect
 * to a given program header
 *
 */
uint64_t elf_vtopProgramHeader(void *elfFile, uint16_t ph, uint64_t vaddr);


/**
 * 
 * \return true if the address in in this program header
 */
bool elf_vaddrInProgramHeader(void *elfFile, uint16_t ph, uint64_t vaddr);

/**
 * Determine the memory bounds of an ELF file
 *
 * @param elfFile Pointer to a valid ELF header
 * @param phys If true return bounds of physical memory, otherwise return
 *   bounds of virtual memory
 * @param min Pointer to return value of the minimum
 * @param max Pointer to return value of the maximum
 *
 * \return true on success. false on failure, if for example, it is an invalid ELF file 
 */
bool elf_getMemoryBounds(void *elfFile, bool phys, uint64_t *min, uint64_t *max);

/**
 * Find the entry point of an ELF file.
 *
 * @param elfFile Pointer to a valid ELF header
 *
 * \return The entry point address as a 64-bit integer.
 */
uint64_t elf_getEntryPoint(void *elfFile);

/**
 * Load an ELF file into memory
 *
 * @param elfFile Pointer to a valid ELF file
 * @param phys If true load using the physical address, otherwise using the virtual addresses
 *
 * \return true on success, false on failure.
 *
 * The function assumes that the ELF file is loaded in memory at some
 * address different to the target address at which it will be loaded.
 * It also assumes direct access to the source and destination address, i.e:
 * Memory must be ale to me loaded with a simple memcpy.
 *
 * Obviously this also means that if we are loading a 64bit ELF on a 32bit
 * platform, we assume that any memory address are within the first 4GB.
 *
 */
bool elf_loadFile(void *elfFile, bool phys);

char *elf_getStringTable(void *elfFile, int string_segment);
char *elf_getSegmentStringTable(void *elfFile);
void *elf_getSectionNamed(void *elfFile, char *str);
char *elf_getSectionName(void *elfFile, int i);
uint64_t elf_getSectionSize(void *elfFile, int i);
uint64_t elf_getSectionLink(void *elfFile, int i);
uint64_t elf_getSectionAddr(void *elfFile, int i);

/**
 * Return the flags for a given sections
 *
 * @param elfFile Pointer to a valid ELF header
 * @param i Index of the sections
 *
 * \return The flags of a given section
 */
uint32_t elf_getSectionFlags(void *elfFile, int i);

/**
 * Return the type for a given sections
 *
 * @param elfFile Pointer to a valid ELF header
 * @param i Index of the sections
 *
 * \return The type of a given section
 */
uint32_t elf_getSectionType(void *elfFile, int i);

void *elf_getSection(void *elfFile, int i);
void elf_getProgramHeaderInfo(void *elfFile, uint16_t ph, uint64_t *p_vaddr, 
			      uint64_t *p_paddr, uint64_t *p_filesz, 
			      uint64_t *p_offset, uint64_t *p_memsz);


/**
 * output the details of an ELF file to the stream f
 */
void elf_fprintf(FILE *f, void *elfFile, int size, const char *name, int flags);

#define SHT_DYNSYM 0xB
#if 0
/*
 * Returns a pointer to the program segment table, which is an array of
 * ELF64_Phdr_t structs.  The size of the array can be found by calling
 * getNumProgramSegments. 
 */
struct Elf32_Phdr *elf_getProgramSegmentTable(void *elfFile);
#endif
#if 0
/**
 * Returns a pointer to the program segment table, which is an array of
 * ELF64_Phdr_t structs.  The size of the array can be found by calling
 * getNumProgramSegments. 
 */
struct Elf32_Shdr *elf_getSectionTable(void *elfFile);
#endif

#endif
