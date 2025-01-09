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

#ifndef NAVIGATION_WIDGET_HXX
#define NAVIGATION_WIDGET_HXX

class EditTextWidget;
class FileListWidget;
namespace GUI {
  class Font;
}

#include "Widget.hxx"

class NavigationWidget : public Widget
{
  public:
    enum {
      kFolderClicked = 'flcl'
    };

  private:
    class PathWidget : public Widget
    {
      private:
        class FolderLinkWidget : public ButtonWidget
        {
          public:
            FolderLinkWidget(GuiObject* boss, const GUI::Font& font,
              int x, int y, int w, int h, string_view text, string_view path);
            ~FolderLinkWidget() override = default;

            void setPath(string_view path) { myPath = path; }
            const string& getPath() const  { return myPath; }

          private:
            void drawWidget(bool hilite) override;

          private:
            string myPath;

          private:
            // Following constructors and assignment operators not supported
            FolderLinkWidget() = delete;
            FolderLinkWidget(const FolderLinkWidget&) = delete;
            FolderLinkWidget(FolderLinkWidget&&) = delete;
            FolderLinkWidget& operator=(const FolderLinkWidget&) = delete;
            FolderLinkWidget& operator=(FolderLinkWidget&&) = delete;
        }; // FolderLinkWidget

      public:
        PathWidget(GuiObject* boss, CommandReceiver* target,
          const GUI::Font& font, int x, int y, int w, int h);
        ~PathWidget() override = default;

        void setPath(string_view path);
        const string& getPath(int idx) const;

      private:
        string myLastPath;
        std::vector<FolderLinkWidget*> myFolderList;
        CommandReceiver* myTarget{nullptr};

      private:
        // Following constructors and assignment operators not supported
        PathWidget() = delete;
        PathWidget(const PathWidget&) = delete;
        PathWidget(PathWidget&&) = delete;
        PathWidget& operator=(const PathWidget&) = delete;
        PathWidget& operator=(PathWidget&&) = delete;
    }; // PathWidget

  public:
    NavigationWidget(GuiObject* boss, const GUI::Font& font,
      int x, int y, int w, int h);
    ~NavigationWidget() override = default;

    void setWidth(int w) override;
    void setList(FileListWidget* list);
    void setVisible(bool isVisible);
    void updateUI();

  private:
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    bool              myUseMinimalUI{false};

    ButtonWidget*     myHomeButton{nullptr};
    ButtonWidget*     myPrevButton{nullptr};
    ButtonWidget*     myNextButton{nullptr};
    ButtonWidget*     myUpButton{nullptr};
    EditTextWidget*   myDir{nullptr};
    PathWidget*       myPath{nullptr};

    FileListWidget*   myList{nullptr};

  private:
    // Following constructors and assignment operators not supported
    NavigationWidget() = delete;
    NavigationWidget(const NavigationWidget&) = delete;
    NavigationWidget(NavigationWidget&&) = delete;
    NavigationWidget& operator=(const NavigationWidget&) = delete;
    NavigationWidget& operator=(NavigationWidget&&) = delete;
}; // NavigationWidget

#endif
