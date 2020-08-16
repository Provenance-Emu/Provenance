//this code is sloppily ripped from an unfinished sound system written for internal use by m.gambrell
//it is released into the public domain and its stability is not warranted

#include "oakra.h"

#include "dsound.h"
#include <vector>

#define LATENCY_MS (100)



class DSVoice : public OAKRA_Voice {
public:
	OAKRA_Module_OutputDS *driver;
	OAKRA_Format format;
	int formatShift;
	IDirectSoundBuffer *ds_buf;
	int buflen;
	unsigned int cPlay;
	int vol,pan;

	virtual void setPan(int pan) {
		//removed for FCEU
	}
	virtual void setVol(int vol) {
		//removed for FCEU
	}
	virtual int getVol() { return vol; }
	virtual int getPan() { return pan; }
	void setSource(OAKRA_Module *source) {
		this->source = source;
	}
	virtual ~DSVoice() {
		driver->freeVoiceInternal(this,true);
		if(ds_buf)
			ds_buf->Release();
	}
	DSVoice(OAKRA_Module_OutputDS *driver, OAKRA_Format &format, IDirectSound *ds_dev, bool global) 
		: ds_buf(0)
	{ 
		this->driver = driver;
		vol = 255;
		pan = 0;
		source = 0;
		this->format = format;
		formatShift = getFormatShift(format);
		buflen = (format.rate * LATENCY_MS / 1000);

		WAVEFORMATEX wfx;
		memset(&wfx, 0, sizeof(wfx));
		wfx.wFormatTag      = WAVE_FORMAT_PCM;
		wfx.nChannels       = format.channels;
		wfx.nSamplesPerSec  = format.rate;
		wfx.nAvgBytesPerSec = format.rate * format.size;
		wfx.nBlockAlign     = format.size;
		wfx.wBitsPerSample  = (format.format==OAKRA_S16?16:8);
		wfx.cbSize          = sizeof(wfx);

		DSBUFFERDESC dsbd;
		memset(&dsbd, 0, sizeof(dsbd));
		dsbd.dwSize        = sizeof(dsbd);
		//commented out for FCEU
		dsbd.dwFlags       = DSBCAPS_GETCURRENTPOSITION2;// | DSBCAPS_LOCSOFTWARE | DSBCAPS_CTRLVOLUME ;
		if(global) dsbd.dwFlags |= DSBCAPS_GLOBALFOCUS ;
		dsbd.dwBufferBytes = buflen  * format.size;
		dsbd.lpwfxFormat   = &wfx;
		
		HRESULT hr = ds_dev->CreateSoundBuffer(&dsbd,&ds_buf,0);
		cPlay = 0;

		if(!hr)
		{
			hr = ds_buf->Play(0,0,DSBPLAY_LOOPING);
		}

		//if we couldnt create the voice, then a sound card is missing.
		//we'll use this in getVoice to catch the condition
		if(hr)
			dead = true;
	}
	
	//not supported
	virtual void volFade(int start, int end, int ms) {}

	void update() {
	    DWORD play, write;
		HRESULT hr = ds_buf->GetCurrentPosition(&play, &write);
		play >>= formatShift;
		write >>= formatShift;
		
		int todo;
		if(play<cPlay) todo = play + buflen - cPlay;
		else todo = play - cPlay;

		if(!todo) return;
		

		void* buffer1;
		void* buffer2;
		DWORD buffer1_length;
		DWORD buffer2_length;
		hr = ds_buf->Lock(
			cPlay<<formatShift,todo<<formatShift,
			&buffer1, &buffer1_length,
			&buffer2, &buffer2_length,0
			);

		buffer1_length >>= formatShift;
		buffer2_length >>= formatShift;
		int done = 0;
		if(source) {
			done = source->generate(buffer1_length,buffer1);
			if(done != buffer1_length) {
				generateSilence(buffer1_length - done,(char *)buffer1 + (done<<formatShift),format.size);
				generateSilence(buffer2_length,buffer2,format.size);
				die();
			} else {
				if(buffer2_length) {
					done = source->generate(buffer2_length,buffer2);
					if(done != buffer2_length) {
						generateSilence(buffer2_length - done,(char *)buffer2 + (done<<formatShift),format.size);
						die();
					}
				}
			}
		}

		ds_buf->Unlock(
			buffer1, buffer1_length,
			buffer2, buffer2_length);

		cPlay = play;
	}
};

class Data {
public:
	bool global;
	IDirectSound* ds_dev;
	std::vector<DSVoice *> voices;
	CRITICAL_SECTION criticalSection;
};


class ThreadData {
public:
	ThreadData() { kill = dead = false; }
	OAKRA_Module_OutputDS *ds;
	bool kill,dead;
};

OAKRA_Module_OutputDS::OAKRA_Module_OutputDS() {
	data = new Data();
	((Data *)data)->global = false;
	InitializeCriticalSection(&((Data *)data)->criticalSection);
}

OAKRA_Module_OutputDS::~OAKRA_Module_OutputDS() {
	//ask the driver to shutdown, and wait for it to do so
	((ThreadData *)threadData)->kill = true;
	while(!((ThreadData *)threadData)->dead) Sleep(1);

	////kill all the voices
	std::vector<DSVoice *> voicesCopy = ((Data *)data)->voices;
	int voices = (int)voicesCopy.size();
	for(int i=0;i<voices;i++)
		delete voicesCopy[i];

	////free other resources
	DeleteCriticalSection(&((Data *)data)->criticalSection);
	((Data *)data)->ds_dev->Release();
	delete (Data *)data;
	delete (ThreadData *)threadData;
}

OAKRA_Voice *OAKRA_Module_OutputDS::getVoice(OAKRA_Format &format, OAKRA_Module *source) {
	DSVoice *dsv = (DSVoice *)getVoice(format);
	if(dsv->dead)
	{
		delete dsv;
	}
	else
	{
		dsv->setSource(source);
	}
	return dsv;
}

OAKRA_Voice *OAKRA_Module_OutputDS::getVoice(OAKRA_Format &format) {
	DSVoice *voice = new DSVoice(this,format,((Data *)data)->ds_dev,((Data *)data)->global);
	if(voice->dead)
	{
		delete voice;
		voice = 0;
	} else
	{
		((Data *)data)->voices.push_back(voice);
	}
	return voice;
}
void OAKRA_Module_OutputDS::freeVoice(OAKRA_Voice *voice) {
	freeVoiceInternal(voice,false);
}

void OAKRA_Module_OutputDS::freeVoiceInternal(OAKRA_Voice *voice, bool internal) {
	lock();
	Data *data = (Data *)this->data;
	int j = -1;
	for(int i=0;i<(int)data->voices.size();i++)
		if(data->voices[i] == voice) j = i;
	if(j!=-1)
		data->voices.erase(data->voices.begin()+j);
	if(!internal)
	{
		delete voice;
		voice = 0;
	}
	unlock();
}



void OAKRA_Module_OutputDS::start(void *hwnd) {
	HRESULT hr = CoInitialize(NULL);
	IDirectSound* ds_dev;
	hr = CoCreateInstance(CLSID_DirectSound,0,CLSCTX_INPROC_SERVER,IID_IDirectSound,(void**)&ds_dev);
	
	if(!hwnd) {
		hwnd = GetDesktopWindow();
		((Data *)data)->global = true;
	}
	
	//use default device
	hr = ds_dev->Initialize(0); 
	hr = ds_dev->SetCooperativeLevel((HWND)hwnd, DSSCL_NORMAL);

	((Data *)data)->ds_dev = ds_dev;
}


DWORD WINAPI updateProc(LPVOID lpParameter) {
	ThreadData *data = (ThreadData *)lpParameter;
	for(;;) {
		if(data->kill) break;
		data->ds->update();
		Sleep(1);
	}
	data->dead = true;
	return 0;
}

void OAKRA_Module_OutputDS::beginThread() {
	DWORD updateThreadId;
	threadData = new ThreadData();
	((ThreadData *)threadData)->ds = this;
	HANDLE updateThread = CreateThread(0,0,updateProc,threadData,0,&updateThreadId);
	SetThreadAffinityMask(updateThread,1);
	SetThreadPriority(updateThread,THREAD_PRIORITY_TIME_CRITICAL);
	//SetThreadPriority(updateThread,THREAD_PRIORITY_HIGHEST);
}

void OAKRA_Module_OutputDS::endThread() {
	((ThreadData *)threadData)->kill = true;
}

void OAKRA_Module_OutputDS::update() {
	lock();
	int voices = (int)((Data *)data)->voices.size();

	//render all the voices
	for(int i=0;i<voices;i++)
		((Data *)data)->voices[i]->update();

	//look for voices that are dead
	std::vector<DSVoice *> deaders;
	for(int i=0;i<voices;i++)
		if(((Data *)data)->voices[i]->dead)
			deaders.push_back(((Data *)data)->voices[i]);

	//unlock the driver before killing voices!
	//that way, the voice's death callback won't occur within the driver lock
	unlock();

	// kill those voices
	if (deaders.size())
	{
		for (int i = 0; i < (int)deaders.size(); i++)
		{
			deaders[i]->callbackDied();
			freeVoice(deaders[i]);
		}
	}
}

void OAKRA_Module_OutputDS::lock() {
	EnterCriticalSection(  &((Data *)this->data)->criticalSection );
}

void OAKRA_Module_OutputDS::unlock() {
	LeaveCriticalSection(  &((Data *)this->data)->criticalSection );
}

