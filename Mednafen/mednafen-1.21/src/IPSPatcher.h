#ifndef __MDFN_IPSPATCHER_H
#define __MDFN_IPSPATCHER_H

#include <mednafen/Stream.h>

struct IPSPatcher
{
 // Returns the number of patches encountered(!= bytes patched, usually).
 static uint32 Apply(Stream* ips, Stream* targ);
};


#endif
