
#include "types.h"
#include "netqueue.h"


void NetQueueNew(NetQueueT *pQueue)
{
	NetQueueReset(pQueue,0);
}

void NetQueueDelete(NetQueueT *pQueue)
{
	NetQueueReset(pQueue,0);
}

void NetQueueReset(NetQueueT *pQueue, Uint32 uSeqNum)
{
	pQueue->uHead = uSeqNum;
	pQueue->uTail = uSeqNum;
}


Int32 NetQueueGetCount(NetQueueT *pQueue)
{
	// this should never be < 0
	return (Int32)(pQueue->uTail - pQueue->uHead);
}


Bool NetQueueDequeue(NetQueueT *pQueue, NetQueueElementT *pElement)
{
	// is queue empty?
	if (NetQueueGetCount(pQueue) > 0)
	{
		// dequeue element from head
		*pElement = pQueue->Elements[pQueue->uHead & NETQUEUE_MASK];
		pQueue->uHead++;

		return TRUE;
	}

	return FALSE;
}

Bool NetQueueEnqueue(NetQueueT *pQueue, NetQueueElementT *pElement)
{
	// is queue full?
	if (NetQueueGetCount(pQueue) < NETQUEUE_SIZE)
	{
		// enqueue element at tail
		pQueue->Elements[pQueue->uTail & NETQUEUE_MASK] = *pElement;
		pQueue->uTail++;

		return TRUE;
	} 
	return FALSE;
}

Bool NetQueueEnqueueAt(NetQueueT *pQueue, Uint32 uPos, NetQueueElementT *pElement)
{
	if (uPos == pQueue->uTail)
	{
		return NetQueueEnqueue(pQueue, pElement);
	}
	return FALSE;
}

Bool NetQueueGetElement(NetQueueT *pQueue, Uint32 uPos, NetQueueElementT *pElement)
{
	if (uPos >= pQueue->uHead && uPos < pQueue->uTail)
	{
		*pElement = pQueue->Elements[uPos & NETQUEUE_MASK];
		return TRUE;
	}
	return FALSE;
}

Int32 NetQueueFetchRange(NetQueueT *pQueue, Uint32 uStart, Uint32 uEnd, NetQueueElementT *pElement, Int32 nMaxElements)
{
	Int32 nLength;
	Int32 nElements = 0;

	nLength = (Int32)(uEnd - uStart);

	// dont overflow buffer
	if (nLength > nMaxElements)
	{
		nLength = nMaxElements;
	}

	if (nLength >= 0)
	{
		// fetch forward
		while (uStart!=uEnd)
		{
			if (!NetQueueGetElement(pQueue, uStart, pElement))
			{
				break;
			}

			pElement++;
			nElements++;
			uStart++;
		}

	} else
	{
		// fetch backward
		while (uStart!=uEnd)
		{
			if (!NetQueueGetElement(pQueue, uEnd, pElement))
			{
				break;
			}

			pElement++;
			nElements++;
			uEnd--;
		}
	}

	return nElements;
}
