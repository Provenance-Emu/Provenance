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

#ifndef ROM_INFO_WIDGET_HXX
#define ROM_INFO_WIDGET_HXX

class FBSurface;
class Properties;

#include "Widget.hxx"

class RomInfoWidget : public Widget, public CommandSender
{
  public:
    enum {
      kClickedCmd = 'RIcl'
    };

  public:
    RomInfoWidget(GuiObject *boss, const GUI::Font& font,
                  int x, int y, int w, int h);
    ~RomInfoWidget() override = default;

    void setProperties(const FSNode& node, const Properties& properties,
                       bool full = true);
    void clearProperties();
    void reloadProperties(const FSNode& node);

    const string& getUrl() const { return myUrl; }

  protected:
    void drawWidget(bool hilite) override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;

  private:
    void parseProperties(const FSNode& node, bool full = true);

  private:
    // Some ROM properties info, as well as 'tEXt' chunks from the PNG image
    StringList myRomInfo;

    // The properties for the currently selected ROM
    Properties myProperties;

    // Indicates if the current properties should actually be used
    bool myHaveProperties{false};

    // Optional cart link URL
    string myUrl;

  private:
    // Following constructors and assignment operators not supported
    RomInfoWidget() = delete;
    RomInfoWidget(const RomInfoWidget&) = delete;
    RomInfoWidget(RomInfoWidget&&) = delete;
    RomInfoWidget& operator=(const RomInfoWidget&) = delete;
    RomInfoWidget& operator=(RomInfoWidget&&) = delete;
};

#endif
