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

#ifndef CONTEXT_MENU_HXX
#define CONTEXT_MENU_HXX

#include "bspf.hxx"
#include "Command.hxx"
#include "Dialog.hxx"
#include "Variant.hxx"

/**
 * Popup context menu which, when clicked, "pop up" a list of items and
 * lets the user pick on of them.
 *
 * Implementation wise, when the user selects an item, then the given 'cmd'
 * is broadcast, with data being equal to the tag value of the selected entry.
 *
 * There are also several utility methods (named as sendSelectionXXX) that
 * allow to cycle through the current items without actually opening the dialog.
 */
class ContextMenu : public Dialog, public CommandSender
{
  public:
    enum {
      kItemSelectedCmd = 'CMsl'
    };

  public:
    ContextMenu(GuiObject* boss, const GUI::Font& font,
                const VariantList& items = VariantList{},
                int cmd = 0, int width = 0);
    ~ContextMenu() override = default;

    bool isShading() const override { return false; }

    /** Set the parent widget's ID */
    void setID(uInt32 id) { _id = id; }

    /** Add the given items to the widget. */
    void addItems(const VariantList& items);

    /** Show context menu onscreen at the specified coordinates */
    void show(uInt32 x, uInt32 y, const Common::Rect& bossRect, int item = -1);

    /** Select the first entry matching the given tag. */
    void setSelected(const Variant& tag, const Variant& defaultTag);

    /** Select the entry at the given index. */
    void setSelectedIndex(int idx);

    /** Select the highest/last entry in the internal list. */
    void setSelectedMax();

    /** Clear selection (reset to default). */
    void clearSelection();

    /** Accessor methods for the currently selected item. */
    int getSelected() const;
    const string& getSelectedName() const;
    void setSelectedName(string_view name);
    const Variant& getSelectedTag() const;

    /** This dialog uses its own positioning, so we override Dialog::setPosition() */
    void setPosition() override;

    /** The following methods are used when we want to select *and*
        send a command for the new selection.  They are only to be used
        when the dialog *isn't* open, and are basically a shortcut so
        that a PopUpWidget has some basic functionality without forcing
        to open its associated ContextMenu. */
    bool sendSelectionUp();
    bool sendSelectionDown();
    bool sendSelectionFirst();
    bool sendSelectionLast();

  private:
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseMoved(int x, int y) override;
    bool handleMouseClicks(int x, int y, MouseButton b) override;
    void handleMouseWheel(int x, int y, int direction) override;
    void handleKeyDown(StellaKey key, StellaMod mod, bool repeated) override;
    void handleJoyUp(int stick, int button) override;
    void handleJoyAxis(int stick, JoyAxis axis, JoyDir adir, int button) override;
    bool handleJoyHat(int stick, int hat, JoyHatDir hdir, int button) override;
    void handleEvent(Event::Type e) override;

    void setArrows();
    void drawDialog() override;

    void recalc(const Common::Rect& image);

    int findItem(int x, int y) const;
    void drawCurrentSelection(int item);

    void moveUp();
    void moveDown();
    void movePgUp();
    void movePgDown();
    void moveToFirst();
    void moveToLast();
    void moveToSelected();
    void scrollUp(int distance = 1);
    void scrollDown(int distance = 1);
    void sendSelection();

  private:
    VariantList _entries;

    int _rowHeight{0};
    int _firstEntry{0}, _numEntries{0};
    int _selectedOffset{0}, _selectedItem{-1};
    bool _showScroll{false};
    bool _isScrolling{false};
    ColorId _scrollUpColor{kColor}, _scrollDnColor{kColor};

    int _cmd{0};
    int _id{-1};

    uInt32 _xorig{0}, _yorig{0};
    int _maxWidth{0};

    int _textOfs{0};
    int _arrowSize{0};
    const uInt32* _upImg{nullptr};
    const uInt32* _downImg{nullptr};

  private:
    // Following constructors and assignment operators not supported
    ContextMenu() = delete;
    ContextMenu(const ContextMenu&) = delete;
    ContextMenu(ContextMenu&&) = delete;
    ContextMenu& operator=(const ContextMenu&) = delete;
    ContextMenu& operator=(ContextMenu&&) = delete;
};

#endif
