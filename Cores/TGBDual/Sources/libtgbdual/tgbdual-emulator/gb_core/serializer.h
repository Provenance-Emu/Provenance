#ifndef __SERIALIZER_H__
#define __SERIALIZER_H__

#include <string.h>

// convenience macros for common uses
#define s_ARRAY(a) s.process((a), sizeof(a))
#define s_VAR(v) s.process(&(v), sizeof(v))

// short and simple serializing to buffer / file / thin air.
// inspired by the much nicer one found in bsnes.
class serializer
{
public:
	enum mode_t { COUNT, SAVE_BUF, LOAD_BUF };
	serializer(void *target, mode_t mode)
	{
		my_mode = mode;
		my_target.ptr = target;
	}
	inline size_t process(void *data, size_t size)
	{
		switch(my_mode) {
			case COUNT:
				my_target.counter[0] += size;
				return size;
			case SAVE_BUF:
				memcpy(my_target.buf, data, size);
				my_target.buf += size;
				return size;
			case LOAD_BUF:
				memcpy(data, my_target.buf, size);
				my_target.buf += size;
				return size;
			default:
				break;
		}
		return 0;
	}
private:
	mode_t my_mode;
	union {
		void *ptr;
		size_t *counter;
		unsigned char *buf;
	} my_target;
};

#endif //__SERIALIZER_H__

