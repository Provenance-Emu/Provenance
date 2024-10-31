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

#include "ScrollBarWidget.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "StellaKeys.hxx"
#include "Version.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "DebuggerDialog.hxx"
#include "DebuggerParser.hxx"
#include "EventHandler.hxx"

#include "PromptWidget.hxx"
#include "CartDebug.hxx"

#define PROMPT  "> "

// Uncomment the following to give full-line cut/copy/paste
// Note that this will be removed eventually, when we implement proper cut/copy/paste
#define PSEUDO_CUT_COPY_PASTE

// TODO: Github issue #361
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PromptWidget::PromptWidget(GuiObject* boss, const GUI::Font& font,
                           int x, int y, int w, int h)
  : Widget(boss, font, x, y, w - ScrollBarWidget::scrollBarWidth(font), h),
    CommandSender(boss)
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_CLEARBG | Widget::FLAG_RETAIN_FOCUS |
           Widget::FLAG_WANTS_TAB | Widget::FLAG_WANTS_RAWDATA;
  _textcolor = kTextColor;
  _bgcolor = kWidColor;
  _bgcolorlo = kDlgColor;

  _kConsoleCharWidth  = font.getMaxCharWidth();
  _kConsoleCharHeight = font.getFontHeight();
  _kConsoleLineHeight = _kConsoleCharHeight + 2;

  // Calculate depending values
  _lineWidth = (_w - ScrollBarWidget::scrollBarWidth(_font) - 2) / _kConsoleCharWidth;
  _linesPerPage = (_h - 2) / _kConsoleLineHeight;
  _linesInBuffer = kBufferSize / _lineWidth;

  // Add scrollbar
  _scrollBar = new ScrollBarWidget(boss, font, _x + _w, _y,
                                   ScrollBarWidget::scrollBarWidth(_font), _h);
  _scrollBar->setTarget(this);
  _scrollStopLine = INT_MAX;

  clearScreen();

  addFocusWidget(this);
  setHelpAnchor("PromptTab", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::drawWidget(bool hilite)
{
//cerr << "PromptWidget::drawWidget\n";
  ColorId fgcolor{}, bgcolor{};
  FBSurface& s = _boss->dialog().surface();

  // Draw text
  const int start = _scrollLine - _linesPerPage + 1;
  int y = _y + 2;

  for (int line = 0; line < _linesPerPage; ++line)
  {
    int x = _x + 1;
    for (int column = 0; column < _lineWidth; ++column) {
      const int c = buffer((start + line) * _lineWidth + column);

      if(c & (1 << 17))  // inverse video flag
      {
        fgcolor = _bgcolor;
        bgcolor = static_cast<ColorId>((c & 0x1ffff) >> 8);
        s.fillRect(x, y, _kConsoleCharWidth, _kConsoleCharHeight, bgcolor);
      }
      else
        fgcolor = static_cast<ColorId>(c >> 8);

      s.drawChar(_font, c & 0x7f, x, y, fgcolor);
      x += _kConsoleCharWidth;
    }
    y += _kConsoleLineHeight;
  }

  // Draw the caret
  drawCaret();

  // Draw the scrollbar
  _scrollBar->draw();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
//  cerr << "PromptWidget::handleMouseDown\n";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::handleMouseWheel(int x, int y, int direction)
{
  _scrollBar->handleMouseWheel(x, y, direction);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::printPrompt()
{
  const string watches = instance().debugger().showWatches();
  if(!watches.empty())
    print(watches);

  print(PROMPT);
  _promptStartPos = _promptEndPos = _currentPos;

  resetFunctions();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PromptWidget::handleText(char text)
{
  if(text >= 0)
  {
    // FIXME - convert this class to inherit from EditableWidget
    for(int i = _promptEndPos - 1; i >= _currentPos; i--)
      buffer(i + 1) = buffer(i);
    _promptEndPos++;
    putcharIntern(text);
    scrollToCurrent();

    resetFunctions();
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PromptWidget::handleKeyDown(StellaKey key, StellaMod mod)
{
  bool handled = true,
    dirty = true,
    changeInput = false,
    resetAutoComplete = true,
    resetHistoryScroll = true;

  // Uses normal edit events + special prompt events
  Event::Type event = instance().eventHandler().eventForKey(EventMode::kEditMode, key, mod);
  if(event == Event::NoType)
    event = instance().eventHandler().eventForKey(EventMode::kPromptMode, key, mod);

  switch(event)
  {
    case Event::EndEdit:
    {
      if(_scrollLine < _currentPos / _lineWidth)
      {
        // Scroll page by page when not at cursor position:
        _scrollLine += _linesPerPage;
        if(_scrollLine > _promptEndPos / _lineWidth)
          _scrollLine = _promptEndPos / _lineWidth;
        updateScrollBuffer();
        break;
      }
      if(execute())
        return true;
      printPrompt();
      break;
    }

    // special events (auto complete & history scrolling)
    case Event::UINavNext:
      dirty = changeInput = autoComplete(+1);
      resetAutoComplete = false;
      break;

    case Event::UINavPrev:
      dirty = changeInput = autoComplete(-1);
      resetAutoComplete = false;
      break;

    case Event::UILeft: // mapped to KBDK_DOWN by default
      dirty = changeInput = historyScroll(-1);
      resetHistoryScroll = false;
      break;

    case Event::UIRight: // mapped to KBDK_UP by default
      dirty = changeInput = historyScroll(+1);
      resetHistoryScroll = false;
      break;

    // input modifying events
    case Event::Backspace:
      if(_currentPos > _promptStartPos)
      {
        killChar(-1);
        changeInput = true;
      }
      scrollToCurrent();
      break;

    case Event::Delete:
      killChar(+1);
      changeInput = true;
      break;

    case Event::DeleteEnd:
      killLine(+1);
      changeInput = true;
      break;

    case Event::DeleteHome:
      killLine(-1);
      changeInput = true;
      break;

    case Event::DeleteLeftWord:
      killWord();
      changeInput = true;
      break;

    case Event::Cut:
      textCut();
      changeInput = true;
      break;

    case Event::Copy:
      textCopy();
      break;

    case Event::Paste:
      textPaste();
      changeInput = true;
      break;

    // cursor events
    case Event::MoveHome:
      _currentPos = _promptStartPos;
      break;

    case Event::MoveEnd:
      _currentPos = _promptEndPos;
      break;

    case Event::MoveRightChar:
      if(_currentPos < _promptEndPos)
        _currentPos++;
      else
        handled = false;
      break;

    case Event::MoveLeftChar:
      if(_currentPos > _promptStartPos)
        _currentPos--;
      else
        handled = false;
      break;

    // scrolling events
    case Event::UIUp:
      if(_scrollLine <= _firstLineInBuffer + _linesPerPage - 1)
        break;

      _scrollLine -= 1;
      updateScrollBuffer();
      break;

    case Event::UIDown:
      // Don't scroll down when at bottom of buffer
      if(_scrollLine >= _promptEndPos / _lineWidth)
        break;

      _scrollLine += 1;
      updateScrollBuffer();
      break;

    case Event::UIPgUp:
      // Don't scroll up when at top of buffer
      if(_scrollLine < _linesPerPage)
        break;

      _scrollLine -= _linesPerPage - 1;
      if(_scrollLine < _firstLineInBuffer + _linesPerPage - 1)
        _scrollLine = _firstLineInBuffer + _linesPerPage - 1;
      updateScrollBuffer();
      break;

    case Event::UIPgDown:
      // Don't scroll down when at bottom of buffer
      if(_scrollLine >= _promptEndPos / _lineWidth)
        break;

      _scrollLine += _linesPerPage - 1;
      if(_scrollLine > _promptEndPos / _lineWidth)
        _scrollLine = _promptEndPos / _lineWidth;
      updateScrollBuffer();
      break;

    case Event::UIHome:
      _scrollLine = _firstLineInBuffer + _linesPerPage - 1;
      updateScrollBuffer();
      break;

    case Event::UIEnd:
      _scrollLine = _promptEndPos / _lineWidth;
      if(_scrollLine < _linesPerPage - 1)
        _scrollLine = _linesPerPage - 1;
      updateScrollBuffer();
      break;

    default:
      handled = false;
      dirty = false;
      break;
  }

  // Take care of changes made above
  if(dirty)
    setDirty();

  // Reset special event handling if input has changed
  // We assume that non-handled events will modify the input too
  if(!handled || (resetAutoComplete && changeInput))
    _tabCount = -1;
  if(!handled || (resetHistoryScroll && changeInput))
    _historyLine = 0;

  return handled;
}

#if 0
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::insertIntoPrompt(const char* str)
{
  Int32 l = (Int32)strlen(str);
  for(Int32 i = _promptEndPos - 1; i >= _currentPos; i--)
    buffer(i + l) = buffer(i);

  for(Int32 j = 0; j < l; ++j)
  {
    _promptEndPos++;
    putcharIntern(str[j]);
  }
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::handleCommand(CommandSender* sender, int cmd,
                                 int data, int id)
{
  if(cmd == GuiObject::kSetPositionCmd)
  {
    const int newPos = data + _linesPerPage - 1 + _firstLineInBuffer;
    if (newPos != _scrollLine)
    {
      _scrollLine = newPos;
      setDirty();
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::loadConfig()
{
  // Show the prompt the first time we draw this widget
  if(_firstTime)
  {
    _firstTime = false;

    // Display greetings & prompt
    const string version = string("Stella ") + STELLA_VERSION + "\n";
    print(version);
    print(PROMPT);

    // Take care of one-time debugger stuff
    // fill the history from the saved breaks, traps and watches commands
    StringList history;
    print(instance().debugger().autoExec(&history));
    for(const auto& h: history)
      addToHistory(h.c_str());

    history.clear();
    print(instance().debugger().cartDebug().loadConfigFile() + "\n");
    print(instance().debugger().cartDebug().loadListFile() + "\n");
    print(instance().debugger().cartDebug().loadSymbolFile() + "\n");

    bool extra = false;
    if(instance().settings().getBool("dbg.autosave"))
    {
      print(DebuggerParser::inverse(" autoSave enabled "));
      print("\177 "); // must switch inverse here!
      extra = true;
    }
    if(instance().settings().getBool("dbg.logbreaks"))
    {
      print(DebuggerParser::inverse(" logBreaks enabled "));
      extra = true;
    }
    if(instance().settings().getBool("dbg.logtrace"))
    {
      print(DebuggerParser::inverse(" logTrace enabled "));
      extra = true;
    }
    if(extra)
      print("\n");

    print(PROMPT);

    _promptStartPos = _promptEndPos = _currentPos;
    _exitedEarly = false;
  }
  else if(_exitedEarly)
  {
    printPrompt();
    _exitedEarly = false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int PromptWidget::getWidth() const
{
  return _w + ScrollBarWidget::scrollBarWidth(_font);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::killChar(int direction)
{
  if(direction == -1)    // Delete previous character (backspace)
  {
    if(_currentPos <= _promptStartPos)
      return;

    _currentPos--;
    for (int i = _currentPos; i < _promptEndPos; i++)
      buffer(i) = buffer(i + 1);

    buffer(_promptEndPos) = ' ';
    _promptEndPos--;
  }
  else if(direction == 1)    // Delete next character (delete)
  {
    if(_currentPos >= _promptEndPos)
      return;

    // There are further characters to the right of cursor
    if(_currentPos + 1 <= _promptEndPos)
    {
      for (int i = _currentPos; i < _promptEndPos; i++)
        buffer(i) = buffer(i + 1);

      buffer(_promptEndPos) = ' ';
      _promptEndPos--;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::killLine(int direction)
{
  if(direction == -1)  // erase from current position to beginning of line
  {
    const int count = _currentPos - _promptStartPos;
    if(count > 0)
      for (int i = 0; i < count; i++)
       killChar(-1);
  }
  else if(direction == 1)  // erase from current position to end of line
  {
    for (int i = _currentPos; i < _promptEndPos; i++)
      buffer(i) = ' ';

    _promptEndPos = _currentPos;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::killWord()
{
  int cnt = 0;
  bool space = true;
  while (_currentPos > _promptStartPos)
  {
    if ((buffer(_currentPos - 1) & 0xff) == ' ')
    {
      if (!space)
        break;
    }
    else
      space = false;

    _currentPos--;
    cnt++;
  }

  for (int i = _currentPos; i < _promptEndPos; i++)
    buffer(i) = buffer(i + cnt);

  buffer(_promptEndPos) = ' ';
  _promptEndPos -= cnt;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string PromptWidget::getLine()
{
#if defined(PSEUDO_CUT_COPY_PASTE)
  assert(_promptEndPos >= _promptStartPos);
  string text;

  // Copy current line to text
  for(int i = _promptStartPos; i < _promptEndPos; i++)
    text += buffer(i) & 0x7f;

  return text;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::textCut()
{
#if defined(PSEUDO_CUT_COPY_PASTE)
  textCopy();

  // Remove the current line
  _currentPos = _promptStartPos;
  killLine(1);  // to end of line
  _promptEndPos = _currentPos;

  resetFunctions();
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::textCopy()
{
#if defined(PSEUDO_CUT_COPY_PASTE)
  instance().eventHandler().copyText(getLine());
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::textPaste()
{
#if defined(PSEUDO_CUT_COPY_PASTE)
  string text;

  // Remove the current line
  _currentPos = _promptStartPos;
  killLine(1);  // to end of line

  instance().eventHandler().pasteText(text);
  print(text);
  _promptEndPos = _currentPos;

  resetFunctions();
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int PromptWidget::historyDir(int& index, int direction)
{
  index += direction;
  if(index < 0)
    index += static_cast<int>(_history.size());
  else
    index %= static_cast<int>(_history.size());

  return index;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::historyAdd(string_view entry)
{
  if(_historyIndex >= static_cast<int>(_history.size()))
    _history.emplace_back(entry);
  else
    _history[_historyIndex] = entry;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::addToHistory(const char* str)
{
  // Do not add duplicates, remove old duplicate
  if(!_history.empty())
  {
    int i = _historyIndex;
    const int historyEnd = _historyIndex % _history.size();

    do
    {
      historyDir(i, -1);

      if(!BSPF::compareIgnoreCase(_history[i], str))
      {
        int j = i;

        do
        {
          const int prevJ = j;
          historyDir(j, +1);
          _history[prevJ] = _history[j];
        }
        while(j != historyEnd);

        historyDir(_historyIndex, -1);
        break;
      }
    }
    while(i != historyEnd);
  }
  historyAdd(str);
  _historyLine = 0; // reset history scroll
  _historyIndex = (_historyIndex + 1) % kHistorySize;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PromptWidget::historyScroll(int direction)
{
  if(_history.empty())
    return false;

  // add current input temporarily to history
  if(_historyLine == 0)
    historyAdd(getLine());

  // Advance to the next/prev line in the history
  historyDir(_historyLine, direction);

  // Search the history using the original input
  do
  {
    const int idx = _historyLine
      ? (_historyIndex - _historyLine + _history.size()) % static_cast<int>(_history.size())
      : _historyIndex;

    if(BSPF::startsWithIgnoreCase(_history[idx], _history[_historyIndex]))
      break;

    // Advance to the next/prev line in the history
    historyDir(_historyLine, direction);
  }
  while(_historyLine); // If _historyLine == 0, nothing was found

  // Remove the current user text
  _currentPos = _promptStartPos;
  killLine(1);  // to end of line

  // ... and ensure the prompt is visible
  scrollToCurrent();

  // Print the text from the history
  const int idx = _historyLine
    ? (_historyIndex - _historyLine + _history.size()) % static_cast<int>(_history.size())
    : _historyIndex;

  for(int i = 0; i < kLineBufferSize && _history[idx][i] != '\0'; i++)
    putcharIntern(_history[idx][i]);
  _promptEndPos = _currentPos;

  // Ensure once more the caret is visible (in case of very long history entries)
  scrollToCurrent();

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PromptWidget::execute()
{
  nextLine();

  assert(_promptEndPos >= _promptStartPos);
  const int len = _promptEndPos - _promptStartPos;

  if(len > 0)
  {
    // Copy the user input to command
    const string command = getLine();

    // Add the input to the history
    addToHistory(command.c_str());

    // Pass the command to the debugger, and print the result
    const string result = instance().debugger().run(command);

    // This is a bit of a hack
    // Certain commands remove the debugger dialog from underneath us,
    // so we shouldn't print any messages
    // Those commands will return '_EXIT_DEBUGGER' as their result
    if(result == "_EXIT_DEBUGGER")
    {
      _exitedEarly = true;
      return true;
    }
    else if(result == "_NO_PROMPT")
      return true;
    else if(!result.empty())
      print(result + "\n");
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PromptWidget::autoComplete(int direction)
{
  // Tab completion: we complete either commands or labels, but not
  // both at once.

  if(_currentPos <= _promptStartPos)
    return false; // no input

  scrollToCurrent();

  int len = _promptEndPos - _promptStartPos;

  if(_tabCount != -1)
    len = static_cast<int>(strlen(_inputStr));
  if(len > kLineBufferSize - 1)
    len = kLineBufferSize - 1;

  int lastDelimPos = -1;
  char delimiter = '\0';

  for(int i = 0; i < len; i++)
  {
    // copy the input at first tab press only
    if(_tabCount == -1)
      _inputStr[i] = buffer(_promptStartPos + i) & 0x7f;
    // whitespace characters
    if(strchr("{*@<> =[]()+-/&|!^~%", _inputStr[i]))
    {
      lastDelimPos = i;
      delimiter = _inputStr[i];
    }
}
  if(_tabCount == -1)
    _inputStr[len] = '\0';

  StringList list;

  if(lastDelimPos == -1)
    // no delimiters, do only command completion:
    DebuggerParser::getCompletions(_inputStr, list);
  else
  {
    const size_t strLen = len - lastDelimPos - 1;
    // do not show ALL commands/labels without any filter as it makes no sense
    if(strLen > 0)
    {
      // Special case for 'help' command
      if(BSPF::startsWithIgnoreCase(_inputStr, "help"))
        DebuggerParser::getCompletions(_inputStr + lastDelimPos + 1, list);
      else
      {
        // we got a delimiter, so this must be a label or a function
        const Debugger& dbg = instance().debugger();

        dbg.cartDebug().getCompletions(_inputStr + lastDelimPos + 1, list);
        dbg.getCompletions(_inputStr + lastDelimPos + 1, list);
      }
    }

  }
  if(list.empty())
    return false;
  sort(list.begin(), list.end());

  if(direction < 0)
  {
    if(--_tabCount < 0)
      _tabCount = static_cast<int>(list.size()) - 1;
  }
  else
    _tabCount = (_tabCount + 1) % list.size();

  nextLine();
  _currentPos = _promptStartPos;
  killLine(1);  // kill whole line

  // start with-autocompleted, fixed string...
  for(int i = 0; i < lastDelimPos; i++)
    putcharIntern(_inputStr[i]);
  if(lastDelimPos > 0)
    putcharIntern(delimiter);

  // ...and add current autocompletion string
  print(list[_tabCount]);
  putcharIntern(' ');
  _promptEndPos = _currentPos;

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::nextLine()
{
  // Reset colors every line, so I don't have to remember to do it myself
  _textcolor = kTextColor;
  _inverse = false;

  const int line = _currentPos / _lineWidth;
  if (line == _scrollLine && _scrollLine < _scrollStopLine)
    _scrollLine++;

  _currentPos = (line + 1) * _lineWidth;

  updateScrollBuffer();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Call this (at least) when the current line changes or when a new line is added
void PromptWidget::updateScrollBuffer()
{
  const int lastchar = std::max(_promptEndPos, _currentPos),
            line = lastchar / _lineWidth,
            numlines = (line < _linesInBuffer) ? line + 1 : _linesInBuffer,
            firstline = line - numlines + 1;

  if (firstline > _firstLineInBuffer)
  {
    // clear old line from buffer
    for (int i = lastchar; i < (line+1) * _lineWidth; ++i)
      buffer(i) = ' ';

    _firstLineInBuffer = firstline;
  }

  _scrollBar->_numEntries = numlines;
  _scrollBar->_currentPos = _scrollBar->_numEntries - (line - _scrollLine + _linesPerPage);
  _scrollBar->_entriesPerPage = _linesPerPage;
  _scrollBar->recalc();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// TODO: rewrite this (cert-dcl50-cpp)
int PromptWidget::printf(const char* format, ...)  // NOLINT
{
  va_list argptr;

  va_start(argptr, format);
  const int count = this->vprintf(format, argptr);
  va_end (argptr);
  return count;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int PromptWidget::vprintf(const char* format, va_list argptr)
{
  char buf[2048];  // NOLINT  (will be rewritten soon)
  const int count = std::vsnprintf(buf, sizeof(buf), format, argptr);

  print(buf);
  return count;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::putcharIntern(int c)
{
  if (c == '\n')
    nextLine();
  else if(c & 0x80) { // set foreground color to TIA color
                      // don't print or advance cursor
    _textcolor = static_cast<ColorId>((c & 0x7f) << 1);
  }
  else if(c && c < 0x1e) { // first actual character is large dash
    // More colors (the regular GUI ones)
    _textcolor = static_cast<ColorId>(c + 0x100);
  }
  else if(c == 0x7f) { // toggle inverse video (DEL char)
    _inverse = !_inverse;
  }
  else if(isprint(c) || c == 0x1e || c == 0x1f) // graphic bits chars
  {
    buffer(_currentPos) = c | (_textcolor << 8) | (_inverse << 17);
    _currentPos++;
    if ((_scrollLine + 1) * _lineWidth == _currentPos
        && _scrollLine < _scrollStopLine)
    {
      _scrollLine++;
      updateScrollBuffer();
    }
  }
  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::print(string_view str)
{
  // limit scrolling of long text output
  _scrollStopLine = _currentPos / _lineWidth + _linesPerPage - 1;
  for(const auto c : str)
    putcharIntern(c);
  _scrollStopLine = INT_MAX;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::drawCaret()
{
//cerr << "PromptWidget::drawCaret()\n";
  FBSurface& s = _boss->dialog().surface();
  const int line = _currentPos / _lineWidth;

  // Don't draw the cursor if it's not in the current view
  if(_scrollLine < line)
    return;

  const int displayLine = line - _scrollLine + _linesPerPage - 1,
                          x = _x + 1 + (_currentPos % _lineWidth) * _kConsoleCharWidth,
                          y = _y + displayLine * _kConsoleLineHeight;

  const char c = buffer(_currentPos); //FIXME: int to char??
  s.fillRect(x, y, _kConsoleCharWidth, _kConsoleLineHeight, kTextColor);
  s.drawChar(_font, c, x, y + 2, kBGColor);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::scrollToCurrent()
{
  const int line = _promptEndPos / _lineWidth;

  if (line + _linesPerPage <= _scrollLine)
  {
    // TODO - this should only occur for long edit lines, though
  }
  else if (line > _scrollLine)
  {
    _scrollLine = line;
    updateScrollBuffer();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string PromptWidget::saveBuffer(const FSNode& file)
{
  stringstream out;
  for(int start = 0; start < _promptStartPos; start += _lineWidth)
  {
    int end = start + _lineWidth - 1;

    // Look for first non-space, printing char from end of line
    while(static_cast<char>(_buffer[end] & 0xff) <= ' ' && end >= start)
      end--;

    // Spit out the line minus its trailing junk
    // Strip off any color/inverse bits
    for(int j = start; j <= end; ++j)
      out << static_cast<char>(_buffer[j] & 0xff);

    out << '\n';
  }

  try {
    if(file.write(out) > 0)
      return "saved " + file.getShortPath() + " OK";
    else
      return "unable to save session";
  }
  catch(...) {
    return "unable to save session";
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::clearScreen()
{
  // Initialize start position
  _currentPos = 0;
  _scrollLine = _linesPerPage - 1;
  _firstLineInBuffer = 0;
  _promptStartPos = _promptEndPos = -1;
  memset(_buffer, 0, kBufferSize * sizeof(int));

  if(!_firstTime)
    updateScrollBuffer();

  resetFunctions();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::clearHistory()
{
  _history.clear();
  _historyIndex = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PromptWidget::resetFunctions()
{
  // reset special functions
  _tabCount = -1;
  _historyLine = 0;
}
