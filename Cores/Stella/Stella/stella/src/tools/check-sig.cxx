#include <iostream>
#include <iomanip>
#include <fstream>
#include <sstream>
#include <cstring>
#include <cstdlib>
#include <list>

using namespace std;

using uInt8 = unsigned char;
using uInt32 = unsigned int;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int searchForBytes(const uInt8* image, uInt32 imagesize,
                   const uInt8* signature, uInt32 sigsize,
                   list<int>& locations)
{
  uInt32 count = 0;
  for(uInt32 i = 0; i < imagesize - sigsize; ++i)
  {
    uInt32 matches = 0;
    for(uInt32 j = 0; j < sigsize; ++j)
    {
      if(image[i+j] == signature[j])
        ++matches;
      else
        break;
    }
    if(matches == sigsize)
    {
      ++count;
      locations.push_back(i);
    }
  }

  return count;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int main(int ac, char* av[])
{
  int offset = 0;

  if(ac < 3)
  {
    cout << "usage: " << av[0] << " <filename> <hex pattern> [start address]\n";
    exit(0);
  }
  if(ac > 3)
    offset = atoi(av[3]);

  ifstream in(av[1], ios_base::binary);
  in.seekg(0, ios::end);
  int i_size = (int) in.tellg();
  in.seekg(0, ios::beg);

  unique_ptr<uInt8[]> image = make_unique<uInt8[]>(i_size);
  in.read((char*)(image.get()), i_size);
  in.close();

  int s_size = 0;
  unique_ptr<uInt8[]> sig = make_unique<uInt8[]>(strlen(av[2])/2);
  istringstream buf(av[2]);

  uInt32 c;
  while(buf >> hex >> c)
  {
    sig[s_size++] = (uInt8)c;
//    cerr << "character = " << hex << (int)sig[s_size-1] << endl;
  }
//  cerr << "sig size = " << hex << s_size << endl;

  list<int> locations;
  int result = searchForBytes(image.get()+offset, i_size-offset, sig.get(), s_size, locations);
  if(result > 0)
  {
    cout << setw(3) << result << " hits:  \'" << av[2] << "\' - \"" << av[1] << "\" @";
    for(const auto& it: locations)
      cout << ' ' << hex << (it + offset);
    cout << endl;
  }

  return 0;
}
