//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef LINKED_OBJECT_POOL_HXX
#define LINKED_OBJECT_POOL_HXX

#include <list>
#include "bspf.hxx"

/**
  A fixed-size object-pool based doubly-linked list that makes use of
  multiple STL lists, to reduce frequent (de)allocations.

  This structure can be used as either a stack or queue, but also allows
  for removal at any location in the list.

  There are two internal lists; one stores active nodes, and the other
  stores pool nodes that have been 'deleted' from the active list (note
  that no actual deletion takes place; nodes are simply moved from one list
  to another).  Similarly, when a new node is added to the active list, it
  is simply moved from the pool list to the active list.

  In all cases, the variable 'myCurrent' is updated to point to the
  current node.

  NOTE: You must always call 'currentIsValid()' before calling 'current()',
        to make sure that the return value is a valid reference.

        In the case of methods which wrap the C++ 'splice()' method, the
        semantics of splice are followed wrt invalid/out-of-range/etc
        iterators.  See the applicable C++ STL documentation for such
        behaviour.

  @author Stephen Anthony
*/
namespace Common {

template <typename T, uInt32 CAPACITY = 100>
class LinkedObjectPool
{
  public:
    using iter = typename std::list<T>::iterator;
    using const_iter = typename std::list<T>::const_iterator;

    /*
      Create a pool of size CAPACITY; the active list starts out empty.
    */
    LinkedObjectPool<T, CAPACITY>() { resize(CAPACITY); }

    /**
      Return node data that the 'current' iterator points to.
      Note that this returns a valid value only in the case where the list
      is non-empty (at least one node has been added to the active list).

      Make sure to call 'currentIsValid()' before accessing this method.
    */
    T& current() const { return *myCurrent; }

    /**
      Returns current's position in the list

      SLOW, but only required for messages
    */
    uInt32 currentIdx() const {
      if(empty())
        return 0;

      iter it = myCurrent;
      uInt32 idx = 1;

      while(it != myList.begin()) {
        ++idx;
        --it;
      }
      return idx;
    }

    /**
      Does the 'current' iterator point to a valid node in the active list?
      This must be called before 'current()' is called.
    */
    bool currentIsValid() const { return myCurrent != myList.end(); }

    /**
      Advance 'current' iterator to previous position in the active list.
      If we go past the beginning, it is reset to one past the end (indicates nullptr).
    */
    void moveToPrevious() {
      if(currentIsValid())
        myCurrent = myCurrent == myList.begin() ? myList.end() : std::prev(myCurrent, 1);
    }

    /**
      Advance 'current' iterator to next position in the active list.
      If we go past the last node, it will point to one past the end (indicates nullptr).
    */
    void moveToNext() {
      if(currentIsValid())
        myCurrent = std::next(myCurrent, 1);
    }

    /**
      Advance 'current' iterator to first position in the active list.
    */
    void moveToFirst() {
      if(currentIsValid())
        myCurrent = myList.begin();
    }

    /**
      Advance 'current' iterator to last position in the active list.
    */
    void moveToLast() {
      if(currentIsValid())
        myCurrent = std::prev(myList.end(), 1);
    }

    /**
      Return an iterator to the first node in the active list.
    */
    const_iter first() const { return myList.begin(); }

    /**
      Return an iterator to the last node in the active list.
    */
    const_iter last() const { return std::prev(myList.end(), 1); }

    /**
      Return an iterator to the previous node of 'i' in the active list.
    */
    const_iter previous(const_iter i) const { return std::prev(i, 1); }

    /**
      Return an iterator to the next node to 'current' in the active list.
    */
    const_iter next(const_iter i) const { return std::next(i, 1); }

    /**
      Canonical iterators from C++ STL.
    */
    const_iter cbegin() const { return myList.cbegin(); }
    const_iter cend() const   { return myList.cend();   }

    /**
      Answer whether 'current' is at the specified iterator.
    */
    bool atFirst() const { return myCurrent == first(); }
    bool atLast() const  { return myCurrent == last();  }

    /**
      Add a new node at the beginning of the active list, and update 'current'
      to point to that node.
    */
    void addFirst() {
      myList.splice(myList.begin(), myPool, myPool.begin());
      myCurrent = myList.begin();
    }

    /**
      Add a new node at the end of the active list, and update 'current'
      to point to that node.
    */
    void addLast() {
      myList.splice(myList.end(), myPool, myPool.begin());
      myCurrent = std::prev(myList.end(), 1);
    }

    /**
      Remove the first node of the active list, updating 'current' if it
      happens to be the one removed.
    */
    void removeFirst() {
      const_iter i = myList.cbegin();
      myPool.splice(myPool.end(), myList, i);
      if(myCurrent == i)  // did we just invalidate 'current'
        moveToNext();     // if so, move to the next node
    }

    /**
      Remove the last node of the active list, updating 'current' if it
      happens to be the one removed.
    */
    void removeLast() {
      const_iter i = std::prev(myList.end(), 1);
      myPool.splice(myPool.end(), myList, i);
      if(myCurrent == i)  // did we just invalidate 'current'
        moveToPrevious(); // if so, move to the previous node
    }

    /**
      Remove a single element from the active list at position of the iterator.
    */
    void remove(const_iter i) {
      myPool.splice(myPool.end(), myList, i);
    }

    /**
      Remove a single element from the active list by index, offset from
      the beginning of the list. (ie, '0' means first element, '1' is second,
      and so on).
    */
    void remove(uInt32 index) {
      myPool.splice(myPool.end(), myList, std::next(myList.begin(), index));
    }

    /**
      Remove range of elements from the beginning of the active list to
      the 'current' node.
    */
    void removeToFirst() {
      myPool.splice(myPool.end(), myList, myList.begin(), myCurrent);
    }

    /**
      Remove range of elements from the node after 'current' to the end of the
      active list.
    */
    void removeToLast() {
      if(currentIsValid())
        myPool.splice(myPool.end(), myList, std::next(myCurrent, 1), myList.end());
    }

    /**
      Resize the pool to specified size, invalidating the list in the process
      (ie, the list essentially becomes empty again).
    */
    void resize(uInt32 capacity) {
      if(myCapacity != capacity)  // only resize when necessary
      {
        myList.clear();  myPool.clear();
        myCurrent = myList.end();
        myCapacity = capacity;

        for(uInt32 i = 0; i < myCapacity; ++i)
          myPool.emplace_back(T());
      }
    }

    /**
      Erase entire contents of active list.
    */
    void clear() {
      myPool.splice(myPool.end(), myList, myList.begin(), myList.end());
      myCurrent = myList.end();
    }

    uInt32 capacity() const { return myCapacity; }

    uInt32 size() const { return static_cast<uInt32>(myList.size()); }
    bool empty() const  { return size() == 0; }
    bool full() const   { return size() >= capacity(); }

    friend ostream& operator<<(ostream& os, const LinkedObjectPool<T>& p) {
      for(const auto& i: p.myList)
        os << i << (p.current() == i ? "* " : "  ");
      return os;
    }

  private:
    std::list<T> myList, myPool;

    // Current position in the active list (end() indicates an invalid position)
    iter myCurrent{myList.end()};

    // Total capacity of the pool
    uInt32 myCapacity{0};

  private:
    // Following constructors and assignment operators not supported
    LinkedObjectPool(const LinkedObjectPool&) = delete;
    LinkedObjectPool(LinkedObjectPool&&) = delete;
    LinkedObjectPool& operator=(const LinkedObjectPool&) = delete;
    LinkedObjectPool& operator=(LinkedObjectPool&&) = delete;
};

} // namespace Common

#endif
