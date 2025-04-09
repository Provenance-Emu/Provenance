#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "errno_holder.h"

static const char *srr_wrap(int ret, const char *local_strerror)
{
 if(ret == -1)
  return("ERROR IN strerror_r()!!!");

 return(local_strerror);
}

static const char *srr_wrap(const char *ret, const char *local_strerror)
{
 if(ret == NULL)
  return("ERROR IN strerror_r()!!!");

 return(ret);
}

void ErrnoHolder::SetErrno(int the_errno)
{
 local_errno = the_errno;

 if(the_errno == 0)
  local_strerror[0] = 0;
 else
 {
  #ifdef HAVE_STRERROR_R
   const char *retv;

   retv = srr_wrap(strerror_r(the_errno, local_strerror, 256), local_strerror);

   if(retv != local_strerror)
    strncpy(local_strerror, retv, 255);

  #else // No strerror_r :(

   strncpy(local_strerror, strerror(the_errno), 255);

  #endif

  local_strerror[255] = 0;
 }
}
