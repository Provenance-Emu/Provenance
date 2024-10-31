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

#include "bspf.hxx"
#include "Launcher.hxx"
#include "Bankswitch.hxx"
#include "BrowserDialog.hxx"
#include "DialogContainer.hxx"
#include "EditTextWidget.hxx"
#include "ProgressDialog.hxx"
#include "FSNode.hxx"
#include "Font.hxx"
#include "MessageBox.hxx"
#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "Props.hxx"
#include "PropsSet.hxx"
#include "Settings.hxx"
#include "RomAuditDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RomAuditDialog::RomAuditDialog(OSystem& osystem, DialogContainer& parent,
                               const GUI::Font& font, int max_w, int max_h)
  : Dialog(osystem, parent, font, "Audit ROMs"),
    myMaxWidth{max_w},
    myMaxHeight{max_h}
{
  const int lineHeight   = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = Dialog::buttonWidth("Audit path" + ELLIPSIS),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
  const int lwidth = font.getStringWidth("ROMs without properties (skipped) ");
  const int xpos = HBORDER + buttonWidth + fontWidth;
  int ypos = _th + VBORDER;
  WidgetArray wid;

  // Set real dimensions
  _w = 64 * fontWidth + HBORDER * 2;
  _h = _th + VBORDER * 2 + buttonHeight * 2 + lineHeight * 3 + VGAP * 10;

  // Audit path
  auto* romButton = new ButtonWidget(this, font, HBORDER, ypos,
      buttonWidth, buttonHeight, "Audit path" + ELLIPSIS, kChooseAuditDirCmd);
  wid.push_back(romButton);
  myRomPath = new EditTextWidget(this, font, xpos, ypos + (buttonHeight - lineHeight) / 2 - 1,
                                 _w - xpos - HBORDER, lineHeight);
  wid.push_back(myRomPath);

  // Show results of ROM audit
  ypos += buttonHeight + VGAP * 4;
  new StaticTextWidget(this, font, HBORDER, ypos, "ROMs with properties (renamed) ");
  myResults1 = new EditTextWidget(this, font, HBORDER + lwidth, ypos - 2,
                                  fontWidth * 6, lineHeight);
  myResults1->setEditable(false, true);
  ypos += buttonHeight;
  new StaticTextWidget(this, font, HBORDER, ypos, "ROMs without properties (skipped) ");
  myResults2 = new EditTextWidget(this, font, HBORDER + lwidth, ypos - 2,
                                  fontWidth * 6, lineHeight);
  myResults2->setEditable(false, true);

  ypos += buttonHeight + VGAP * 2;
  new StaticTextWidget(this, font, HBORDER, ypos, "(*) WARNING: Operation cannot be undone!");

  // Add OK and Cancel buttons
  addOKCancelBGroup(wid, font, "Audit", "Close");
  addBGroupToFocusList(wid);

  setHelpAnchor("ROMAudit");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RomAuditDialog::~RomAuditDialog()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomAuditDialog::loadConfig()
{
  const string& currentdir =
    instance().launcher().currentDir().getShortPath();
  const string& path = currentdir.empty() ?
    instance().settings().getString("romdir") : currentdir;

  myRomPath->setText(path);
  myResults1->setText("");
  myResults2->setText("");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomAuditDialog::auditRoms()
{
  const string& auditPath = myRomPath->getText();
  myResults1->setText("");
  myResults2->setText("");

  const FSNode node(auditPath);
  FSList files;
  files.reserve(2048);
  node.getChildren(files, FSNode::ListMode::FilesOnly);

  // Create a progress dialog box to show the progress of processing
  // the ROMs, since this is usually a time-consuming operation
  ostringstream buf;
  ProgressDialog progress(this, instance().frameBuffer().font());

  buf << "Auditing ROM files" << ELLIPSIS;
  progress.setMessage(buf.str());
  progress.setRange(0, static_cast<int>(files.size()) - 1, 5);
  progress.open();

  Properties props;
  uInt32 renamed = 0, notfound = 0;
  for(uInt32 idx = 0; idx < files.size() && !progress.isCancelled(); ++idx)
  {
    string extension;
    if(files[idx].isFile() &&
       Bankswitch::isValidRomName(files[idx], extension))
    {
      bool renameSucceeded = false;

      // Calculate the MD5 so we can get the rest of the info
      // from the PropertiesSet (stella.pro)
      const string& md5 = OSystem::getROMMD5(files[idx]);
      if(instance().propSet().getMD5(md5, props))
      {
        const string& name = props.get(PropType::Cart_Name);

        // Only rename the file if we found a valid properties entry
        if(!name.empty() && name != files[idx].getName())
        {
          string newfile = node.getPath();
          newfile.append(name).append(".").append(extension);
          if(files[idx].getPath() != newfile && files[idx].rename(newfile))
            renameSucceeded = true;
        }
      }
      if(renameSucceeded)
        ++renamed;
      else
        ++notfound;
    }

    // Update the progress bar, indicating one more ROM has been processed
    progress.incProgress();
  }
  progress.close();

  myResults1->setText(std::to_string(renamed));
  myResults2->setText(std::to_string(notfound));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomAuditDialog::handleCommand(CommandSender* sender, int cmd,
                                   int data, int id)
{
  switch (cmd)
  {
    case GuiObject::kOKCmd:
      if(!myConfirmMsg)
      {
        StringList msg;
        msg.emplace_back("This operation cannot be undone.  Your ROMs");
        msg.emplace_back("will be modified, and as such there is a chance");
        msg.emplace_back("that files may be lost.  You are recommended");
        msg.emplace_back("to back up your files before proceeding.");
        msg.emplace_back("");
        msg.emplace_back("If you're sure you want to proceed with the");
        msg.emplace_back("audit, click 'OK', otherwise click 'Cancel'.");
        myConfirmMsg = make_unique<GUI::MessageBox>
          (this, _font, msg, myMaxWidth, myMaxHeight, kConfirmAuditCmd,
          "OK", "Cancel", "ROM Audit", false);
      }
      myConfirmMsg->show();
      break;

    case kConfirmAuditCmd:
      auditRoms();
      instance().launcher().reload();
      break;

    case kChooseAuditDirCmd:
      BrowserDialog::show(this, _font, "Select ROM Directory to Audit",
                          myRomPath->getText(),
                          BrowserDialog::Mode::Directories,
                          [this](bool OK, const FSNode& node) {
                            if(OK) {
                              myRomPath->setText(node.getShortPath());
                              myResults1->setText("");
                              myResults2->setText("");
                            }
                          });
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
      break;
  }
}
