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
#ifndef ARRAY_H
#define ARRAY_H

#include "defined_ptr.h"
#include "uncopyable.h"
#include <cstddef>

template<typename T>
class SimpleArray : Uncopyable {
public:
	explicit SimpleArray(std::size_t size = 0) : a_(size ? new T[size] : 0) {}
	~SimpleArray() { delete[] defined_ptr(a_); }
	void reset(std::size_t size = 0) { delete[] defined_ptr(a_); a_ = size ? new T[size] : 0; }
	T * get() const { return a_; }
	operator T *() const { return a_; }

private:
	T *a_;
};

template<typename T>
class Array {
public:
	explicit Array(std::size_t size = 0) : a_(size), size_(size) {}
	void reset(std::size_t size = 0) { a_.reset(size); size_ = size; }
	std::size_t size() const { return size_; }
	T * get() const { return a_; }
	operator T *() const { return a_; }

private:
	SimpleArray<T> a_;
	std::size_t size_;
};

#endif
