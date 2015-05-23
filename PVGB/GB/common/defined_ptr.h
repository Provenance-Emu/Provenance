#ifndef DEFINED_PTR_H
#define DEFINED_PTR_H

template<class T>
inline T * defined_ptr(T *t) {
	typedef char type_is_defined[sizeof *t ? 1 : -1];
	(void) sizeof(type_is_defined);
	return t;
}

template<class T>
inline void defined_delete(T *t) { delete defined_ptr(t); }

struct defined_deleter { template<class T> static void del(T *p) { defined_delete(p); } };

#endif
