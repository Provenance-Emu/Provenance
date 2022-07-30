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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef CONVOLUTION_BUFFER_HXX
#define CONVOLUTION_BUFFER_HXX

#include "bspf.hxx"

class ConvolutionBuffer
{
  public:

    explicit ConvolutionBuffer(uInt32 size);

    void shift(float nextValue);

    float convoluteWith(const float* const kernel) const;

  private:

    unique_ptr<float[]> myData;

    uInt32 myFirstIndex{0};

    uInt32 mySize{0};

  private:

    ConvolutionBuffer() = delete;
    ConvolutionBuffer(const ConvolutionBuffer&) = delete;
    ConvolutionBuffer(ConvolutionBuffer&&) = delete;
    ConvolutionBuffer& operator=(const ConvolutionBuffer&) = delete;
    ConvolutionBuffer& operator=(ConvolutionBuffer&&) = delete;

};

#endif // CONVOLUTION_BUFFER_HXX
