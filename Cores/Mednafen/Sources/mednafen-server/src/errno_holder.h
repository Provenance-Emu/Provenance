#include <string.h>
#include <errno.h>

class ErrnoHolder
{
 public:

 ErrnoHolder()
 {
  //SetErrno(0);
  local_errno = 0;
  local_strerror[0] = 0;
 }

 ErrnoHolder(int the_errno)
 {
  SetErrno(the_errno);
 }

 inline int Errno(void) const
 {
  return(local_errno);
 }

 const char *StrError(void) const
 {
  return(local_strerror);
 }

 void operator=(int the_errno)
 {
  SetErrno(the_errno);
 }

 private:

 void SetErrno(int the_errno);

 int local_errno;
 char local_strerror[256];
};

