#ifndef _guid_h_
#define _guid_h_

#include <string>
#include "../types.h"
#include "valuearray.h"

struct FCEU_Guid : public ValueArray<uint8,16>
{
	void newGuid();
	std::string toString();
	static FCEU_Guid fromString(std::string str);
	static uint8 hexToByte(char** ptrptr);
	void scan(std::string& str);
};


#endif
