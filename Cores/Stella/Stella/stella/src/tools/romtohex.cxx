/**
  Simple program that produces a hex list of a binary object file

  @author  Bradford W. Mott
*/

#include <iomanip>
#include <fstream>
#include <iostream>
#include <cstdlib>
using namespace std;

using uInt8 = unsigned char;
using uInt32 = unsigned int;

int main(int ac, char* av[])
{
  if(ac < 2)
  {
    cout << av[0] << " <INPUT_FILE> [values per line = 8] [startpos = 0]" << endl
         << endl
         << "  Read data from INPUT_FILE, and convert to unsigned char" << endl
         << "  (in hex format), writing to standard output." << endl
         << endl;
    return 0;
  }

  int values_per_line = ac >= 3 ? atoi(av[2]) : 8;
  int offset = ac >= 4 ? atoi(av[3]) : 0;

  ifstream in(av[1]);
  if(in.is_open())
  {
    in.seekg(0, ios::end);
    int len = (int)in.tellg();
    in.seekg(0, ios::beg);

    unique_ptr<uInt8[]> data = make_unique<uInt8[]>(len);
    in.read((char*)data.get(), len);
    in.close();

    cout << "SIZE = " << len << endl << "  ";

    // Skip first 'offset' bytes; they shouldn't be used
    for(int t = offset; t < len; ++t)
    {
      cout << "0x" << setw(2) << setfill('0') << hex << (int)data[t];
      if(t < len - 1)
        cout << ", ";
      if(((t-offset) % values_per_line) == (values_per_line-1))
        cout << endl << "  ";
    }
    cout << endl;
  }
}
