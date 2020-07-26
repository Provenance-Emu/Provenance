/*
 * some code for sample mixing
 * (C) notaz, 2006,2007
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#define MAXOUT		(+32767)
#define MINOUT		(-32768)

/* limitter */
#define Limit(val, max,min) { \
	if ( val > max )      val = max; \
	else if ( val < min ) val = min; \
}


void mix_32_to_16l_stereo(short *dest, int *src, int count)
{
	int l, r;

	for (; count > 0; count--)
	{
		l = r = *dest;
		l += *src++;
		r += *src++;
		Limit( l, MAXOUT, MINOUT );
		Limit( r, MAXOUT, MINOUT );
		*dest++ = l;
		*dest++ = r;
	}
}


void mix_32_to_16_mono(short *dest, int *src, int count)
{
	int l;

	for (; count > 0; count--)
	{
		l = *dest;
		l += *src++;
		Limit( l, MAXOUT, MINOUT );
		*dest++ = l;
	}
}


void mix_16h_to_32(int *dest_buf, short *mp3_buf, int count)
{
	while (count--)
	{
		*dest_buf++ += *mp3_buf++ >> 1;
	}
}

void mix_16h_to_32_s1(int *dest_buf, short *mp3_buf, int count)
{
	count >>= 1;
	while (count--)
	{
		*dest_buf++ += *mp3_buf++ >> 1;
		*dest_buf++ += *mp3_buf++ >> 1;
		mp3_buf += 1*2;
	}
}

void mix_16h_to_32_s2(int *dest_buf, short *mp3_buf, int count)
{
	count >>= 1;
	while (count--)
	{
		*dest_buf++ += *mp3_buf++ >> 1;
		*dest_buf++ += *mp3_buf++ >> 1;
		mp3_buf += 3*2;
	}
}

