
#ifndef __DLLEXPORTS2_H__
#define __DLLEXPORTS2_H__ 1

#include "../../Common/MyGuidDef.h"

STDAPI CreateObject(const GUID *clsid, const GUID *iid, void **outObject);

#endif

