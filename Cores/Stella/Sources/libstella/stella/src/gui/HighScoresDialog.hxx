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

#ifndef HIGHSCORE_DIALOG_HXX
#define HIGHSCORE_DIALOG_HXX

class CommandSender;
class DialogContainer;
class OSystem;
class EditTextWidget;
class PopUpWidget;
namespace GUI {
  class MessageBox;
}
class Serializer;

#include "OptionsMenu.hxx"
#include "Dialog.hxx"
#include "HighScoresManager.hxx"
#include "json_lib.hxx"

using json = nlohmann::json;

/**
  The dialog for displaying high scores in Stella.

  @author  Thomas Jentzsch
*/

class HighScoresDialog : public Dialog
{
  public:
    static constexpr uInt32 NUM_RANKS = 10;

    HighScoresDialog(OSystem& osystem, DialogContainer& parent,
                     int max_w, int max_h, AppMode mode);
    ~HighScoresDialog() override;

  protected:
    void loadConfig() override;
    void saveConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void updateWidgets(bool init = false);
    void handleVariation(bool init = false);
    void handlePlayedVariation();

    void deleteRank(int rank);
    bool handleDirty();

    string cartName() const;
    static string now();

    enum {
      kVariationChanged = 'Vach',
      kPrevVariation    = 'PrVr',
      kNextVariation    = 'NxVr',
      kDeleteSingle     = 'DeSi',
      kConfirmSave      = 'CfSv',
      kCancelSave       = 'CcSv'
    };

  private:
    bool myUserDefVar{false}; // allow the user to define the variation
    bool myDirty{false};
    bool myHighScoreSaved{false};  // remember if current high score was already saved
                                   // (avoids double HS)
    unique_ptr<GUI::MessageBox> myConfirmMsg;
    int _max_w{0};
    int _max_h{0};

    string myInitials;
    Int32 myEditRank{-1};
    Int32 myHighScoreRank{-1};
    string myNow;

    HSM::ScoresData myScores;

    StaticTextWidget* myGameNameWidget{nullptr};

    PopUpWidget*      myVariationPopup{nullptr};
    ButtonWidget*     myPrevVarButton{nullptr};
    ButtonWidget*     myNextVarButton{nullptr};

    StaticTextWidget* mySpecialLabelWidget{nullptr};

    StaticTextWidget* myRankWidgets[NUM_RANKS]{nullptr};
    StaticTextWidget* myScoreWidgets[NUM_RANKS]{nullptr};
    StaticTextWidget* mySpecialWidgets[NUM_RANKS]{nullptr};
    StaticTextWidget* myNameWidgets[NUM_RANKS]{nullptr};
    EditTextWidget*   myEditNameWidgets[NUM_RANKS]{nullptr};
    StaticTextWidget* myDateWidgets[NUM_RANKS]{nullptr};
    ButtonWidget*     myDeleteButtons[NUM_RANKS]{nullptr};

    StaticTextWidget* myNotesWidget{nullptr};
    StaticTextWidget* myMD5Widget{nullptr};
    StaticTextWidget* myCheckSumWidget{nullptr};

    AppMode myMode{AppMode::emulator};

  private:
    // Following constructors and assignment operators not supported
    HighScoresDialog() = delete;
    HighScoresDialog(const HighScoresDialog&) = delete;
    HighScoresDialog(HighScoresDialog&&) = delete;
    HighScoresDialog& operator=(const HighScoresDialog&) = delete;
    HighScoresDialog& operator=(HighScoresDialog&&) = delete;
};

#endif
