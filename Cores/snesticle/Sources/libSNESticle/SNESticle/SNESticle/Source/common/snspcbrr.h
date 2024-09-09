

#ifndef _SNSPCBRR_H
#define _SNSPCBRR_H



typedef struct SNSpcBRRBlock_t
{
	Uint8	header;
	Int8	data[8];
} SNSpcBRRBlockT;


Uint8 SNSpcBRRDecode(Uint8 *pBRRBlock, Int16 *pOut, Int32 iPrev0, Int32 iPrev1);
void SNSpcBRRClear(Int16 *pOut, Int16 iPrev);


#endif
