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

#ifndef EDITABLE_WIDGET_HXX
#define EDITABLE_WIDGET_HXX

#include <functional>

#include "Widget.hxx"
#include "Rect.hxx"
#include "ContextMenu.hxx"
#include "UndoHandler.hxx"

/**
 * Base class for widgets which need to edit text, like ListWidget and
 * EditTextWidget.
 *
 * Widgets wishing to enforce their own editing restrictions are able
 * to use a 'TextFilter' as described below.
 */
class EditableWidget : public Widget, public CommandSender
{
  public:
    /** Function used to test if a specified character can be inserted
        into the internal buffer */
    using TextFilter = std::function<bool(char)>;

    enum {
      kAcceptCmd  = 'EDac',
      kCancelCmd  = 'EDcl',
      kChangedCmd = 'EDch'
    };

  public:
    EditableWidget(GuiObject* boss, const GUI::Font& font,
                   int x, int y, int w, int h, string_view str = "");
    ~EditableWidget() override = default;

    virtual void setText(string_view str, bool changed = false);
    void setMaxLen(int len) { _maxLen = len; }
    const string& getText() const { return _editString; }

    bool isEditable() const	{ return _editable; }
    bool isChanged() { return editString() != backupString(); }
    virtual void setEditable(bool editable, bool hiliteBG = false);

    bool handleText(char text) override;
    bool handleKeyDown(StellaKey key, StellaMod mod) override;

    // We only want to focus this widget when we can edit its contents
    bool wantsFocus() const override { return _editable; }

    // Set filter used to test whether a character can be inserted
    void setTextFilter(const TextFilter& filter) { _filter = filter; }

  protected:
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseMoved(int x, int y) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    virtual int caretOfs() const { return _editScrollOffset; }
    int toCaretPos(int x) const;

    void receivedFocusWidget() override;
    void lostFocusWidget() override;
    void tick() override;
    bool wantsToolTip() const override;

    virtual void startEditMode() { setFlags(Widget::FLAG_WANTS_RAWDATA);   }
    virtual void endEditMode()   {
      clearFlags(Widget::FLAG_WANTS_RAWDATA);
      commit();
    }
    virtual void abortEditMode()
    {
      clearFlags(Widget::FLAG_WANTS_RAWDATA);
      abort();
    }
    void commit() { _backupString = _editString; }
    void abort()  { setText(_backupString); }

    virtual Common::Rect getEditRect() const = 0;
    virtual int getCaretOffset() const;
    void drawCaretSelection();
    bool setCaretPos(int newPos);
    bool moveCaretPos(int direction);
    bool adjustOffset();

    // This method is used internally by child classes wanting to
    // access/edit the internal buffer
    string& editString() { return _editString; }
    string& backupString() { return _backupString; }
    string selectString() const;
    void resetSelection() { _selectSize = 0; }
    int scrollOffset() const;

  private:
    // Line editing
    bool killChar(int direction, bool addEdit = true);
    bool killLine(int direction);
    bool killWord(int direction);
    bool moveWord(int direction, bool select);
    bool markWord();

    bool killSelectedText(bool addEdit = true);
    int selectStartPos() const;
    int selectEndPos() const;
    // Clipboard
    bool cutSelectedText();
    bool copySelectedText();
    bool pasteSelectedText();

    // Use the current TextFilter to insert a character into the
    // internal buffer
    bool tryInsertChar(char c, int pos);

    ContextMenu& mouseMenu();

  private:
    unique_ptr<ContextMenu> myMouseMenu;
    bool    _isDragging{false};

    bool   _editable{true};
    string _editString;
    string _backupString;
    int    _maxLen{0};
    unique_ptr<UndoHandler> myUndoHandler;

    int    _caretPos{0};
    int    _caretTimer{0};
    bool   _caretEnabled{true};

    // Size of current selected text
    //    0 = no selection
    //   <0 = selected left of caret
    //   >0 = selected right of caret
    int    _selectSize{0};

  protected:
    int   _editScrollOffset{0};
    bool  _editMode{true};
    int   _dyText{0};

  private:
    TextFilter _filter;

  private:
    // Following constructors and assignment operators not supported
    EditableWidget() = delete;
    EditableWidget(const EditableWidget&) = delete;
    EditableWidget(EditableWidget&&) = delete;
    EditableWidget& operator=(const EditableWidget&) = delete;
    EditableWidget& operator=(EditableWidget&&) = delete;
};

#endif
