/*
	Extremely primitive bios replacement

	Many thanks to Lars Olsson (jlo@ludd.luth.se) for bios decompile work
		http://www.ludd.luth.se/~jlo/dc/bootROM.c
		http://www.ludd.luth.se/~jlo/dc/bootROM.h
		http://www.ludd.luth.se/~jlo/dc/security_stuff.c
*/

#include "reios.h"

#include "reios_elf.h"

#include "gdrom_hle.h"
#include "descrambl.h"

#include "hw/sh4/sh4_mem.h"

#include "hw/naomi/naomi_cart.h"

#include <map>

//#define debugf printf

#define debugf(...) 

#define dc_bios_syscall_system				0x8C0000B0
#define dc_bios_syscall_font				0x8C0000B4
#define dc_bios_syscall_flashrom			0x8C0000B8
#define dc_bios_syscall_gd					0x8C0000BC
#define dc_bios_syscall_misc				0x8c0000E0

//At least one game (ooga) uses this directly
#define dc_bios_entrypoint_gd_do_bioscall	0x8c0010F0

#define SYSINFO_ID_ADDR 0x8C001010

u8* biosrom;
u8* flashrom;
u32 base_fad = 45150;
bool descrambl = false;

//Read 32 bit 'bi-endian' integer
//Uses big-endian bytes, that's what the dc bios does too
u32 read_u32bi(u8* ptr) {
	return (ptr[4]<<24) | (ptr[5]<<16) | (ptr[6]<<8) | (ptr[7]<<0);
}

bool reios_locate_bootfile(const char* bootfile="1ST_READ.BIN") {
	u32 data_len = 2048 * 1024;
	u8* temp = new u8[data_len];

	libGDR_ReadSector(temp, base_fad + 16, 1, 2048);

	if (memcmp(temp, "\001CD001\001", 7) == 0) {
		printf("reios: iso9660 PVD found\n");
		u32 lba = read_u32bi(&temp[156 + 2]); //make sure to use big endian
		u32 len = read_u32bi(&temp[156 + 10]); //make sure to use big endian
		
		data_len = ((len + 2047) / 2048) *2048;

		printf("reios: iso9660 root_directory, FAD: %d, len: %d\n", 150 + lba, data_len);
		libGDR_ReadSector(temp, 150 + lba, data_len/2048, 2048);
	}
	else {
		libGDR_ReadSector(temp, base_fad + 16, data_len / 2048, 2048);
	}

	for (int i = 0; i < (data_len-20); i++) {
		if (memcmp(temp+i, bootfile, strlen(bootfile)) == 0){
			printf("Found %s at %06X\n", bootfile, i);

			u32 lba = read_u32bi(&temp[i - 33 +  2]); //make sure to use big endian
			u32 len = read_u32bi(&temp[i - 33 + 10]); //make sure to use big endian
			
			printf("filename len: %d\n", temp[i - 1]);
			printf("file LBA: %d\n", lba);
			printf("file LEN: %d\n", len);

			if (descrambl)
				descrambl_file(lba + 150, len, GetMemPtr(0x8c010000, 0));
			else
				libGDR_ReadSector(GetMemPtr(0x8c010000, 0), lba + 150, (len + 2047) / 2048, 2048);

			if (false) {
				FILE* f = fopen("z:\\1stboot.bin", "wb");
				fwrite(GetMemPtr(0x8c010000, 0), 1, len, f);
				fclose(f);
			}

			delete[] temp;
			return true;
		}
	}

	delete[] temp;
	return false;
}

char ip_bin[256];
char reios_hardware_id[17];
char reios_maker_id[17];
char reios_device_info[17];
char reios_area_symbols[9];
char reios_peripherals[9];
char reios_product_number[11];
char reios_product_version[7];
char reios_releasedate[17];
char reios_boot_filename[17];
char reios_software_company[17];
char reios_software_name[129];
char reios_bootfile[32];

bool pre_init = false;

void reios_pre_init()
{
	if (libGDR_GetDiscType() == GdRom) {
		base_fad = 45150;
		descrambl = false;
	} else {
		u8 ses[6];
		libGDR_GetSessionInfo(ses, 0);
		libGDR_GetSessionInfo(ses, ses[2]);
		base_fad = (ses[3] << 16) | (ses[4] << 8) | (ses[5] << 0);
		descrambl = true;
	}
	pre_init = true;
}

char* reios_disk_id() {

	if (!pre_init) reios_pre_init();

	libGDR_ReadSector(GetMemPtr(0x8c008000, 0), base_fad, 256, 2048);
	memset(ip_bin, 0, sizeof(ip_bin));
	memcpy(ip_bin, GetMemPtr(0x8c008000, 0), 256);
	memcpy(&reios_hardware_id[0], &ip_bin[0], 16 * sizeof(char));
	memcpy(&reios_maker_id[0], &ip_bin[16],   16 * sizeof(char));
	memcpy(&reios_device_info[0], &ip_bin[32],   16 * sizeof(char));
	memcpy(&reios_area_symbols[0], &ip_bin[48],   8 * sizeof(char));
	memcpy(&reios_peripherals[0], &ip_bin[56],   8 * sizeof(char));
	memcpy(&reios_product_number[0], &ip_bin[64],   10 * sizeof(char));
	memcpy(&reios_product_version[0], &ip_bin[74],   6 * sizeof(char));
	memcpy(&reios_releasedate[0], &ip_bin[80],   16 * sizeof(char));
	memcpy(&reios_boot_filename[0], &ip_bin[96],   16 * sizeof(char));
	memcpy(&reios_software_company[0], &ip_bin[112],   16 * sizeof(char));
	memcpy(&reios_software_name[0], &ip_bin[128],   128 * sizeof(char));

	return reios_product_number;
}

const char* reios_locate_ip() {

	if (!pre_init) reios_pre_init();

	printf("reios: loading ip.bin from FAD: %d\n", base_fad);

	libGDR_ReadSector(GetMemPtr(0x8c008000, 0), base_fad, 16, 2048);
	
	memset(reios_bootfile, 0, sizeof(reios_bootfile));
	memcpy(reios_bootfile, GetMemPtr(0x8c008060, 0), 16);

	printf("reios: bootfile is '%s'\n", reios_bootfile);

	for (int i = 15; i >= 0; i--) {
		if (reios_bootfile[i] != ' ')
			break;
		reios_bootfile[i] = 0;
	}
	return reios_bootfile;
}


void reios_sys_system() {
	debugf("reios_sys_system\n");

	u32 cmd = Sh4cntx.r[7];

	switch (cmd) {
		case 0:	//SYSINFO_INIT
			Sh4cntx.r[0] = 0;
			break;

		case 2: //SYSINFO_ICON 
		{
			printf("SYSINFO_ICON\n");
			/*
				r4 = icon number (0-9, but only 5-9 seems to really be icons)
				r5 = destination buffer (704 bytes in size)
			*/
			Sh4cntx.r[0] = 704;
		}
		break;

		case 3: //SYSINFO_ID 
		{
			WriteMem32(SYSINFO_ID_ADDR + 0, 0xe1e2e3e4);
			WriteMem32(SYSINFO_ID_ADDR + 4, 0xe5e6e7e8);

			Sh4cntx.r[0] = SYSINFO_ID_ADDR;
		}
		break;

		default:
			printf("unhandled: reios_sys_system\n");
			break;
	}
}

void reios_sys_font() {
	printf("reios_sys_font\n");
}

void reios_sys_flashrom() {
	debugf("reios_sys_flashrom\n");

	u32 cmd = Sh4cntx.r[7];

	u32 flashrom_info[][2] = {
		{ 0 * 1024, 8 * 1024 },
		{ 8 * 1024, 8 * 1024 },
		{ 16 * 1024, 16 * 1024 },
		{ 32 * 1024, 32 * 1024 },
		{ 64 * 1024, 64 * 1024 },
	};

	switch (cmd) {
			case 0: // FLASHROM_INFO 
			{
				/*
					r4 = partition number(0 - 4)
					r5 = pointer to two 32 bit integers to receive the result.
						The first will be the offset of the partition start, in bytes from the start of the flashrom.
						The second will be the size of the partition, in bytes.

						#define FLASHROM_PT_SYSTEM      0   /< \brief Factory settings (read-only, 8K) 
						#define FLASHROM_PT_RESERVED    1   /< \brief reserved (all 0s, 8K) 
						#define FLASHROM_PT_BLOCK_1     2   /< \brief Block allocated (16K) 
						#define FLASHROM_PT_SETTINGS    3   /< \brief Game settings (block allocated, 32K) 
						#define FLASHROM_PT_BLOCK_2     4   /< \brief Block allocated (64K) 
				*/

				u32 part = Sh4cntx.r[4];
				u32 dest = Sh4cntx.r[5];

				u32* pDst = (u32*)GetMemPtr(dest, 8);

				if (part <= 4) {
					pDst[0] = flashrom_info[part][0];
					pDst[1] = flashrom_info[part][1];
					
					Sh4cntx.r[0] = 0;
				}
				else {
					Sh4cntx.r[0] = -1;
				}
			}
			break;

			case 1:	//FLASHROM_READ 
			{
				/*
				r4 = read start position, in bytes from the start of the flashrom
				r5 = pointer to destination buffer
				r6 = number of bytes to read
				*/
				u32 offs = Sh4cntx.r[4];
				u32 dest = Sh4cntx.r[5];
				u32 size = Sh4cntx.r[6];

				memcpy(GetMemPtr(dest, size), flashrom + offs, size);

				Sh4cntx.r[0] = size;
			}
			break;

			
			case 2:	//FLASHROM_WRITE 
			{
				/*
					r4 = write start position, in bytes from the start of the flashrom
					r5 = pointer to source buffer
					r6 = number of bytes to write
				*/

				u32 offs = Sh4cntx.r[4];
				u32 src = Sh4cntx.r[5];
				u32 size = Sh4cntx.r[6];

				u8* pSrc = GetMemPtr(src, size);

				for (int i = 0; i < size; i++) {
					flashrom[offs + i] &= pSrc[i];
				}
			}
			break;

			case 3:	//FLASHROM_DELETE  
			{			
				u32 offs = Sh4cntx.r[4];
				u32 dest = Sh4cntx.r[5];

				u32 part = 5;

				for (int i = 0; i <= 4; i++) {
					if (offs >= flashrom_info[i][0] && offs < (flashrom_info[i][0] + flashrom_info[i][1])) {
						part = i;
						break;
					}
				}

				if (part <= 4) {
					memset(flashrom + flashrom_info[part][0], 0xFF, flashrom_info[part][1]);
					Sh4cntx.r[0] = 0;
				}
				else {
					Sh4cntx.r[0] = -1;
				}
			}
			break;
			
	default:
		printf("reios_sys_flashrom: not handled, %d\n", cmd);
	}
}

void reios_sys_gd() {
	gdrom_hle_op();
}

/*
	- gdGdcReqCmd, 0
	- gdGdcGetCmdStat, 1
	- gdGdcExecServer, 2
	- gdGdcInitSystem, 3
	- gdGdcGetDrvStat, 4
*/
void gd_do_bioscall()
{
	//looks like the "real" entrypoint for this on a dreamcast
	gdrom_hle_op();
	return;

	/*
		int func1, func2, arg1, arg2;
	*/

	switch (Sh4cntx.r[7]) {
	case 0:	//gdGdcReqCmd, wth is r6 ?
		GD_HLE_Command(Sh4cntx.r[4], Sh4cntx.r[5]);
		Sh4cntx.r[0] = 0xf344312e;
		break;

	case 1:	//gdGdcGetCmdStat, r4 -> id as returned by gdGdcReqCmd, r5 -> buffer to get status in ram, r6 ?
		Sh4cntx.r[0] = 0; //All good, no status info
		break;

	case 2: //gdGdcExecServer
		//nop? returns something, though.
		//Bios seems to be based on a cooperative threading model
		//this is the "context" switch entry point
		break;

	case 3: //gdGdcInitSystem
		//nop? returns something, though.
		break;
	case 4: //gdGdcGetDrvStat
		/*
			Looks to same as GDROM_CHECK_DRIVE
		*/
		WriteMem32(Sh4cntx.r[4] + 0, 0x02);	// STANDBY
		WriteMem32(Sh4cntx.r[4] + 4, 0x80);	// CDROM | 0x80 for GDROM
		Sh4cntx.r[0] = 0;					// RET SUCCESS
		break;

	default:
		printf("gd_do_bioscall: (%d) %d, %d, %d\n", Sh4cntx.r[4], Sh4cntx.r[5], Sh4cntx.r[6], Sh4cntx.r[7]);
		break;
	}
	
	//gdGdcInitSystem
}

void reios_sys_misc() {
	printf("reios_sys_misc - r7: 0x%08X, r4 0x%08X, r5 0x%08X, r6 0x%08X\n", Sh4cntx.r[7], Sh4cntx.r[4], Sh4cntx.r[5], Sh4cntx.r[6]);
	Sh4cntx.r[0] = 0;
}

typedef void hook_fp();
u32 hook_addr(hook_fp* fn);

void setup_syscall(u32 hook_addr, u32 syscall_addr) {
	WriteMem32(syscall_addr, hook_addr);
	WriteMem16(hook_addr, REIOS_OPCODE);

	debugf("reios: Patching syscall vector %08X, points to %08X\n", syscall_addr, hook_addr);
	debugf("reios: - address %08X: data %04X [%04X]\n", hook_addr, ReadMem16(hook_addr), REIOS_OPCODE);
}

void reios_setup_state(u32 boot_addr) {
	/*
	Post Boot registers from actual bios boot
	r
	[0x00000000]	0xac0005d8
	[0x00000001]	0x00000009
	[0x00000002]	0xac00940c
	[0x00000003]	0x00000000
	[0x00000004]	0xac008300
	[0x00000005]	0xf4000000
	[0x00000006]	0xf4002000
	[0x00000007]	0x00000070
	[0x00000008]	0x00000000
	[0x00000009]	0x00000000
	[0x0000000a]	0x00000000
	[0x0000000b]	0x00000000
	[0x0000000c]	0x00000000
	[0x0000000d]	0x00000000
	[0x0000000e]	0x00000000
	[0x0000000f]	0x8d000000
	mac
	l	0x5bfcb024
	h	0x00000000
	r_bank
	[0x00000000]	0xdfffffff
	[0x00000001]	0x500000f1
	[0x00000002]	0x00000000
	[0x00000003]	0x00000000
	[0x00000004]	0x00000000
	[0x00000005]	0x00000000
	[0x00000006]	0x00000000
	[0x00000007]	0x00000000
	gbr	0x8c000000
	ssr	0x40000001
	spc	0x8c000776
	sgr	0x8d000000
	dbr	0x8c000010
	vbr	0x8c000000
	pr	0xac00043c
	fpul	0x00000000
	pc	0xac008300

	+		sr	{T=1 status = 0x400000f0}
	+		fpscr	{full=0x00040001}
	+		old_sr	{T=1 status=0x400000f0}
	+		old_fpscr	{full=0x00040001}

	*/

	//Setup registers to immitate a normal boot
	sh4rcb.cntx.r[15] = 0x8d000000;

	sh4rcb.cntx.gbr = 0x8c000000;
	sh4rcb.cntx.ssr = 0x40000001;
	sh4rcb.cntx.spc = 0x8c000776;
	sh4rcb.cntx.sgr = 0x8d000000;
	sh4rcb.cntx.dbr = 0x8c000010;
	sh4rcb.cntx.vbr = 0x8c000000;
	sh4rcb.cntx.pr = 0xac00043c;
	sh4rcb.cntx.fpul = 0x00000000;
	sh4rcb.cntx.pc = boot_addr;

	sh4rcb.cntx.sr.status = 0x400000f0;
	sh4rcb.cntx.sr.T = 1;

	sh4rcb.cntx.old_sr.status = 0x400000f0;

	sh4rcb.cntx.fpscr.full = 0x00040001;
	sh4rcb.cntx.old_fpscr.full = 0x00040001;
}

void reios_setuo_naomi(u32 boot_addr) {
	/*
		SR 0x60000000 0x00000001
		FPSRC 0x00040001

		-		xffr	0x13e1fe40	float [32]
		[0x0]	1.00000000	float
		[0x1]	0.000000000	float
		[0x2]	0.000000000	float
		[0x3]	0.000000000	float
		[0x4]	0.000000000	float
		[0x5]	1.00000000	float
		[0x6]	0.000000000	float
		[0x7]	0.000000000	float
		[0x8]	0.000000000	float
		[0x9]	0.000000000	float
		[0xa]	1.00000000	float
		[0xb]	0.000000000	float
		[0xc]	0.000000000	float
		[0xd]	0.000000000	float
		[0xe]	0.000000000	float
		[0xf]	1.00000000	float
		[0x10]	1.00000000	float
		[0x11]	2.14748365e+009	float
		[0x12]	0.000000000	float
		[0x13]	480.000000	float
		[0x14]	9.99999975e-006	float
		[0x15]	0.000000000	float
		[0x16]	0.00208333321	float
		[0x17]	0.000000000	float
		[0x18]	0.000000000	float
		[0x19]	2.14748365e+009	float
		[0x1a]	1.00000000	float
		[0x1b]	-1.00000000	float
		[0x1c]	0.000000000	float
		[0x1d]	0.000000000	float
		[0x1e]	0.000000000	float
		[0x1f]	0.000000000	float
		
		-		r	0x13e1fec0	unsigned int [16]
		[0x0]	0x0c021000	unsigned int
		[0x1]	0x0c01f820	unsigned int
		[0x2]	0xa0710004	unsigned int
		[0x3]	0x0c01f130	unsigned int
		[0x4]	0x5bfccd08	unsigned int
		[0x5]	0xa05f7000	unsigned int
		[0x6]	0xa05f7008	unsigned int
		[0x7]	0x00000007	unsigned int
		[0x8]	0x00000000	unsigned int
		[0x9]	0x00002000	unsigned int
		[0xa]	0xffffffff	unsigned int
		[0xb]	0x0c0e0000	unsigned int
		[0xc]	0x00000000	unsigned int
		[0xd]	0x00000000	unsigned int
		[0xe]	0x00000000	unsigned int
		[0xf]	0x0cc00000	unsigned int

		-		mac	{full=0x0000000000002000 l=0x00002000 h=0x00000000 }	Sh4Context::<unnamed-tag>::<unnamed-tag>::<unnamed-type-mac>
		full	0x0000000000002000	unsigned __int64
		l	0x00002000	unsigned int
		h	0x00000000	unsigned int
		
		-		r_bank	0x13e1ff08	unsigned int [8]
		[0x0]	0x00000000	unsigned int
		[0x1]	0x00000000	unsigned int
		[0x2]	0x00000000	unsigned int
		[0x3]	0x00000000	unsigned int
		[0x4]	0x00000000	unsigned int
		[0x5]	0x00000000	unsigned int
		[0x6]	0x00000000	unsigned int
		[0x7]	0x00000000	unsigned int
		gbr	0x0c2abcc0	unsigned int
		ssr	0x60000000	unsigned int
		spc	0x0c041738	unsigned int
		sgr	0x0cbfffb0	unsigned int
		dbr	0x00000fff	unsigned int
		vbr	0x0c000000	unsigned int
		pr	0xac0195ee	unsigned int
		fpul	0x000001e0	unsigned int
		pc	0x0c021000	unsigned int
		jdyn	0x0c021000	unsigned int

	*/

	//Setup registers to immitate a normal boot
	sh4rcb.cntx.r[0] = 0x0c021000;
	sh4rcb.cntx.r[1] = 0x0c01f820;
	sh4rcb.cntx.r[2] = 0xa0710004;
	sh4rcb.cntx.r[3] = 0x0c01f130;
	sh4rcb.cntx.r[4] = 0x5bfccd08;
	sh4rcb.cntx.r[5] = 0xa05f7000;
	sh4rcb.cntx.r[6] = 0xa05f7008;
	sh4rcb.cntx.r[7] = 0x00000007;
	sh4rcb.cntx.r[8] = 0x00000000;
	sh4rcb.cntx.r[9] = 0x00002000;
	sh4rcb.cntx.r[10] = 0xffffffff;
	sh4rcb.cntx.r[11] = 0x0c0e0000;
	sh4rcb.cntx.r[12] = 0x00000000;
	sh4rcb.cntx.r[13] = 0x00000000;
	sh4rcb.cntx.r[14] = 0x00000000;
	sh4rcb.cntx.r[15] = 0x0cc00000;

	sh4rcb.cntx.gbr = 0x0c2abcc0;
	sh4rcb.cntx.ssr = 0x60000000;
	sh4rcb.cntx.spc = 0x0c041738;
	sh4rcb.cntx.sgr = 0x0cbfffb0;
	sh4rcb.cntx.dbr = 0x00000fff;
	sh4rcb.cntx.vbr = 0x0c000000;
	sh4rcb.cntx.pr = 0xac0195ee;
	sh4rcb.cntx.fpul = 0x000001e0;
	sh4rcb.cntx.pc = boot_addr;

	sh4rcb.cntx.sr.status = 0x60000000;
	sh4rcb.cntx.sr.T = 1;

	sh4rcb.cntx.old_sr.status = 0x60000000;

	sh4rcb.cntx.fpscr.full = 0x00040001;
	sh4rcb.cntx.old_fpscr.full = 0x00040001;
}
void reios_boot() {
	printf("-----------------\n");
	printf("REIOS: Booting up\n");
	printf("-----------------\n");
	//setup syscalls
	//find boot file
	//boot it

	memset(GetMemPtr(0x8C000000, 0), 0xFF, 64 * 1024);

	setup_syscall(hook_addr(&reios_sys_system), dc_bios_syscall_system);
	setup_syscall(hook_addr(&reios_sys_font), dc_bios_syscall_font);
	setup_syscall(hook_addr(&reios_sys_flashrom), dc_bios_syscall_flashrom);
	setup_syscall(hook_addr(&reios_sys_gd), dc_bios_syscall_gd);
	setup_syscall(hook_addr(&reios_sys_misc), dc_bios_syscall_misc);

	WriteMem32(dc_bios_entrypoint_gd_do_bioscall, REIOS_OPCODE);
	//Infinitive loop for arm !
	WriteMem32(0x80800000, 0xEAFFFFFE);

	if (settings.reios.ElfFile.size()) {
		if (!reios_loadElf(settings.reios.ElfFile)) {
			msgboxf("Failed to open %s\n", MBX_ICONERROR, settings.reios.ElfFile.c_str());
		}
		reios_setup_state(0x8C010000);
	}
	else {
		if (DC_PLATFORM == DC_PLATFORM_DREAMCAST) {
			const char* bootfile = reios_locate_ip();
			if (!bootfile || !reios_locate_bootfile(bootfile))
				msgboxf("Failed to locate bootfile", MBX_ICONERROR);
			reios_setup_state(0xac008300);
		}
		else {
			verify(DC_PLATFORM == DC_PLATFORM_NAOMI);
			
			u32* sz = (u32*)naomi_cart_GetPtr(0x368, 4);
			if (!sz) {
				msgboxf("Naomi boot failure", MBX_ICONERROR);
			}

			int size = *sz;

			verify(size < RAM_SIZE && naomi_cart_GetPtr(size - 1, 1) && "Invalid cart size");

			WriteMemBlock_nommu_ptr(0x0c020000, (u32*)naomi_cart_GetPtr(0, size), size);

			reios_setuo_naomi(0x0c021000);
		}
	}
}

map<u32, hook_fp*> hooks;
map<hook_fp*, u32> hooks_rev;

#define SYSCALL_ADDR_MAP(addr) ((addr & 0x1FFFFFFF) | 0x80000000)

void register_hook(u32 pc, hook_fp* fn) {
	hooks[SYSCALL_ADDR_MAP(pc)] = fn;
	hooks_rev[fn] = pc;
}

void DYNACALL reios_trap(u32 op) {
	verify(op == REIOS_OPCODE);
	u32 pc = sh4rcb.cntx.pc - 2;
	sh4rcb.cntx.pc = sh4rcb.cntx.pr;

	u32 mapd = SYSCALL_ADDR_MAP(pc);

	debugf("reios: dispatch %08X -> %08X\n", pc, mapd);

	hooks[mapd]();
}

u32 hook_addr(hook_fp* fn) {
	if (hooks_rev.count(fn))
		return hooks_rev[fn];
	else {
		printf("hook_addr: Failed to reverse lookup %08X\n", (unat)fn);
		verify(false);
		return 0;
	}
}

bool reios_init(u8* rom, u8* flash) {

	printf("reios: Init\n");

	biosrom = rom;
	flashrom = flash;

	memset(rom, 0xEA, 2048 * 1024);
	memset(GetMemPtr(0x8C000000, 0), 0, RAM_SIZE);

	u16* rom16 = (u16*)rom;

	rom16[0] = REIOS_OPCODE;

	register_hook(0xA0000000, reios_boot);

	register_hook(0x8C001000, reios_sys_system);
	register_hook(0x8C001002, reios_sys_font);
	register_hook(0x8C001004, reios_sys_flashrom);
	register_hook(0x8C001006, reios_sys_gd);
	register_hook(0x8C001008, reios_sys_misc);

	register_hook(dc_bios_entrypoint_gd_do_bioscall, &gd_do_bioscall);

	return true;
}

void reios_reset() {

}

void reios_term() {

}
