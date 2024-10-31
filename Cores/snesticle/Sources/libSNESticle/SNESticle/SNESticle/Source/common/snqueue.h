
#ifndef _SNQUEUE_H
#define _SNQUEUE_H

#define SNQUEUE_SIZE (512)

struct SNQueueElementT
{
	Uint32	uCycle;
	Uint16	uAddr;
	Uint8	uData;
	Uint8	uPad;
};

class SNQueue
{
public:
    SNQueue() 
    {
        Reset();
    }

	inline void Reset()
	{
		m_iHead = m_iTail = 0;
	}

	inline Bool IsEmpty()
	{
		return m_iHead == m_iTail;
	}

	inline Bool Enqueue(Uint32 uCycle, Uint32 uAddr, Uint8 uData)
	{
		if (IsEmpty())
		{
			Reset();
		}

		if (m_iTail < SNQUEUE_SIZE)
		{
			SNQueueElementT *pElement = &m_Elements[m_iTail++];

			// enqueue write
			pElement->uCycle = uCycle;
			pElement->uAddr  = uAddr;
			pElement->uData = uData;
			return TRUE;
		} else
		{
			// write cannot be enqueued, buffer full
			return FALSE;
		}
	}

	inline SNQueueElementT	*Dequeue(Uint32 uCycle)
	{
		// dequeue element only if it is earlier than cycle time given
		if (m_iHead < m_iTail && (uCycle > m_Elements[m_iHead].uCycle))
		{
			return &m_Elements[m_iHead++];
		}
		return NULL;
 	}

	inline SNQueueElementT	*Dequeue()
	{
		if (m_iHead < m_iTail)
		{
			return &m_Elements[m_iHead++];
		}
		return NULL;
	}

private:
    Int32			m_iHead;	// current read position within write queue
    Int32			m_iTail;	// current write position within write queue
    SNQueueElementT	m_Elements[SNQUEUE_SIZE];

};

#endif
