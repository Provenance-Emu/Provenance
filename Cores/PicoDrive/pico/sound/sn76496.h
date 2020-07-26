#ifndef SN76496_H
#define SN76496_H

void SN76496Write(int data);
void SN76496Update(short *buffer,int length,int stereo);
int  SN76496_init(int clock,int sample_rate);

#endif
