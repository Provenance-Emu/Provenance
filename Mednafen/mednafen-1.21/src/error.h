/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* error.h:
**  Copyright (C) 2007-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef __MDFN_ERROR_H
#define __MDFN_ERROR_H

#ifdef __cplusplus

class ErrnoHolder;
class MDFN_Error : public std::exception
{
 public:

 MDFN_Error() noexcept MDFN_COLD;

 MDFN_Error(int errno_code_new, const char *format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 3, 4) MDFN_COLD;
 MDFN_Error(const ErrnoHolder &enh) MDFN_COLD;

 ~MDFN_Error() noexcept MDFN_COLD;

 MDFN_Error(const MDFN_Error &ze_error) noexcept MDFN_COLD;
 MDFN_Error & operator=(const MDFN_Error &ze_error) noexcept MDFN_COLD;

 virtual const char *what(void) const noexcept;
 int GetErrno(void) const noexcept;

 private:

 int errno_code;
 char *error_message;
};

//#define DEFMDFNERROR(name, en) struct Error_##name : public MDFN_Error { template<typename ...Z> INLINE Error_##name(Z... args) : MDFN_Error(en, args...) { } }

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

#endif

#endif
