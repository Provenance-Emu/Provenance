

#ifndef _EMUTHREAD_H
#define _EMUTHREAD_H



enum EmuThreadCounterE
{
	EMUTHREAD_COUNTER_TOTAL,
	EMUTHREAD_COUNTER_FRAME,
	EMUTHREAD_COUNTER_LINE,
	EMUTHREAD_COUNTER_USER0,

	EMUTHREAD_COUNTER_NUM
};


class CEmuThread
{
protected:
	Int32				m_Cycles;								// cycle counter for current execution
	Int32				m_Counter[EMUTHREAD_COUNTER_NUM];		// counter(s)
	void				*m_pUserData;							// user data pointer

public:
	CEmuThread()
	{
		ResetCounters();
		m_pUserData = NULL;
	}

	void	ResetCounters()
	{
		// reset all counters
		m_Cycles = 0;
		m_Counter[0] = 0;
		m_Counter[1] = 0;
		m_Counter[2] = 0;
		m_Counter[3] = 0;
	}

	inline void AdvanceCycles(Int32 nCycles)
	{
		m_Cycles += nCycles;
		m_Counter[0] += nCycles;
		m_Counter[1] += nCycles;
		m_Counter[2] += nCycles;
		m_Counter[3] += nCycles;
	}

	inline void	ResetCounter(EmuThreadCounterE eCounter) 
	{
		m_Counter[eCounter] = 0;
	}

	inline Int32	GetCounter(EmuThreadCounterE eCounter)
	{
		return m_Counter[eCounter] - m_Cycles;
	}
};

#endif