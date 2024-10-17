#ifndef SCOPED_PTR_H
#define SCOPED_PTR_H

#include "transfer_ptr.h"
#include "uncopyable.h"

template<class T, class Deleter = defined_deleter>
class scoped_ptr : Uncopyable {
public:
	explicit scoped_ptr(T *p = 0) : p_(p) {}
	template<class U> explicit scoped_ptr(transfer_ptr<U, Deleter> p) : p_(p.release()) {}
	~scoped_ptr() { Deleter::del(p_); }
	T * get() const { return p_; }
	void reset(T *p = 0) { Deleter::del(p_); p_ = p; }
	T & operator*() const { return *p_; }
	T * operator->() const { return p_; }
	operator bool() const { return p_; }

	template<class U>
	scoped_ptr & operator=(transfer_ptr<U, Deleter> p) {
		reset(p.release());
		return *this;
	}

private:
	T *p_;
};

#endif
