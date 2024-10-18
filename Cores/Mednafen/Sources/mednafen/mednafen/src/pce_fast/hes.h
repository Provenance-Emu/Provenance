namespace MDFN_IEN_PCE_FAST
{

uint8 ReadIBP(unsigned int A);
void HES_Draw(MDFN_Surface *surface, MDFN_Rect *DisplayRect, int16 *samples, int32 sampcount);

void HES_Load(Stream* fp) MDFN_COLD;
void HES_Reset(void) MDFN_COLD;
void HES_Close(void) MDFN_COLD;

};
