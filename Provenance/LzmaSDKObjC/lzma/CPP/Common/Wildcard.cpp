// Common/Wildcard.cpp

#include "StdAfx.h"

#include "Wildcard.h"

bool g_CaseSensitive =
  #ifdef _WIN32
    false;
  #else
    true;
  #endif


bool IsPath1PrefixedByPath2(const wchar_t *s1, const wchar_t *s2)
{
  if (g_CaseSensitive)
    return IsString1PrefixedByString2(s1, s2);
  return IsString1PrefixedByString2_NoCase(s1, s2);
}

int CompareFileNames(const wchar_t *s1, const wchar_t *s2) STRING_UNICODE_THROW
{
  if (g_CaseSensitive)
    return wcscmp(s1, s2);
  return MyStringCompareNoCase(s1, s2);
}

#ifndef USE_UNICODE_FSTRING
int CompareFileNames(const char *s1, const char *s2)
{
  if (g_CaseSensitive)
    return wcscmp(fs2us(s1), fs2us(s2));
  return MyStringCompareNoCase(fs2us(s1), fs2us(s2));
}
#endif

// -----------------------------------------
// this function compares name with mask
// ? - any char
// * - any char or empty

static bool EnhancedMaskTest(const wchar_t *mask, const wchar_t *name)
{
  for (;;)
  {
    wchar_t m = *mask;
    wchar_t c = *name;
    if (m == 0)
      return (c == 0);
    if (m == '*')
    {
      if (EnhancedMaskTest(mask + 1, name))
        return true;
      if (c == 0)
        return false;
    }
    else
    {
      if (m == '?')
      {
        if (c == 0)
          return false;
      }
      else if (m != c)
        if (g_CaseSensitive || MyCharUpper(m) != MyCharUpper(c))
          return false;
      mask++;
    }
    name++;
  }
}

// --------------------------------------------------
// Splits path to strings

void SplitPathToParts(const UString &path, UStringVector &pathParts)
{
  pathParts.Clear();
  unsigned len = path.Len();
  if (len == 0)
    return;
  UString name;
  unsigned prev = 0;
  for (unsigned i = 0; i < len; i++)
    if (IsPathSepar(path[i]))
    {
      name.SetFrom(path.Ptr(prev), i - prev);
      pathParts.Add(name);
      prev = i + 1;
    }
  name.SetFrom(path.Ptr(prev), len - prev);
  pathParts.Add(name);
}

void SplitPathToParts_2(const UString &path, UString &dirPrefix, UString &name)
{
  const wchar_t *start = path;
  const wchar_t *p = start + path.Len();
  for (; p != start; p--)
    if (IsPathSepar(*(p - 1)))
      break;
  dirPrefix.SetFrom(path, (unsigned)(p - start));
  name = p;
}

void SplitPathToParts_Smart(const UString &path, UString &dirPrefix, UString &name)
{
  const wchar_t *start = path;
  const wchar_t *p = start + path.Len();
  if (p != start)
  {
    if (IsPathSepar(*(p - 1)))
      p--;
    for (; p != start; p--)
      if (IsPathSepar(*(p - 1)))
        break;
  }
  dirPrefix.SetFrom(path, (unsigned)(p - start));
  name = p;
}

UString ExtractDirPrefixFromPath(const UString &path)
{
  const wchar_t *start = path;
  const wchar_t *p = start + path.Len();
  for (; p != start; p--)
    if (IsPathSepar(*(p - 1)))
      break;
  return path.Left((unsigned)(p - start));
}

UString ExtractFileNameFromPath(const UString &path)
{
  const wchar_t *start = path;
  const wchar_t *p = start + path.Len();
  for (; p != start; p--)
    if (IsPathSepar(*(p - 1)))
      break;
  return p;
}


bool DoesWildcardMatchName(const UString &mask, const UString &name)
{
  return EnhancedMaskTest(mask, name);
}

bool DoesNameContainWildcard(const UString &path)
{
  for (unsigned i = 0; i < path.Len(); i++)
  {
    wchar_t c = path[i];
    if (c == '*' || c == '?')
      return true;
  }
  return false;
}


// ----------------------------------------------------------'
// NWildcard

namespace NWildcard {

/*

M = MaskParts.Size();
N = TestNameParts.Size();

                           File                          Dir
ForFile     rec   M<=N  [N-M, N)                          -
!ForDir  nonrec   M=N   [0, M)                            -
 
ForDir      rec   M<N   [0, M) ... [N-M-1, N-1)  same as ForBoth-File
!ForFile nonrec         [0, M)                   same as ForBoth-File

ForFile     rec   m<=N  [0, M) ... [N-M, N)      same as ForBoth-File
ForDir   nonrec         [0, M)                   same as ForBoth-File

*/

bool CItem::AreAllAllowed() const
{
  return ForFile && ForDir && WildcardMatching && PathParts.Size() == 1 && PathParts.Front() == L"*";
}

bool CItem::CheckPath(const UStringVector &pathParts, bool isFile) const
{
  if (!isFile && !ForDir)
    return false;

  /*
  if (PathParts.IsEmpty())
  {
    // PathParts.IsEmpty() means all items (universal wildcard)
    if (!isFile)
      return true;
    if (pathParts.Size() <= 1)
      return ForFile;
    return (ForDir || Recursive && ForFile);
  }
  */

  int delta = (int)pathParts.Size() - (int)PathParts.Size();
  if (delta < 0)
    return false;
  int start = 0;
  int finish = 0;
  
  if (isFile)
  {
    if (!ForDir)
    {
      if (Recursive)
        start = delta;
      else if (delta !=0)
        return false;
    }
    if (!ForFile && delta == 0)
      return false;
  }
  
  if (Recursive)
  {
    finish = delta;
    if (isFile && !ForFile)
      finish = delta - 1;
  }
  
  for (int d = start; d <= finish; d++)
  {
    unsigned i;
    for (i = 0; i < PathParts.Size(); i++)
    {
      if (WildcardMatching)
      {
        if (!DoesWildcardMatchName(PathParts[i], pathParts[i + d]))
          break;
      }
      else
      {
        if (CompareFileNames(PathParts[i], pathParts[i + d]) != 0)
          break;
      }
    }
    if (i == PathParts.Size())
      return true;
  }
  return false;
}

bool CCensorNode::AreAllAllowed() const
{
  if (!Name.IsEmpty() ||
      !SubNodes.IsEmpty() ||
      !ExcludeItems.IsEmpty() ||
      IncludeItems.Size() != 1)
    return false;
  return IncludeItems.Front().AreAllAllowed();
}

int CCensorNode::FindSubNode(const UString &name) const
{
  FOR_VECTOR (i, SubNodes)
    if (CompareFileNames(SubNodes[i].Name, name) == 0)
      return i;
  return -1;
}

void CCensorNode::AddItemSimple(bool include, CItem &item)
{
  if (include)
    IncludeItems.Add(item);
  else
    ExcludeItems.Add(item);
}

void CCensorNode::AddItem(bool include, CItem &item, int ignoreWildcardIndex)
{
  if (item.PathParts.Size() <= 1)
  {
    if (item.PathParts.Size() != 0 && item.WildcardMatching)
    {
      if (!DoesNameContainWildcard(item.PathParts.Front()))
        item.WildcardMatching = false;
    }
    AddItemSimple(include, item);
    return;
  }
  const UString &front = item.PathParts.Front();
  
  // WIN32 doesn't support wildcards in file names
  if (item.WildcardMatching
      && ignoreWildcardIndex != 0
      && DoesNameContainWildcard(front))
  {
    AddItemSimple(include, item);
    return;
  }
  int index = FindSubNode(front);
  if (index < 0)
    index = SubNodes.Add(CCensorNode(front, this));
  item.PathParts.Delete(0);
  SubNodes[index].AddItem(include, item, ignoreWildcardIndex - 1);
}

void CCensorNode::AddItem(bool include, const UString &path, bool recursive, bool forFile, bool forDir, bool wildcardMatching)
{
  CItem item;
  SplitPathToParts(path, item.PathParts);
  item.Recursive = recursive;
  item.ForFile = forFile;
  item.ForDir = forDir;
  item.WildcardMatching = wildcardMatching;
  AddItem(include, item);
}

bool CCensorNode::NeedCheckSubDirs() const
{
  FOR_VECTOR (i, IncludeItems)
  {
    const CItem &item = IncludeItems[i];
    if (item.Recursive || item.PathParts.Size() > 1)
      return true;
  }
  return false;
}

bool CCensorNode::AreThereIncludeItems() const
{
  if (IncludeItems.Size() > 0)
    return true;
  FOR_VECTOR (i, SubNodes)
    if (SubNodes[i].AreThereIncludeItems())
      return true;
  return false;
}

bool CCensorNode::CheckPathCurrent(bool include, const UStringVector &pathParts, bool isFile) const
{
  const CObjectVector<CItem> &items = include ? IncludeItems : ExcludeItems;
  FOR_VECTOR (i, items)
    if (items[i].CheckPath(pathParts, isFile))
      return true;
  return false;
}

bool CCensorNode::CheckPathVect(const UStringVector &pathParts, bool isFile, bool &include) const
{
  if (CheckPathCurrent(false, pathParts, isFile))
  {
    include = false;
    return true;
  }
  include = true;
  bool finded = CheckPathCurrent(true, pathParts, isFile);
  if (pathParts.Size() <= 1)
    return finded;
  int index = FindSubNode(pathParts.Front());
  if (index >= 0)
  {
    UStringVector pathParts2 = pathParts;
    pathParts2.Delete(0);
    if (SubNodes[index].CheckPathVect(pathParts2, isFile, include))
      return true;
  }
  return finded;
}

/*
bool CCensorNode::CheckPath2(bool isAltStream, const UString &path, bool isFile, bool &include) const
{
  UStringVector pathParts;
  SplitPathToParts(path, pathParts);
  if (CheckPathVect(pathParts, isFile, include))
  {
    if (!include || !isAltStream)
      return true;
  }
  if (isAltStream && !pathParts.IsEmpty())
  {
    UString &back = pathParts.Back();
    int pos = back.Find(L':');
    if (pos > 0)
    {
      back.DeleteFrom(pos);
      return CheckPathVect(pathParts, isFile, include);
    }
  }
  return false;
}

bool CCensorNode::CheckPath(bool isAltStream, const UString &path, bool isFile) const
{
  bool include;
  if (CheckPath2(isAltStream, path, isFile, include))
    return include;
  return false;
}
*/

bool CCensorNode::CheckPathToRoot(bool include, UStringVector &pathParts, bool isFile) const
{
  if (CheckPathCurrent(include, pathParts, isFile))
    return true;
  if (Parent == 0)
    return false;
  pathParts.Insert(0, Name);
  return Parent->CheckPathToRoot(include, pathParts, isFile);
}

/*
bool CCensorNode::CheckPathToRoot(bool include, const UString &path, bool isFile) const
{
  UStringVector pathParts;
  SplitPathToParts(path, pathParts);
  return CheckPathToRoot(include, pathParts, isFile);
}
*/

void CCensorNode::AddItem2(bool include, const UString &path, bool recursive, bool wildcardMatching)
{
  if (path.IsEmpty())
    return;
  bool forFile = true;
  bool forFolder = true;
  UString path2 = path;
  if (IsPathSepar(path.Back()))
  {
    path2.DeleteBack();
    forFile = false;
  }
  AddItem(include, path2, recursive, forFile, forFolder, wildcardMatching);
}

void CCensorNode::ExtendExclude(const CCensorNode &fromNodes)
{
  ExcludeItems += fromNodes.ExcludeItems;
  FOR_VECTOR (i, fromNodes.SubNodes)
  {
    const CCensorNode &node = fromNodes.SubNodes[i];
    int subNodeIndex = FindSubNode(node.Name);
    if (subNodeIndex < 0)
      subNodeIndex = SubNodes.Add(CCensorNode(node.Name, this));
    SubNodes[subNodeIndex].ExtendExclude(node);
  }
}

int CCensor::FindPrefix(const UString &prefix) const
{
  FOR_VECTOR (i, Pairs)
    if (CompareFileNames(Pairs[i].Prefix, prefix) == 0)
      return i;
  return -1;
}

#ifdef _WIN32

bool IsDriveColonName(const wchar_t *s)
{
  wchar_t c = s[0];
  return c != 0 && s[1] == ':' && s[2] == 0 && (c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z');
}

unsigned GetNumPrefixParts_if_DrivePath(UStringVector &pathParts)
{
  if (pathParts.IsEmpty())
    return 0;
  
  unsigned testIndex = 0;
  if (pathParts[0].IsEmpty())
  {
    if (pathParts.Size() < 4
        || !pathParts[1].IsEmpty()
        || pathParts[2] != L"?")
      return 0;
    testIndex = 3;
  }
  if (NWildcard::IsDriveColonName(pathParts[testIndex]))
    return testIndex + 1;
  return 0;
}

#endif

static unsigned GetNumPrefixParts(const UStringVector &pathParts)
{
  if (pathParts.IsEmpty())
    return 0;
  
  #ifdef _WIN32
  
  if (IsDriveColonName(pathParts[0]))
    return 1;
  if (!pathParts[0].IsEmpty())
    return 0;

  if (pathParts.Size() == 1)
    return 1;
  if (!pathParts[1].IsEmpty())
    return 1;
  if (pathParts.Size() == 2)
    return 2;
  if (pathParts[2] == L".")
    return 3;

  unsigned networkParts = 2;
  if (pathParts[2] == L"?")
  {
    if (pathParts.Size() == 3)
      return 3;
    if (IsDriveColonName(pathParts[3]))
      return 4;
    if (!pathParts[3].IsEqualTo_Ascii_NoCase("UNC"))
      return 3;
    networkParts = 4;
  }

  networkParts +=
      // 2; // server/share
      1; // server
  if (pathParts.Size() <= networkParts)
    return pathParts.Size();
  return networkParts;

  #else
  
  return pathParts[0].IsEmpty() ? 1 : 0;
 
  #endif
}

void CCensor::AddItem(ECensorPathMode pathMode, bool include, const UString &path, bool recursive, bool wildcardMatching)
{
  if (path.IsEmpty())
    throw "Empty file path";

  UStringVector pathParts;
  SplitPathToParts(path, pathParts);

  bool forFile = true;
  if (pathParts.Back().IsEmpty())
  {
    forFile = false;
    pathParts.DeleteBack();
  }
  
  UString prefix;
  
  int ignoreWildcardIndex = -1;

  // #ifdef _WIN32
  // we ignore "?" wildcard in "\\?\" prefix.
  if (pathParts.Size() >= 3
      && pathParts[0].IsEmpty()
      && pathParts[1].IsEmpty()
      && pathParts[2] == L"?")
    ignoreWildcardIndex = 2;
  // #endif

  if (pathMode != k_AbsPath)
  {
    ignoreWildcardIndex = -1;

    const unsigned numPrefixParts = GetNumPrefixParts(pathParts);
    unsigned numSkipParts = numPrefixParts;

    if (pathMode != k_FullPath)
    {
      if (numPrefixParts != 0 && pathParts.Size() > numPrefixParts)
        numSkipParts = pathParts.Size() - 1;
    }
    {
      int dotsIndex = -1;
      for (unsigned i = numPrefixParts; i < pathParts.Size(); i++)
      {
        const UString &part = pathParts[i];
        if (part == L".." || part == L".")
          dotsIndex = i;
      }

      if (dotsIndex >= 0)
        if (dotsIndex == (int)pathParts.Size() - 1)
          numSkipParts = pathParts.Size();
        else
          numSkipParts = pathParts.Size() - 1;
    }

    for (unsigned i = 0; i < numSkipParts; i++)
    {
      {
        const UString &front = pathParts.Front();
        // WIN32 doesn't support wildcards in file names
        if (wildcardMatching)
          if (i >= numPrefixParts && DoesNameContainWildcard(front))
            break;
        prefix += front;
        prefix.Add_PathSepar();
      }
      pathParts.Delete(0);
    }
  }

  int index = FindPrefix(prefix);
  if (index < 0)
    index = Pairs.Add(CPair(prefix));

  if (pathMode != k_AbsPath)
  {
    if (pathParts.IsEmpty() || pathParts.Size() == 1 && pathParts[0].IsEmpty())
    {
      // we create universal item, if we skip all parts as prefix (like \ or L:\ )
      pathParts.Clear();
      pathParts.Add(L"*");
      forFile = true;
      wildcardMatching = true;
      recursive = false;
    }
  }

  CItem item;
  item.PathParts = pathParts;
  item.ForDir = true;
  item.ForFile = forFile;
  item.Recursive = recursive;
  item.WildcardMatching = wildcardMatching;
  Pairs[index].Head.AddItem(include, item, ignoreWildcardIndex);
}

/*
bool CCensor::CheckPath(bool isAltStream, const UString &path, bool isFile) const
{
  bool finded = false;
  FOR_VECTOR (i, Pairs)
  {
    bool include;
    if (Pairs[i].Head.CheckPath2(isAltStream, path, isFile, include))
    {
      if (!include)
        return false;
      finded = true;
    }
  }
  return finded;
}
*/

void CCensor::ExtendExclude()
{
  unsigned i;
  for (i = 0; i < Pairs.Size(); i++)
    if (Pairs[i].Prefix.IsEmpty())
      break;
  if (i == Pairs.Size())
    return;
  unsigned index = i;
  for (i = 0; i < Pairs.Size(); i++)
    if (index != i)
      Pairs[i].Head.ExtendExclude(Pairs[index].Head);
}

void CCensor::AddPathsToCensor(ECensorPathMode censorPathMode)
{
  FOR_VECTOR(i, CensorPaths)
  {
    const CCensorPath &cp = CensorPaths[i];
    AddItem(censorPathMode, cp.Include, cp.Path, cp.Recursive, cp.WildcardMatching);
  }
  CensorPaths.Clear();
}

void CCensor::AddPreItem(bool include, const UString &path, bool recursive, bool wildcardMatching)
{
  CCensorPath &cp = CensorPaths.AddNew();
  cp.Path = path;
  cp.Include = include;
  cp.Recursive = recursive;
  cp.WildcardMatching = wildcardMatching;
}

}
