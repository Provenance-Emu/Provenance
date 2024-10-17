
#ifndef _NETQUEUE_H
#define _NETQUEUE_H

#include "types.h"

typedef Uint32 NetQueueElementT; 

#define NETQUEUE_SIZE (128)
#define NETQUEUE_MASK (NETQUEUE_SIZE - 1)

typedef struct NetQueue_t
{
	Uint32				uHead;
	Uint32				uTail;

	NetQueueElementT	Elements[NETQUEUE_SIZE];
} NetQueueT;


void NetQueueNew(NetQueueT *pQueue);
void NetQueueDelete(NetQueueT *pQueue);
void NetQueueReset(NetQueueT *pQueue, Uint32 uSeqNum);
Int32 NetQueueGetCount(NetQueueT *pQueue);
Bool NetQueueDequeue(NetQueueT *pQueue, NetQueueElementT *pElement);
Bool NetQueueEnqueue(NetQueueT *pQueue, NetQueueElementT *pElement);
Bool NetQueueEnqueueAt(NetQueueT *pQueue, Uint32 uPos, NetQueueElementT *pElement);
Bool NetQueueGetElement(NetQueueT *pQueue, Uint32 uPos, NetQueueElementT *pElement);
Int32 NetQueueFetchRange(NetQueueT *pQueue, Uint32 uStart, Uint32 uEnd, NetQueueElementT *pElement, Int32 nMaxElements);

#endif
