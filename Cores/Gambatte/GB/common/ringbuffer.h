/***************************************************************************
 *   Copyright (C) 2008 by Sindre Aamås                                    *
 *   sinamas@users.sourceforge.net                                         *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License version 2 as     *
 *   published by the Free Software Foundation.                            *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License version 2 for more details.                *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   version 2 along with this program; if not, write to the               *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/
#ifndef RINGBUFFER_H
#define RINGBUFFER_H

#include "array.h"
#include <algorithm>
#include <cstddef>
#include <cstring>

template<typename T>
class RingBuffer {
public:
	explicit RingBuffer(std::size_t size = 0)
	: endpos_(0), rpos_(0), wpos_(0)
	{
		reset(size);
	}

	void reset(std::size_t size);

	void clear() {
		wpos_ = rpos_ = 0;
	}

	void fill(T value);
	void read(T *out, std::size_t num);
	void write(T const *in, std::size_t num);

	std::size_t avail() const {
		return (wpos_ < rpos_ ? 0 : endpos_) + rpos_ - wpos_ - 1;
	}

	std::size_t used() const {
		return (wpos_ < rpos_ ? endpos_ : 0) + wpos_ - rpos_;
	}

	std::size_t size() const {
		return endpos_ - 1;
	}

private:
	Array<T> buf_;
	std::size_t endpos_;
	std::size_t rpos_;
	std::size_t wpos_;
};

template<typename T>
void RingBuffer<T>::reset(std::size_t size) {
	endpos_ = size + 1;
	rpos_ = wpos_ = 0;
	buf_.reset(size ? endpos_ : 0);
}

template<typename T>
void RingBuffer<T>::fill(T value) {
	std::fill(buf_.get(), buf_.get() + buf_.size(), value);
	rpos_ = 0;
	wpos_ = endpos_ - 1;
}

template<typename T>
void RingBuffer<T>::read(T *out, std::size_t num) {
	if (rpos_ + num > endpos_) {
		std::size_t const n = endpos_ - rpos_;
		std::memcpy(out, buf_ + rpos_, n * sizeof *out);
		rpos_ = 0;
		num -= n;
		out += n;
	}

	std::memcpy(out, buf_ + rpos_, num * sizeof *out);
	if ((rpos_ += num) == endpos_)
		rpos_ = 0;
}

template<typename T>
void RingBuffer<T>::write(T const *in, std::size_t num) {
	if (wpos_ + num > endpos_) {
		std::size_t const n = endpos_ - wpos_;
		std::memcpy(buf_ + wpos_, in, n * sizeof *buf_);
		wpos_ = 0;
		num -= n;
		in += n;
	}

	std::memcpy(buf_ + wpos_, in, num * sizeof *buf_);
	if ((wpos_ += num) == endpos_)
		wpos_ = 0;
}

#endif
