#include <string>
#include <fstream>
#include <iostream>
#include <vector>

#include <initguid.h>
#include <ObjBase.h>
#include <OleAuto.h>

#include "7zip/IArchive.h"
#include "file.h"
#include "utils/guid.h"

#include "driver.h"
#include "main.h"

//todo - we need a way to get a non-readable filepointer, just for probing the archive
//it would be nonreadable because we wouldnt actually decompress the contents

static FCEUARCHIVEFILEINFO *currFileSelectorContext;

DEFINE_GUID(CLSID_CFormat_07,0x23170F69,0x40C1,0x278A,0x10,0x00,0x00,0x01,0x10,0x07,0x00,0x00);

class OutStream : public IArchiveExtractCallback
{
	class SeqStream : public ISequentialOutStream
	{
		EMUFILE_MEMORY* ms;
		ULONG refCount;

		HRESULT STDMETHODCALLTYPE QueryInterface(REFGUID,void**)
		{
			return E_NOINTERFACE;
		}

		HRESULT STDMETHODCALLTYPE Write(const void* data,UInt32 length,UInt32* save)
		{
			if (data != NULL)
			{
				//NST_VERIFY( length <= size - pos );

				ms->fwrite(data,length);
				if(save) *save = length;

				return S_OK;
			}
			else
			{
				return E_INVALIDARG;
			}
		}

		ULONG STDMETHODCALLTYPE AddRef()
		{
			return ++refCount;
		}

		ULONG STDMETHODCALLTYPE Release()
		{
			return --refCount;
		}

	public:

		SeqStream(EMUFILE_MEMORY* dest,uint32 s)
		: ms(dest)
		, refCount(0) {}

		uint32 Size() const
		{
			return ms->size();
		}
	};

	SeqStream seqStream;
	const uint32 index;
	ULONG refCount;

	HRESULT STDMETHODCALLTYPE QueryInterface(REFGUID,void**)
	{
		return E_NOINTERFACE;
	}

	HRESULT STDMETHODCALLTYPE PrepareOperation(Int32)
	{
		return S_OK;
	}

	HRESULT STDMETHODCALLTYPE SetTotal(UInt64)
	{
		return S_OK;
	}

	HRESULT STDMETHODCALLTYPE SetCompleted(const UInt64*)
	{
		return S_OK;
	}

	HRESULT STDMETHODCALLTYPE SetOperationResult(Int32)
	{
		return S_OK;
	}

	HRESULT STDMETHODCALLTYPE GetStream(UInt32 id,ISequentialOutStream** ptr,Int32 mode)
	{
		switch (mode)
		{
			case NArchive::NExtract::NAskMode::kExtract:
			case NArchive::NExtract::NAskMode::kTest:

				if (id != index || ptr == NULL)
					return S_FALSE;
				else
					*ptr = &seqStream;

			case NArchive::NExtract::NAskMode::kSkip:
				return S_OK;

			default:
				return E_INVALIDARG;
		}
	}

	ULONG STDMETHODCALLTYPE AddRef()
	{
		return ++refCount;
	}

	ULONG STDMETHODCALLTYPE Release()
	{
		return --refCount;
	}

public:

	OutStream(uint32 index,EMUFILE_MEMORY* data,uint32 size)
	: seqStream(data,size), index(index), refCount(0) {}

	uint32 Size() const
	{
		return seqStream.Size();
	}
};

class InStream : public IInStream, private IStreamGetSize
{
	ULONG refCount;

	HRESULT STDMETHODCALLTYPE QueryInterface(REFGUID,void**)
	{
		return E_NOINTERFACE;
	}

	HRESULT STDMETHODCALLTYPE GetSize(UInt64* save)
	{
		if (save)
		{
			*save = size;
			return S_OK;
		}
		else
		{
			return E_INVALIDARG;
		}
	}

	ULONG STDMETHODCALLTYPE AddRef()
	{
		return ++refCount;
	}

	ULONG STDMETHODCALLTYPE Release()
	{
		return --refCount;
	}

protected:

	uint32 size;

public:

	explicit InStream()
	: refCount(0)
	{}
};


class InFileStream : public InStream
{
public:

	~InFileStream()
	{
		if(inf) delete inf;
	}

	EMUFILE_FILE* inf;

	InFileStream(std::string fname)
	: inf(0)
	{
		inf = FCEUD_UTF8_fstream(fname,"rb");
		if(inf)
		{
			size = inf->size();
			inf->fseek(0,SEEK_SET);
		}
	}

	HRESULT STDMETHODCALLTYPE Read(void* data,UInt32 length,UInt32* save)
	{
		if(!inf) return E_FAIL;

		if (data != NULL || length == 0)
		{
			length = inf->fread((char*)data,length);
			
			//do we need to do 
			//return E_FAIL;

			if (save)
				*save = length;

			return S_OK;
		}
		else
		{
			return E_INVALIDARG;
		}
	}

	HRESULT STDMETHODCALLTYPE Seek(Int64 offset,UInt32 origin,UInt64* pos)
	{
		if(!inf) return E_FAIL;

		if (origin < 3)
		{
			UInt32 offtype;
			switch(origin)
			{
			case 0: offtype = SEEK_SET; break;
			case 1: offtype = SEEK_CUR; break;
			case 2: offtype = SEEK_END; break;
			default:
				return E_INVALIDARG;
			}
			inf->fseek(offset,offtype);
			origin = inf->ftell();

			if (pos)
				*pos = origin;

			return S_OK;
		}
		else
		{
			return E_INVALIDARG;
		}
	
	}
};


class LibRef
{
public:
	HMODULE hmod;
	LibRef(const char* fname) {
		hmod = LoadLibrary(fname);
	}
	~LibRef() {
		if(hmod)
			FreeLibrary(hmod);
	}
};


static BOOL CALLBACK ArchiveFileSelectorCallback(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg)
	{
	case WM_INITDIALOG:
		{
			HWND hwndListbox = GetDlgItem(hwndDlg,IDC_LIST1);
			for(uint32 i=0;i<currFileSelectorContext->size();i++)
			{
				std::string& name = (*currFileSelectorContext)[i].name;
				SendMessage(hwndListbox,LB_ADDSTRING,0,(LPARAM)name.c_str());
			}
		}
		break;

	case WM_COMMAND:
		switch(LOWORD(wParam))
		{
			case IDC_LIST1:
				if(HIWORD(wParam) == LBN_DBLCLK)
				{
					EndDialog(hwndDlg,SendMessage((HWND)lParam,LB_GETCURSEL,0,0));
				}
				return TRUE;

			case IDOK:
				EndDialog(hwndDlg,SendMessage(GetDlgItem(hwndDlg,IDC_LIST1),LB_GETCURSEL,0,0));
				return TRUE;

			case IDCANCEL:
				EndDialog(hwndDlg, LB_ERR);
				return TRUE;
		}
		break;
	}
	return FALSE;
}

typedef UINT32 (WINAPI *CreateObjectFunc)(const GUID*,const GUID*,void**);

struct FormatRecord
{
	std::vector<char> signature;
	GUID guid;
};

typedef std::vector<FormatRecord> TFormatRecords;
TFormatRecords formatRecords;
static bool archiveSystemInitialized=false;
static LibRef libref("7z.dll");

void initArchiveSystem()
{
	if(!libref.hmod)
	{
		//couldnt initialize archive system
		return;
	}

	typedef HRESULT (WINAPI *GetNumberOfFormatsFunc)(UINT32 *numFormats);
	typedef HRESULT (WINAPI *GetHandlerProperty2Func)(UInt32 formatIndex, PROPID propID, PROPVARIANT *value);

	GetNumberOfFormatsFunc GetNumberOfFormats = (GetNumberOfFormatsFunc)GetProcAddress(libref.hmod,"GetNumberOfFormats");
	GetHandlerProperty2Func GetHandlerProperty2 = (GetHandlerProperty2Func)GetProcAddress(libref.hmod,"GetHandlerProperty2");

	if(!GetNumberOfFormats || !GetHandlerProperty2)
	{
		//not the right dll.
		return;
	}

	//looks like it is gonna be OK
	archiveSystemInitialized = true;

	UINT32 numFormats;
	GetNumberOfFormats(&numFormats);

	for(uint32 i=0;i<numFormats;i++)
	{
		PROPVARIANT prop;
		prop.vt = VT_EMPTY;

		GetHandlerProperty2(i,NArchive::kStartSignature,&prop);
		
		FormatRecord fr;
		int len = SysStringLen(prop.bstrVal);
		fr.signature.reserve(len);
		for(int j=0;j<len;j++)
			fr.signature.push_back(((char*)prop.bstrVal)[j]);

		GetHandlerProperty2(i,NArchive::kClassID,&prop);
		memcpy((char*)&fr.guid,(char*)prop.bstrVal,16);

		formatRecords.push_back(fr);

		::VariantClear( reinterpret_cast<VARIANTARG*>(&prop) );
	}
}

static std::string wstringFromPROPVARIANT(BSTR bstr, bool& success) {
	std::wstring tempfname = bstr;
	int buflen = tempfname.size()*2;
	char* buf = new char[buflen];
	int ret = WideCharToMultiByte(CP_ACP,0,tempfname.c_str(),tempfname.size(),buf,buflen,0,0);
	if(ret == 0) {
		delete[] buf;
		success = false;
	}
	buf[ret] = 0;
	std::string strret = buf;
	delete[] buf;
	success = true;
	return strret;
}

ArchiveScanRecord FCEUD_ScanArchive(std::string fname)
{
	if(!archiveSystemInitialized)
	{
		return ArchiveScanRecord();
	}

	//check the file against the signatures
	EMUFILE* inf = FCEUD_UTF8_fstream(fname,"rb");
	if(!inf) return ArchiveScanRecord();

	int matchingFormat = -1;
	for(uint32 i=0;i<(int)formatRecords.size();i++)
	{
		inf->fseek(0,SEEK_SET);
		int size = formatRecords[i].signature.size();
		if(size==0)
			continue; //WHY??
		char* temp = new char[size];
		inf->fread((char*)temp,size);
		if(!memcmp(&formatRecords[i].signature[0],temp,size))
		{
			delete[] temp;
			matchingFormat = i;
			break;
		}
		delete[] temp;
	}
	delete inf;

	if(matchingFormat == -1)
		return ArchiveScanRecord();

	CreateObjectFunc CreateObject = (CreateObjectFunc)GetProcAddress(libref.hmod,"CreateObject");
	if(!CreateObject)
		return ArchiveScanRecord();
	IInArchive* object;
	if (!FAILED(CreateObject( &formatRecords[matchingFormat].guid, &IID_IInArchive, (void**)&object )))
	{
		//fetch the start signature
		InFileStream ifs(fname);
		if (SUCCEEDED(object->Open(&ifs,0,0)))
		{
			uint32 numFiles;

			if (SUCCEEDED(object->GetNumberOfItems(&numFiles)))
			{
				// AnS: added this check, because new 7z confuses FDS files with archives (it recognizes the first "F" as a signature of an archive)
				if (numFiles == 0)
					goto bomb;

				ArchiveScanRecord asr(matchingFormat,(int)numFiles);

				//scan the filename of each item
				for(uint32 i=0;i<numFiles;i++)
				{
					FCEUARCHIVEFILEINFO_ITEM item;
					item.index = i;

					PROPVARIANT prop;
					prop.vt = VT_EMPTY;

					if (FAILED(object->GetProperty( i, kpidSize, &prop )) || prop.vt != VT_UI8 /*|| !prop.uhVal.LowPart*/ || prop.uhVal.HighPart)
						goto bomb;

					item.size = prop.uhVal.LowPart;

					if (FAILED(object->GetProperty( i, kpidPath, &prop )) || prop.vt != VT_BSTR || prop.bstrVal == NULL)
						goto bomb;

					bool ok;
					item.name = wstringFromPROPVARIANT(prop.bstrVal,ok);
					::VariantClear( reinterpret_cast<VARIANTARG*>(&prop) );
					
					if(!ok)
						continue;

					asr.files.push_back(item);
				}
				
				object->Release();
				return asr;
			}
		}
	}

bomb:
	object->Release();

	return ArchiveScanRecord();
}

extern HWND hAppWnd;

//TODO - factor out the filesize and name extraction code from below (it is already done once above)

static FCEUFILE* FCEUD_OpenArchive(ArchiveScanRecord& asr, std::string& fname, std::string* innerFilename, int innerIndex)
{
	FCEUFILE* fp = 0;
	
	if(!archiveSystemInitialized) {
		MessageBox(hAppWnd,"Could not locate 7z.dll","Failure launching archive browser",0);
		return 0;
	}

	typedef UINT32 (WINAPI *CreateObjectFunc)(const GUID*,const GUID*,void**);
	CreateObjectFunc CreateObject = (CreateObjectFunc)GetProcAddress(libref.hmod,"CreateObject");
	if(!CreateObject)
	{
		MessageBox(hAppWnd,"7z.dll was invalid","Failure launching archive browser",0);
		return 0;
	}


	bool unnamedFileFound = false;
	IInArchive* object;
	if (!FAILED(CreateObject( &formatRecords[asr.type].guid, &IID_IInArchive, (void**)&object )))
	{
		InFileStream ifs(fname);
		if (SUCCEEDED(object->Open(&ifs,0,0)))
		{
			uint32 numfiles = asr.numFilesInArchive;
			currFileSelectorContext = &asr.files;

			//try to load the file directly if we're in autopilot
			int ret = LB_ERR;
			if(innerFilename || innerIndex != -1)
			{
				for(uint32 i=0;i<currFileSelectorContext->size();i++)
					if(i == (uint32)innerIndex || (innerFilename && (*currFileSelectorContext)[i].name == *innerFilename))
					{
						ret = i;
						break;
					}
			}
			else if(asr.files.size()==1)
				//or automatically choose the first file if there was only one file in the archive
				ret = 0;
			else
				//otherwise use the UI
				ret = DialogBoxParam(fceu_hInstance, "ARCHIVECHOOSERDIALOG", hAppWnd, ArchiveFileSelectorCallback, (LPARAM)0);

			if(ret != LB_ERR)
			{
				FCEUARCHIVEFILEINFO_ITEM& item = (*currFileSelectorContext)[ret];
				EMUFILE_MEMORY* ms = new EMUFILE_MEMORY(item.size);
				OutStream outStream( item.index, ms, item.size);
				const uint32 indices[1] = {item.index};
				HRESULT hr = object->Extract(indices,1,0,&outStream);
				if (SUCCEEDED(hr))
				{
					//if we extracted the file correctly
					fp = new FCEUFILE();
					fp->archiveFilename = fname;
					fp->filename = item.name;
					fp->fullFilename = fp->archiveFilename + "|" + fp->filename;
					fp->archiveIndex = ret;
					fp->mode = FCEUFILE::READ;
					fp->size = item.size;
					fp->stream = ms;
					fp->archiveCount = (int)asr.numFilesInArchive;
					ms->fseek(0,SEEK_SET); //rewind so that the rom analyzer sees a freshly opened file
				} 
				else
				{
					delete ms;
				}

			} //if returned a file from the fileselector
			
		} //if we opened the 7z correctly
		object->Release();
	}

	return fp;
}

FCEUFILE* FCEUD_OpenArchiveIndex(ArchiveScanRecord& asr, std::string& fname, int innerIndex)
{
	return FCEUD_OpenArchive(asr, fname, 0, innerIndex);
}

FCEUFILE* FCEUD_OpenArchive(ArchiveScanRecord& asr, std::string& fname, std::string* innerFilename)
{
	return FCEUD_OpenArchive(asr, fname, innerFilename, -1);
}