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

#ifndef UNDO_HANDLER_HXX
#define UNDO_HANDLER_HXX

#include "bspf.hxx"
#include <deque>

/**
 * Class for providing undo/redo functionality
 *
 * @author Thomas Jentzsch
 */
class UndoHandler
{
  public:
    UndoHandler(size_t size = 100);
    ~UndoHandler() = default;

    // Reset undo buffer
    void reset();

    // Add input to undo buffer
    void doo(string_view text);
    // Retrieve last input from undo buffer
    bool undo(string& text);
    // Retrieve next input from undo buffer
    bool redo(string& text);

    // Add single char for aggregation
    void doChar();
    // Add aggregated single chars to undo buffer
    bool endChars(string_view text);

    // Get index into text of last different character
    static uInt32 lastDiff(string_view text, string_view oldText);

  private:
    std::deque<string> myBuffer;
    // Undo buffer size
    size_t  mySize{0};
    // Aggregated single chars flag
    bool    myCharMode{false};
    // Number of chars available for redo
    uInt32  myRedoCount{0};

  private:
    // Following constructors and assignment operators not supported
    UndoHandler(const UndoHandler&) = delete;
    UndoHandler(UndoHandler&&) = delete;
    UndoHandler& operator=(const UndoHandler&) = delete;
    UndoHandler& operator=(UndoHandler&&) = delete;
};

#endif
