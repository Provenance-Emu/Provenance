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
//
//   Based on code from ScummVM - Scumm Interpreter
//   Copyright (C) 2002-2004 The ScummVM project
//============================================================================

#ifndef COMMAND_HXX
#define COMMAND_HXX

#include "bspf.hxx"

/**
  Allows base GUI objects to send and receive commands.

  @author  Stephen Anthony
*/
class CommandReceiver;
class CommandSender;

class CommandReceiver
{
  friend class CommandSender;

  public:
    CommandReceiver() = default;
    virtual ~CommandReceiver() = default;

  protected:
    virtual void handleCommand(CommandSender* sender, int cmd, int data, int id) { }

  private:
    // Following constructors and assignment operators not supported
    CommandReceiver(const CommandReceiver&) = delete;
    CommandReceiver(CommandReceiver&&) = delete;
    CommandReceiver& operator=(const CommandReceiver&) = delete;
    CommandReceiver& operator=(CommandReceiver&&) = delete;
};

class CommandSender
{
  // TODO - allow for multiple targets, i.e. store targets in a list
  // and add methods addTarget/removeTarget.
  public:
    CommandSender() = default;
    explicit CommandSender(CommandReceiver* target)
        : _target{target} { }

    virtual ~CommandSender() = default;

    virtual void setTarget(CommandReceiver* target) { _target = target; }
    virtual CommandReceiver* getTarget() const { return _target; }

    virtual void sendCommand(int cmd, int data, int id)
    {
      if(_target && cmd)
        _target->handleCommand(this, cmd, data, id);
	}

  protected:
    CommandReceiver* _target{nullptr};

  private:
    // Following constructors and assignment operators not supported
    CommandSender(const CommandSender&) = delete;
    CommandSender(CommandSender&&) = delete;
    CommandSender& operator=(const CommandSender&) = delete;
    CommandSender& operator=(CommandSender&&) = delete;
};

#endif
