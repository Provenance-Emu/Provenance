/*
 *  Created by Martin on 06/03/2017.
 *
 *  Distributed under the Boost Software License, Version 1.0. (See accompanying
 *  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 */
#ifndef TWOBLUECUBES_CATCH_ERRNO_GUARD_HPP_INCLUDED
#define TWOBLUECUBES_CATCH_ERRNO_GUARD_HPP_INCLUDED

#include <cerrno>


namespace Catch {

    class ErrnoGuard {
    public:
        ErrnoGuard():m_oldErrno(errno){}
        ~ErrnoGuard() { errno = m_oldErrno; }
    private:
        int m_oldErrno;
    };

}

#endif // TWOBLUECUBES_CATCH_ERRNO_GUARD_HPP_INCLUDED
