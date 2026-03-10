// By right, input and output pointers must be all quad-word aligned. Unfortunately, some stuff that Picodrive passes to these functions aren't aligned to that degree. And so, only double-word alignment is required.
void do_pal_convert(unsigned short *dest, const unsigned short *src);
void do_pal_convert_with_shadows(unsigned short *dest, const unsigned short *src);
