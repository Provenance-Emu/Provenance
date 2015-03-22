//
//   Copyright (C) 2009 by sinamas <sinamas at users.sourceforge.net>
//
//   This program is free software; you can redistribute it and/or modify
//   it under the terms of the GNU General Public License version 2 as
//   published by the Free Software Foundation.
//
//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License version 2 for more details.
//
//   You should have received a copy of the GNU General Public License
//   version 2 along with this program; if not, write to the
//   Free Software Foundation, Inc.,
//   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//

#ifndef MINKEEPER_H
#define MINKEEPER_H

#include <algorithm>

namespace min_keeper_detail {

template<int n> struct CeiledLog2 { enum { r = 1 + CeiledLog2<(n + 1) / 2>::r }; };
template<> struct CeiledLog2<1> { enum { r = 0 }; };

template<int v, int n> struct CeiledDiv2n { enum { r = CeiledDiv2n<(v + 1) / 2, n - 1>::r }; };
template<int v> struct CeiledDiv2n<v, 0> { enum { r = v }; };
// alternatively: template<int v, int n> struct CeiledDiv2n { enum { r = (v + (1 << n) - 1) >> n }; };

template<template<int> class T, int n> struct Sum { enum { r = T<n-1>::r + Sum<T, n-1>::r }; };
template<template<int> class T> struct Sum<T, 0> { enum { r = 0 }; };

}

// Keeps track of minimum value identified by id as values change.
// Higher ids prioritized (as min value) if values are equal. (Can be inverted by swapping < for <=).
// Higher ids can be faster to change when the number of ids isn't a power of 2.
// Thus, the ones that change more frequently should have higher ids if priority allows for it.
template<int ids>
class MinKeeper {
public:
	explicit MinKeeper(unsigned long initValue);
	int min() const { return a_[0]; }
	unsigned long minValue() const { return minValue_; }

	template<int id>
	void setValue(unsigned long cnt) {
		values_[id] = cnt;
		updateValue<id / 2>(*this);
	}

	void setValue(int id, unsigned long cnt) {
		values_[id] = cnt;
		updateValueLut.call(id >> 1, *this);
	}

	unsigned long value(int id) const { return values_[id]; }

private:
	enum { height = min_keeper_detail::CeiledLog2<ids>::r };
	template<int depth> struct Num { enum { r = min_keeper_detail::CeiledDiv2n<ids, height - depth>::r }; };
	template<int depth> struct Sum { enum { r = min_keeper_detail::Sum<Num, depth>::r }; };

	template<int id, int depth>
	struct UpdateValue {
		enum { p = Sum<depth - 1>::r + id
		    , c0 = Sum<depth>::r + id * 2
		    , c1 = id * 2 + 1 < Num<depth>::r ? c0 + 1 : c0 };
		static void updateValue(MinKeeper<ids> &m) {
			m.a_[p] = m.values_[m.a_[c0]] < m.values_[m.a_[c1]] ? m.a_[c0] : m.a_[c1];
			UpdateValue<id / 2, depth - 1>::updateValue(m);
		}
	};

	template<int id>
	struct UpdateValue<id, 0> {
		static void updateValue(MinKeeper<ids> &m) {
			m.minValue_ = m.values_[m.a_[0]];
		}
	};

	class UpdateValueLut {
	public:
		UpdateValueLut() { FillLut<Num<height - 1>::r - 1, 0>::fillLut(*this); }
		void call(int id, MinKeeper<ids> &mk) const { lut_[id](mk); }

	private:
		template<int id, int dummy>
		struct FillLut {
			static void fillLut(UpdateValueLut & l) {
				l.lut_[id] = updateValue<id>;
				FillLut<id - 1, dummy>::fillLut(l);
			}
		};

		template<int dummy>
		struct FillLut<-1, dummy> {
			static void fillLut(UpdateValueLut &) {}
		};

		void (*lut_[Num<height - 1>::r])(MinKeeper<ids> &);
	};

	static UpdateValueLut updateValueLut;
	unsigned long values_[ids];
	unsigned long minValue_;
	int a_[Sum<height>::r];

	template<int id> static void updateValue(MinKeeper<ids> &m);
};

template<int ids> typename MinKeeper<ids>::UpdateValueLut MinKeeper<ids>::updateValueLut;

template<int ids>
MinKeeper<ids>::MinKeeper(unsigned long const initValue) {
	std::fill(values_, values_ + ids, initValue);

	// todo: simplify/less template bloat.

	for (int i = 0; i < Num<height - 1>::r; ++i) {
		int const c0 = i * 2;
		int const c1 = c0 + 1 < ids ? c0 + 1 : c0;
		a_[Sum<height - 1>::r + i] = values_[c0] < values_[c1] ? c0 : c1;
	}

	int n = Num<height - 1>::r;
	int offset = Sum<height - 1>::r;
	while (offset) {
		int const pn = (n + 1) >> 1;
		int const poff = offset - pn;
		for (int i = 0; i < pn; ++i) {
			int const c0 = offset + i * 2;
			int const c1 = i * 2 + 1 < n ? c0 + 1 : c0;
			a_[poff + i] = values_[a_[c0]] < values_[a_[c1]] ? a_[c0] : a_[c1];
		}

		offset = poff;
		n = pn;
	}

	minValue_ = values_[a_[0]];
}

template<int ids>
template<int id>
void MinKeeper<ids>::updateValue(MinKeeper<ids> &m) {
	enum { c0 = id * 2
	     , c1 = c0 + 1 < ids ? c0 + 1 : c0 };
	m.a_[Sum<height - 1>::r + id] = m.values_[c0] < m.values_[c1] ? c0 : c1;
	UpdateValue<id / 2, height - 1>::updateValue(m);
}

#endif
