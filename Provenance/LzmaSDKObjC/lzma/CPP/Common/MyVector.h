// Common/MyVector.h

#ifndef __COMMON_MY_VECTOR_H
#define __COMMON_MY_VECTOR_H

#include <string.h>

template <class T>
class CRecordVector
{
  T *_items;
  unsigned _size;
  unsigned _capacity;
  
  void MoveItems(unsigned destIndex, unsigned srcIndex)
  {
    memmove(_items + destIndex, _items + srcIndex, (size_t)(_size - srcIndex) * sizeof(T));
  }

  void ReserveOnePosition()
  {
    if (_size == _capacity)
    {
      unsigned newCapacity = _capacity + (_capacity >> 2) + 1;
      T *p = new T[newCapacity];
      if (_size != 0)
        memcpy(p, _items, (size_t)_size * sizeof(T));
      delete []_items;
      _items = p;
      _capacity = newCapacity;
    }
  }

public:

  CRecordVector(): _items(0), _size(0), _capacity(0) {}
  
  CRecordVector(const CRecordVector &v): _items(0), _size(0), _capacity(0)
  {
    unsigned size = v.Size();
    if (size != 0)
    {
      _items = new T[size];
      _size = size;
      _capacity = size;
      memcpy(_items, v._items, (size_t)size * sizeof(T));
    }
  }
  
  unsigned Size() const { return _size; }
  bool IsEmpty() const { return _size == 0; }
  
  void ConstructReserve(unsigned size)
  {
    if (size != 0)
    {
      _items = new T[size];
      _capacity = size;
    }
  }

  void Reserve(unsigned newCapacity)
  {
    if (newCapacity > _capacity)
    {
      T *p = new T[newCapacity];
      if (_size != 0)
        memcpy(p, _items, (size_t)_size * sizeof(T));
      delete []_items;
      _items = p;
      _capacity = newCapacity;
    }
  }

  void ClearAndReserve(unsigned newCapacity)
  {
    Clear();
    if (newCapacity > _capacity)
    {
      delete []_items;
      _items = NULL;
      _capacity = 0;
      _items = new T[newCapacity];
      _capacity = newCapacity;
    }
  }

  void ClearAndSetSize(unsigned newSize)
  {
    ClearAndReserve(newSize);
    _size = newSize;
  }

  void ChangeSize_KeepData(unsigned newSize)
  {
    if (newSize > _capacity)
    {
      T *p = new T[newSize];
      if (_size != 0)
        memcpy(p, _items, (size_t)_size * sizeof(T));
      delete []_items;
      _items = p;
      _capacity = newSize;
    }
    _size = newSize;
  }

  void ReserveDown()
  {
    if (_size == _capacity)
      return;
    T *p = NULL;
    if (_size != 0)
    {
      p = new T[_size];
      memcpy(p, _items, (size_t)_size * sizeof(T));
    }
    delete []_items;
    _items = p;
    _capacity = _size;
  }
  
  ~CRecordVector() { delete []_items; }
  
  void ClearAndFree()
  {
    delete []_items;
    _items = NULL;
    _size = 0;
    _capacity = 0;
  }
  
  void Clear() { _size = 0; }

  void DeleteBack() { _size--; }
  
  void DeleteFrom(unsigned index)
  {
    // if (index <= _size)
      _size = index;
  }
  
  void DeleteFrontal(unsigned num)
  {
    if (num != 0)
    {
      MoveItems(0, num);
      _size -= num;
    }
  }

  void Delete(unsigned index)
  {
    MoveItems(index, index + 1);
    _size -= 1;
  }

  /*
  void Delete(unsigned index, unsigned num)
  {
    if (num > 0)
    {
      MoveItems(index, index + num);
      _size -= num;
    }
  }
  */

  CRecordVector& operator=(const CRecordVector &v)
  {
    if (&v == this)
      return *this;
    unsigned size = v.Size();
    if (size > _capacity)
    {
      delete []_items;
      _capacity = 0;
      _size = 0;
      _items = NULL;
      _items = new T[size];
      _capacity = size;
    }
    _size = size;
    if (size != 0)
      memcpy(_items, v._items, (size_t)size * sizeof(T));
    return *this;
  }

  CRecordVector& operator+=(const CRecordVector &v)
  {
    unsigned size = v.Size();
    Reserve(_size + size);
    if (size != 0)
      memcpy(_items + _size, v._items, (size_t)size * sizeof(T));
    _size += size;
    return *this;
  }
  
  unsigned Add(const T item)
  {
    ReserveOnePosition();
    _items[_size] = item;
    return _size++;
  }

  void AddInReserved(const T item)
  {
    _items[_size++] = item;
  }

  void Insert(unsigned index, const T item)
  {
    ReserveOnePosition();
    MoveItems(index + 1, index);
    _items[index] = item;
    _size++;
  }

  void MoveToFront(unsigned index)
  {
    if (index != 0)
    {
      T temp = _items[index];
      memmove(_items + 1, _items, (size_t)index * sizeof(T));
      _items[0] = temp;
    }
  }

  const T& operator[](unsigned index) const { return _items[index]; }
        T& operator[](unsigned index)       { return _items[index]; }
  const T& Front() const { return _items[0]; }
        T& Front()       { return _items[0]; }
  const T& Back() const  { return _items[_size - 1]; }
        T& Back()        { return _items[_size - 1]; }

  /*
  void Swap(unsigned i, unsigned j)
  {
    T temp = _items[i];
    _items[i] = _items[j];
    _items[j] = temp;
  }
  */

  int FindInSorted(const T item, unsigned left, unsigned right) const
  {
    while (left != right)
    {
      unsigned mid = (left + right) / 2;
      const T midVal = (*this)[mid];
      if (item == midVal)
        return mid;
      if (item < midVal)
        right = mid;
      else
        left = mid + 1;
    }
    return -1;
  }

  int FindInSorted2(const T &item, unsigned left, unsigned right) const
  {
    while (left != right)
    {
      unsigned mid = (left + right) / 2;
      const T& midVal = (*this)[mid];
      int comp = item.Compare(midVal);
      if (comp == 0)
        return mid;
      if (comp < 0)
        right = mid;
      else
        left = mid + 1;
    }
    return -1;
  }

  int FindInSorted(const T item) const
  {
    return FindInSorted(item, 0, _size);
  }

  int FindInSorted2(const T &item) const
  {
    return FindInSorted2(item, 0, _size);
  }

  unsigned AddToUniqueSorted(const T item)
  {
    unsigned left = 0, right = _size;
    while (left != right)
    {
      unsigned mid = (left + right) / 2;
      const T midVal = (*this)[mid];
      if (item == midVal)
        return mid;
      if (item < midVal)
        right = mid;
      else
        left = mid + 1;
    }
    Insert(right, item);
    return right;
  }

  unsigned AddToUniqueSorted2(const T &item)
  {
    unsigned left = 0, right = _size;
    while (left != right)
    {
      unsigned mid = (left + right) / 2;
      const T& midVal = (*this)[mid];
      int comp = item.Compare(midVal);
      if (comp == 0)
        return mid;
      if (comp < 0)
        right = mid;
      else
        left = mid + 1;
    }
    Insert(right, item);
    return right;
  }

  static void SortRefDown(T* p, unsigned k, unsigned size, int (*compare)(const T*, const T*, void *), void *param)
  {
    T temp = p[k];
    for (;;)
    {
      unsigned s = (k << 1);
      if (s > size)
        break;
      if (s < size && compare(p + s + 1, p + s, param) > 0)
        s++;
      if (compare(&temp, p + s, param) >= 0)
        break;
      p[k] = p[s];
      k = s;
    }
    p[k] = temp;
  }

  void Sort(int (*compare)(const T*, const T*, void *), void *param)
  {
    unsigned size = _size;
    if (size <= 1)
      return;
    T* p = (&Front()) - 1;
    {
      unsigned i = size >> 1;
      do
        SortRefDown(p, i, size, compare, param);
      while (--i != 0);
    }
    do
    {
      T temp = p[size];
      p[size--] = p[1];
      p[1] = temp;
      SortRefDown(p, 1, size, compare, param);
    }
    while (size > 1);
  }

  static void SortRefDown2(T* p, unsigned k, unsigned size)
  {
    T temp = p[k];
    for (;;)
    {
      unsigned s = (k << 1);
      if (s > size)
        break;
      if (s < size && p[s + 1].Compare(p[s]) > 0)
        s++;
      if (temp.Compare(p[s]) >= 0)
        break;
      p[k] = p[s];
      k = s;
    }
    p[k] = temp;
  }

  void Sort2()
  {
    unsigned size = _size;
    if (size <= 1)
      return;
    T* p = (&Front()) - 1;
    {
      unsigned i = size >> 1;
      do
        SortRefDown2(p, i, size);
      while (--i != 0);
    }
    do
    {
      T temp = p[size];
      p[size--] = p[1];
      p[1] = temp;
      SortRefDown2(p, 1, size);
    }
    while (size > 1);
  }
};

typedef CRecordVector<int> CIntVector;
typedef CRecordVector<unsigned int> CUIntVector;
typedef CRecordVector<bool> CBoolVector;
typedef CRecordVector<unsigned char> CByteVector;
typedef CRecordVector<void *> CPointerVector;

template <class T>
class CObjectVector
{
  CPointerVector _v;
public:
  unsigned Size() const { return _v.Size(); }
  bool IsEmpty() const { return _v.IsEmpty(); }
  void ReserveDown() { _v.ReserveDown(); }
  // void Reserve(unsigned newCapacity) { _v.Reserve(newCapacity); }
  void ClearAndReserve(unsigned newCapacity) { Clear(); _v.ClearAndReserve(newCapacity); }

  CObjectVector() {};
  CObjectVector(const CObjectVector &v)
  {
    unsigned size = v.Size();
    _v.ConstructReserve(size);
    for (unsigned i = 0; i < size; i++)
      _v.AddInReserved(new T(v[i]));
  }
  CObjectVector& operator=(const CObjectVector &v)
  {
    if (&v == this)
      return *this;
    Clear();
    unsigned size = v.Size();
    _v.Reserve(size);
    for (unsigned i = 0; i < size; i++)
      _v.AddInReserved(new T(v[i]));
    return *this;
  }

  CObjectVector& operator+=(const CObjectVector &v)
  {
    unsigned size = v.Size();
    _v.Reserve(Size() + size);
    for (unsigned i = 0; i < size; i++)
      _v.AddInReserved(new T(v[i]));
    return *this;
  }
  
  const T& operator[](unsigned index) const { return *((T *)_v[index]); }
        T& operator[](unsigned index)       { return *((T *)_v[index]); }
  const T& Front() const { return operator[](0); }
        T& Front()       { return operator[](0); }
  const T& Back() const  { return operator[](_v.Size() - 1); }
        T& Back()        { return operator[](_v.Size() - 1); }
  
  void MoveToFront(unsigned index) { _v.MoveToFront(index); }

  unsigned Add(const T& item) { return _v.Add(new T(item)); }
  
  void AddInReserved(const T& item) { _v.AddInReserved(new T(item)); }
  
  T& AddNew()
  {
    T *p = new T;
    _v.Add(p);
    return *p;
  }
  
  T& AddNewInReserved()
  {
    T *p = new T;
    _v.AddInReserved(p);
    return *p;
  }
  
  void Insert(unsigned index, const T& item) { _v.Insert(index, new T(item)); }
  
  T& InsertNew(unsigned index)
  {
    T *p = new T;
    _v.Insert(index, p);
    return *p;
  }

  ~CObjectVector()
  {
    for (unsigned i = _v.Size(); i != 0;)
      delete (T *)_v[--i];
  }
  
  void ClearAndFree()
  {
    Clear();
    _v.ClearAndFree();
  }
  
  void Clear()
  {
    for (unsigned i = _v.Size(); i != 0;)
      delete (T *)_v[--i];
    _v.Clear();
  }
  
  void DeleteFrom(unsigned index)
  {
    unsigned size = _v.Size();
    for (unsigned i = index; i < size; i++)
      delete (T *)_v[i];
    _v.DeleteFrom(index);
  }

  void DeleteFrontal(unsigned num)
  {
    for (unsigned i = 0; i < num; i++)
      delete (T *)_v[i];
    _v.DeleteFrontal(num);
  }

  void DeleteBack()
  {
    delete (T *)_v[_v.Size() - 1];
    _v.DeleteBack();
  }

  void Delete(unsigned index)
  {
    delete (T *)_v[index];
    _v.Delete(index);
  }

  /*
  void Delete(unsigned index, unsigned num)
  {
    for (unsigned i = 0; i < num; i++)
      delete (T *)_v[index + i];
    _v.Delete(index, num);
  }
  */

  /*
  int Find(const T& item) const
  {
    unsigned size = Size();
    for (unsigned i = 0; i < size; i++)
      if (item == (*this)[i])
        return i;
    return -1;
  }
  */
  
  int FindInSorted(const T& item) const
  {
    unsigned left = 0, right = Size();
    while (left != right)
    {
      unsigned mid = (left + right) / 2;
      const T& midVal = (*this)[mid];
      int comp = item.Compare(midVal);
      if (comp == 0)
        return mid;
      if (comp < 0)
        right = mid;
      else
        left = mid + 1;
    }
    return -1;
  }

  unsigned AddToUniqueSorted(const T& item)
  {
    unsigned left = 0, right = Size();
    while (left != right)
    {
      unsigned mid = (left + right) / 2;
      const T& midVal = (*this)[mid];
      int comp = item.Compare(midVal);
      if (comp == 0)
        return mid;
      if (comp < 0)
        right = mid;
      else
        left = mid + 1;
    }
    Insert(right, item);
    return right;
  }

  /*
  unsigned AddToSorted(const T& item)
  {
    unsigned left = 0, right = Size();
    while (left != right)
    {
      unsigned mid = (left + right) / 2;
      const T& midVal = (*this)[mid];
      int comp = item.Compare(midVal);
      if (comp == 0)
      {
        right = mid + 1;
        break;
      }
      if (comp < 0)
        right = mid;
      else
        left = mid + 1;
    }
    Insert(right, item);
    return right;
  }
  */

  void Sort(int (*compare)(void *const *, void *const *, void *), void *param)
    { _v.Sort(compare, param); }

  static int CompareObjectItems(void *const *a1, void *const *a2, void * /* param */)
    { return (*(*((const T **)a1))).Compare(*(*((const T **)a2))); }

  void Sort() { _v.Sort(CompareObjectItems, 0); }
};

#define FOR_VECTOR(_i_, _v_) for (unsigned _i_ = 0; _i_ < (_v_).Size(); _i_++)

#endif
