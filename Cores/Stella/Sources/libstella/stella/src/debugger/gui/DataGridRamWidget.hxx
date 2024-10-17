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

#ifndef DATA_GRID_RAM_WIDGET_HXX
#define DATA_GRID_RAM_WIDGET_HXX

class RamWidget;

#include "DataGridWidget.hxx"
#include "Base.hxx"

class DataGridRamWidget : public DataGridWidget
{
  public:
    DataGridRamWidget(GuiObject* boss, const RamWidget& ram,
                      const GUI::Font& font,
                      int x, int y, int cols, int rows,
                      int colchars, int bits,
                      Common::Base::Fmt base = Common::Base::Fmt::_DEFAULT,
                      bool useScrollbar = false);
    ~DataGridRamWidget() override = default;

    string getToolTip(const Common::Point& pos) const override;

  private:
    const RamWidget& _ram;

  private:
    // Following constructors and assignment operators not supported
    DataGridRamWidget() = delete;
    DataGridRamWidget(const DataGridRamWidget&) = delete;
    DataGridRamWidget(DataGridRamWidget&&) = delete;
    DataGridRamWidget& operator=(const DataGridRamWidget&) = delete;
    DataGridRamWidget& operator=(DataGridRamWidget&&) = delete;
};

#endif
