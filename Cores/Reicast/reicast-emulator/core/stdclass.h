#pragma once
#include "types.h"
#include <stdlib.h>
#include <vector>
#include <string.h>

#if HOST_OS!=OS_WINDOWS
#include <pthread.h>
#else
#include <Windows.h>
#endif


#ifdef _ANDROID
#include <sys/mman.h>
#undef PAGE_MASK
#define PAGE_MASK (PAGE_SIZE-1)
#else
#ifdef __LP64__
#define PAGE_SIZE 16384
#else
#define PAGE_SIZE 4096
#endif
#define PAGE_MASK (PAGE_SIZE-1)
#endif

//Commonly used classes across the project
//Simple Array class for helping me out ;P
template<class T>
class Array
{
public:
	T* data;
	u32 Size;

	Array(T* Source,u32 ellements)
	{
		//initialise array
		data=Source;
		Size=ellements;
	}

	Array(u32 ellements)
	{
		//initialise array
		data=0;
		Resize(ellements,false);
		Size=ellements;
	}

	Array(u32 ellements,bool zero)
	{
		//initialise array
		data=0;
		Resize(ellements,zero);
		Size=ellements;
	}

	Array()
	{
		//initialise array
		data=0;
		Size=0;
	}

	~Array()
	{
		if  (data)
		{
			#ifdef MEM_ALLOC_TRACE
			printf("WARNING : DESTRUCTOR WITH NON FREED ARRAY [arrayid:%d]\n",id);
			#endif
			Free();
		}
	}

	void SetPtr(T* Source,u32 ellements)
	{
		//initialise array
		Free();
		data=Source;
		Size=ellements;
	}

	T* Resize(u32 size,bool bZero)
	{
		if (size==0)
		{
			if (data)
			{
				#ifdef MEM_ALLOC_TRACE
				printf("Freeing data -> resize to zero[Array:%d]\n",id);
				#endif
				Free();
			}

		}
		
		if (!data)
			data=(T*)malloc(size*sizeof(T));
		else
			data=(T*)realloc(data,size*sizeof(T));

		//TODO : Optimise this
		//if we allocated more , Zero it out
		if (bZero)
		{
			if (size>Size)
			{
				for (u32 i=Size;i<size;i++)
				{
					u8*p =(u8*)&data[i];
					for (size_t j=0;j<sizeof(T);j++)
					{
						p[j]=0;
					}
				}
			}
		}
		Size=size;

		return data;
	}

	void Zero()
	{
		memset(data,0,sizeof(T)*Size);
	}

	void Free()
	{
		if (Size != 0)
		{
			if (data)
				free(data);

			data = NULL;
		}
	}


	INLINE T& operator [](const u32 i)
	{
#ifdef MEM_BOUND_CHECK
		if (i>=Size)
		{
			printf("Error: Array %d , index out of range (%d>%d)\n",id,i,Size-1);
			MEM_DO_BREAK;
		}
#endif
		return data[i];
	}

	INLINE T& operator [](const s32 i)
	{
#ifdef MEM_BOUND_CHECK
		if (!(i>=0 && i<(s32)Size))
		{
			printf("Error: Array %d , index out of range (%d > %d)\n",id,i,Size-1);
			MEM_DO_BREAK;
		}
#endif
		return data[i];
	}
};

//Windoze code
//Threads

#if !defined(HOST_NO_THREADS)
typedef  void* ThreadEntryFP(void* param);

typedef void* THREADHANDLE;

class cThread
{
private:
	ThreadEntryFP* Entry;
	void* param;
public :
	THREADHANDLE hThread;
	cThread(ThreadEntryFP* function,void* param);
	
	void Start();
	void WaitToEnd();
};
#endif
//Wait Events
typedef void* EVENTHANDLE;
class cResetEvent
{

private:
#if HOST_OS==OS_WINDOWS
	EVENTHANDLE hEvent;
#else
	pthread_mutex_t mutx;
	pthread_cond_t cond;

#endif

public :
	bool state;
	cResetEvent(bool State,bool Auto);
	~cResetEvent();
	void Set();		//Set state to signaled
	void Reset();	//Set state to non signaled
	void Wait(u32 msec);//Wait for signal , then reset[if auto]
	void Wait();	//Wait for signal , then reset[if auto]
};

class cMutex
{
private:
#if HOST_OS==OS_WINDOWS
	CRITICAL_SECTION cs;
#else
	pthread_mutex_t mutx;
#endif

public :
	bool state;
	cMutex()
	{
#if HOST_OS==OS_WINDOWS
		InitializeCriticalSection(&cs);
#else
		pthread_mutex_init ( &mutx, NULL);
#endif
	}
	~cMutex()
	{
#if HOST_OS==OS_WINDOWS
		DeleteCriticalSection(&cs);
#else
		pthread_mutex_destroy(&mutx);
#endif
	}
	void Lock()
	{
#if HOST_OS==OS_WINDOWS
		EnterCriticalSection(&cs);
#else
		pthread_mutex_lock(&mutx);
#endif
	}
	void Unlock()
	{
#if HOST_OS==OS_WINDOWS
		LeaveCriticalSection(&cs);
#else
		pthread_mutex_unlock(&mutx);
#endif
	}
};

//Set the path !
void set_user_config_dir(const string& dir);
void set_user_data_dir(const string& dir);
void add_system_config_dir(const string& dir);
void add_system_data_dir(const string& dir);

//subpath format: /data/fsca-table.bit
string get_writable_config_path(const string& filename);
string get_writable_data_path(const string& filename);
string get_readonly_config_path(const string& filename);
string get_readonly_data_path(const string& filename);
bool file_exists(const string& filename);


class VArray2
{
public:

	u8* data;
	u32 size;
	//void Init(void* data,u32 sz);
	//void Term();
	void LockRegion(u32 offset,u32 size);
	void UnLockRegion(u32 offset,u32 size);

	void Zero()
	{
		UnLockRegion(0,size);
		memset(data,0,size);
	}

	INLINE u8& operator [](const u32 i)
    {
#ifdef MEM_BOUND_CHECK
        if (i>=size)
		{
			printf("Error: VArray2 , index out of range (%d>%d)\n",i,size-1);
			MEM_DO_BREAK;
		}
#endif
		return data[i];
    }
};

int ExeptionHandler(u32 dwCode, void* pExceptionPointers);
int msgboxf(const wchar* text,unsigned int type,...);


#define MBX_OK                       0x00000000L
#define MBX_OKCANCEL                 0x00000001L
#define MBX_ABORTRETRYIGNORE         0x00000002L
#define MBX_YESNOCANCEL              0x00000003L
#define MBX_YESNO                    0x00000004L
#define MBX_RETRYCANCEL              0x00000005L


#define MBX_ICONHAND                 0x00000010L
#define MBX_ICONQUESTION             0x00000020L
#define MBX_ICONEXCLAMATION          0x00000030L
#define MBX_ICONASTERISK             0x00000040L


#define MBX_USERICON                 0x00000080L
#define MBX_ICONWARNING              MBX_ICONEXCLAMATION
#define MBX_ICONERROR                MBX_ICONHAND


#define MBX_ICONINFORMATION          MBX_ICONASTERISK
#define MBX_ICONSTOP                 MBX_ICONHAND

#define MBX_DEFBUTTON1               0x00000000L
#define MBX_DEFBUTTON2               0x00000100L
#define MBX_DEFBUTTON3               0x00000200L

#define MBX_DEFBUTTON4               0x00000300L


#define MBX_APPLMODAL                0x00000000L
#define MBX_SYSTEMMODAL              0x00001000L
#define MBX_TASKMODAL                0x00002000L

#define MBX_HELP                     0x00004000L // Help Button


#define MBX_NOFOCUS                  0x00008000L
#define MBX_SETFOREGROUND            0x00010000L
#define MBX_DEFAULT_DESKTOP_ONLY     0x00020000L

#define MBX_TOPMOST                  0x00040000L
#define MBX_RIGHT                    0x00080000L
#define MBX_RTLREADING               0x00100000L

#define MBX_RV_OK                1
#define MBX_RV_CANCEL            2
#define MBX_RV_ABORT             3
#define MBX_RV_RETRY             4
#define MBX_RV_IGNORE            5
#define MBX_RV_YES               6
#define MBX_RV_NO                7
