/*
 *  Created by Phil on 25/2/2012.
 *  Copyright 2012 Two Blue Cubes Ltd. All rights reserved.
 *
 *  Distributed under the Boost Software License, Version 1.0. (See accompanying
 *  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 */
#ifndef TWOBLUECUBES_CATCH_CONSOLE_COLOUR_HPP_INCLUDED
#define TWOBLUECUBES_CATCH_CONSOLE_COLOUR_HPP_INCLUDED

#include "catch_common.h"

namespace Catch {

    struct Colour {
        enum Code {
            None = 0,

            White,
            Red,
            Green,
            Blue,
            Cyan,
            Yellow,
            Grey,

            Bright = 0x10,

            BrightRed = Bright | Red,
            BrightGreen = Bright | Green,
            LightGrey = Bright | Grey,
            BrightWhite = Bright | White,

            // By intention
            FileName = LightGrey,
            Warning = Yellow,
            ResultError = BrightRed,
            ResultSuccess = BrightGreen,
            ResultExpectedFailure = Warning,

            Error = BrightRed,
            Success = Green,

            OriginalExpression = Cyan,
            ReconstructedExpression = Yellow,

            SecondaryText = LightGrey,
            Headers = White
        };

        // Use constructed object for RAII guard
        Colour( Code _colourCode );
        Colour( Colour const& other );
        ~Colour();

        // Use static method for one-shot changes
        static void use( Code _colourCode );

    private:
        bool m_moved;
    };

    inline std::ostream& operator << ( std::ostream& os, Colour const& ) { return os; }

} // end namespace Catch

#endif // TWOBLUECUBES_CATCH_CONSOLE_COLOUR_HPP_INCLUDED
