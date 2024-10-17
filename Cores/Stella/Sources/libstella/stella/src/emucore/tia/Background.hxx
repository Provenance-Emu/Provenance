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
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef TIA_BACKGROUND
#define TIA_BACKGROUND

class TIA;

#include "Serializable.hxx"
#include "bspf.hxx"

class Background : public Serializable
{
  public:
    Background() = default;

  public:
    void setTIA(TIA* tia) { myTIA = tia; }

    void reset();

    void setColor(uInt8 color);
    void setDebugColor(uInt8 color);
    void enableDebugColors(bool enabled);

    void applyColorLoss();

    inline uInt8 getColor() const { return myColor; }

    /**
      Serializable methods (see that class for more information).
    */
    bool save(Serializer& out) const override;
    bool load(Serializer& in) override;

  private:
    void applyColors();

  private:
    uInt8 myColor{0};
    uInt8 myObjectColor{0}, myDebugColor{0};
    bool myDebugEnabled{false};

    TIA* myTIA{nullptr};

  private:
    Background(const Background&) = delete;
    Background(Background&&) = delete;
    Background& operator=(const Background&) = delete;
    Background& operator=(Background&&) = delete;
};

#endif // TIA_BACKGROUND
