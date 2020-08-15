//this code is sloppily ripped from an unfinished sound system written for internal use by m.gambrell
//it is released into the public domain and its stability is not warranted


#define _USE_MATH_DEFINES
#include <math.h>
#include <stdlib.h>
#include <map>
#include <stack>
#include <ctype.h>
#include <queue>


const int OAKRA_U8 = 0;
const int OAKRA_S16 = 1;
const int OAKRA_S32 = 2;

const int OAKRA_STATUS_STOPPED = 0;
const int OAKRA_STATUS_PLAYING = 1;

struct OAKRA_Format {
	int channels, format, rate, size;
};

//implements an easy to use, bland callback
template <typename T> struct OAKRA_Callback {
	OAKRA_Callback() { func = 0; param = 0; }
	T operator()() { if(func) return func(param); }
	T (*func)(void *param);
	void *param;
};
template <typename T, typename TARG> struct OAKRA_ArgumentCallback {
	OAKRA_ArgumentCallback() { func = 0; param = 0; }
	T operator()(TARG arg) { if(func) return func(param,arg); }
	T (*func)(void *param, TARG arg);
	void *param;
};

class OAKRA_Module {
public:
	virtual int generate(int samples, void *buf) { return 0; }

	int adapt_to_2S16(int samples, void *buf, OAKRA_Format &sourceFormat) {
		short *sbuf = (short *)buf;
		unsigned char *bbuf = (unsigned char *)buf;
		if(sourceFormat.format == OAKRA_S16) {
			if(sourceFormat.channels == 2) return samples;
			for(int i=samples-1,j=samples*2-2;i>=0;i--,j-=2)
				sbuf[j] = sbuf[j+1] = sbuf[i];
		} else {
			if(sourceFormat.channels == 1)
				for(int i=samples-1,j=samples*2-2;i>=0;i--,j-=2)
					sbuf[j] = sbuf[j+1] = ((int)bbuf[i]-128)<<8;
			else
				for(int j=samples*2-2;j>=0;j--)
					sbuf[j] = sbuf[j+1] = ((int)bbuf[j]-128)<<8;
		}
		return samples;
	}

	//trashes some samples using the buffer provided
	void trash(int samples, void *buf, int bufsamples) {
		while(samples) {
			int todo = std::min(samples,bufsamples);
			generate(todo,buf);
			samples -= todo;
		}
	}

	static int calcSize(OAKRA_Format &format) {
		int size = format.channels;
		if(format.format == OAKRA_S16) size *= 2;
		return size;
	}

	static int getFormatShift(OAKRA_Format &format) {
		if(format.size==1) return 0;
		else if(format.size==2) return 1;
		else if(format.size==4) return 2;
		return -1; //try and crash!
	}

	static void *malloc(int len) { 
		void *ptr = ::malloc(len);
		return ptr;
	}
	void *malloc(int sampsize, int len) { return malloc(sampsize*len); }
	void *malloc(int sampsize, int channels, int len) { return malloc(sampsize*len*channels); }
	void *realloc(void *ptr, int len) {
		ptr = ::realloc(ptr,len);
		return ptr;
	}
	void free(void *ptr) {
		::free(ptr);
	}
	

	static int generateNoise(int samples, void *buf, int sampleSize) {
		for(int i=0;i<samples;i++)
			for(int j=0;j<sampleSize;j++)
				((char *)buf)[i*sampleSize+j] = rand();
		return samples;
	}

	static int generateSilence(int samples, void *buf, int sampleSize) {
		int n = sampleSize*samples;
		memset(buf,0,n);
		return samples;
	}

	static int generateSilence(int samples, void *buf, OAKRA_Format &format) {
		int n = format.size*samples;
		memset(buf,0,n);
		return samples;
	}


	template<typename T>
	T *malloc() {
		return (T *)malloc(sizeof(T));
	}
	template<typename T>
	T *malloc(int amt) {
		return (T *)malloc(sizeof(T)*amt);
	}
	template<typename T>
	T **nmalloc(int number) {
		return (T **)malloc(sizeof(T)*number);
	}
};

class OAKRA_IQueryFormat {
public:
	virtual OAKRA_Format &queryFormat() = 0;
};

//this is basically a filter class
//one source, one sink
class OAKRA_BasicModule : public OAKRA_Module {
public:
	OAKRA_Module *source, *sink;
	OAKRA_BasicModule() { source = sink = 0; }
};

class OAKRA_Voice : public OAKRA_BasicModule {
public:
	OAKRA_Voice() { dead = false; }
	virtual ~OAKRA_Voice() { }
	virtual void setPan(int pan) = 0;
	virtual int getPan() =0;
	virtual void setVol(int vol) = 0;
	virtual int getVol()=0;
	virtual void setSource(OAKRA_Module *source) = 0;
	
	virtual void volFade(int start, int end, int ms)=0;

	//call this when youre in the middle of rendering the voice, but have decided to quit
	//the driver will then trash the voice as soon as it gets the chance.
	//you dont have to have the driver locked to call it. that would be illogical,
	//as the driver is currently locked while it is rendering!
	virtual void die() {
		dead = true;
	}

	//indicates whether a voice is dead
	bool dead;

	//callback fired when a voice dies
	OAKRA_Callback<void> callbackDied;
};


class OAKRA_OutputDriver : public OAKRA_BasicModule {
public:
	virtual ~OAKRA_OutputDriver() {} ;
    virtual OAKRA_Voice *getVoice(OAKRA_Format &format) = 0;
	virtual OAKRA_Voice *getVoice(OAKRA_Format &format, OAKRA_Module *source) = 0;

	//this should be safe to call from within a driver callback. in general, nothing else will be.
	//even if you dont delete the voice (if youre recycling it) you should clear out the source asap
	virtual void freeVoice(OAKRA_Voice *voice) = 0;

	virtual void lock() = 0;
	virtual void unlock() = 0;
};


class OAKRA_Module_OutputDS : public OAKRA_OutputDriver {
	
	void *threadData;
	void *data;

public:

	OAKRA_Module_OutputDS();
	~OAKRA_Module_OutputDS();
	OAKRA_Voice *getVoice(OAKRA_Format &format);
	OAKRA_Voice *getVoice(OAKRA_Format &format, OAKRA_Module *source);
	void freeVoice(OAKRA_Voice *voice);
	void freeVoiceInternal(OAKRA_Voice *voice, bool internal);
	void start(void *hwnd);
	void update();
	void beginThread();
	void endThread();
	void lock();
	void unlock();
};
