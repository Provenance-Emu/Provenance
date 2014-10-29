#ifndef __MDFN_CDROMFILE_H
#define __MDFN_CDROMFILE_H

#include <stdio.h>

#include "CDUtility.h"

class CDAccess
{
 public:

 CDAccess();
 virtual ~CDAccess();

 virtual void Read_Raw_Sector(uint8 *buf, int32 lba) = 0;

 virtual void Read_TOC(CDUtility::TOC *toc) = 0;

 virtual bool Is_Physical(void) throw() = 0;

 virtual void Eject(bool eject_status) = 0;		// Eject a disc if it's physical, otherwise NOP.  Returns true on success(or NOP), false on error

 private:
 CDAccess(const CDAccess&);	// No copy constructor.
 CDAccess& operator=(const CDAccess&); // No assignment operator.
};

CDAccess *cdaccess_open_image(const char *path, bool image_memcache);
CDAccess *cdaccess_open_phys(const char *devicename);

#endif
