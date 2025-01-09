
#ifndef _PATHEXT_H
#define _PATHEXT_H

typedef Uint32 PathExtTypeE;

int PathExtAdd(PathExtTypeE Type, char *pExt);
Bool PathExtResolve(char *pPath, PathExtTypeE *pType, Bool bTruncatePath);
char *PathExtGet(char *pPath);

#endif
