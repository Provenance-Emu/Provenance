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

#ifndef SNAPSHOT_DIALOG_HXX
#define SNAPSHOT_DIALOG_HXX

class OSystem;
class GuiObject;
class DialogContainer;
class CheckboxWidget;
class EditTextWidget;
class SliderWidget;
class StaticTextWidget;

#include "Dialog.hxx"
#include "Command.hxx"

class SnapshotDialog : public Dialog
{
  public:
    SnapshotDialog(OSystem& osystem, DialogContainer& parent,
                   const GUI::Font& font, int max_w, int max_h);
    ~SnapshotDialog() override = default;

  private:
    void loadConfig() override;
    void saveConfig() override;
    void setDefaults() override;

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    enum {
      kChooseSnapSaveDirCmd = 'LOss', // snapshot dir (save files)
      kSnapshotInterval     = 'SnIn'  // snap chosen (load files)
    };

    // Config paths
    EditTextWidget* mySnapSavePath{nullptr};

    CheckboxWidget* mySnapName{nullptr};
    SliderWidget* mySnapInterval{nullptr};

    CheckboxWidget* mySnapSingle{nullptr};
    CheckboxWidget* mySnap1x{nullptr};

  private:
    // Following constructors and assignment operators not supported
    SnapshotDialog() = delete;
    SnapshotDialog(const SnapshotDialog&) = delete;
    SnapshotDialog(SnapshotDialog&&) = delete;
    SnapshotDialog& operator=(const SnapshotDialog&) = delete;
    SnapshotDialog& operator=(SnapshotDialog&&) = delete;
};

#endif
