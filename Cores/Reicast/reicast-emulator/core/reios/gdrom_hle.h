#pragma once

#define SYSCALL_GDROM			(0x00)

#define GDROM_SEND_COMMAND		(0x00)
#define GDROM_CHECK_COMMAND		(0x01)
#define GDROM_MAIN				(0x02)
#define GDROM_INIT				(0x03)
#define GDROM_CHECK_DRIVE		(0x04)
#define GDROM_ABORT_COMMAND		(0x08)
#define GDROM_RESET				(0x09)
#define GDROM_SECTOR_MODE		(0x0A)


#define GDCC_PIOREAD			(16)
#define GDCC_DMAREAD			(17)
#define GDCC_GETTOC				(18)
#define GDCC_GETTOC2			(19)
#define GDCC_PLAY				(20)
#define GDCC_PLAY_SECTOR		(21)
#define GDCC_PAUSE				(22)
#define GDCC_RELEASE			(23)
#define GDCC_INIT				(24)
#define GDCC_SEEK				(27)
#define GDCC_READ				(28)
#define GDCC_STOP				(33)
#define GDCC_GETSCD				(34)
#define GDCC_GETSES				(35)


#define CTOC_LBA(n) (n)
#define CTOC_ADR(n) (n<<24)
#define CTOC_CTRL(n) (n<<28)
#define CTOC_TRACK(n) (n<<16)

void gdrom_hle_op();
void GD_HLE_Command(u32 cc, u32 prm);