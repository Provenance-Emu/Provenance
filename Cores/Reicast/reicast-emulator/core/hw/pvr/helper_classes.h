#pragma once

template <class T>
struct List
{
	T* daty;
	int avail;

	int size;
	bool* overrun;

	__forceinline int used() const { return size-avail; }
	__forceinline int bytes() const { return used()* sizeof(T); }

	NOINLINE
	T* sig_overrun() 
	{ 
		*overrun |= true;
		Clear();

		return daty;
	}

	__forceinline 
	T* Append(int n=1)
	{
		int ad=avail-n;

		if (ad>=0)
		{
			T* rv=daty;
			daty+=n;
			avail=ad;
			return rv;
		}
		else
			return sig_overrun();
	}

	__forceinline 
	T* LastPtr(int n=1) 
	{ 
		return daty-n; 
	}

	T* head() const { return daty-used(); }

	void InitBytes(int maxbytes,bool* ovrn)
	{
		maxbytes-=maxbytes%sizeof(T);

		daty=(T*)malloc(maxbytes);
		
		verify(daty!=0);

		avail=size=maxbytes/sizeof(T);

		overrun=ovrn;

		Clear();
	}

	void Init(int maxsize,bool* ovrn)
	{
		InitBytes(maxsize*sizeof(T),ovrn);
	}

	void Clear()
	{
		daty=head();
		avail=size;
	}

	void Free()
	{
		Clear();
		free(daty);
	}
};