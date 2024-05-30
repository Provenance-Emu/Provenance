MODULE := src/gui

MODULE_OBJS := \
        src/gui/AboutDialog.o \
        src/gui/BrowserDialog.o \
        src/gui/CheckListWidget.o \
        src/gui/ColorWidget.o \
        src/gui/ComboDialog.o \
        src/gui/CommandDialog.o \
        src/gui/CommandMenu.o \
        src/gui/ContextMenu.o \
        src/gui/DeveloperDialog.o \
        src/gui/DialogContainer.o \
        src/gui/Dialog.o \
        src/gui/EditableWidget.o \
        src/gui/EditTextWidget.o \
        src/gui/EmulationDialog.o \
        src/gui/EventMappingWidget.o \
        src/gui/FavoritesManager.o \
        src/gui/FileListWidget.o \
        src/gui/Font.o \
        src/gui/GameInfoDialog.o \
        src/gui/GlobalPropsDialog.o \
        src/gui/HelpDialog.o \
        src/gui/HighScoresDialog.o \
        src/gui/HighScoresMenu.o \
        src/gui/InputDialog.o \
        src/gui/InputTextDialog.o \
        src/gui/JoystickDialog.o \
        src/gui/LauncherDialog.o \
        src/gui/LauncherFileListWidget.o \
        src/gui/Launcher.o \
        src/gui/ListWidget.o \
        src/gui/LoggerDialog.o \
        src/gui/MessageBox.o \
        src/gui/MessageDialog.o \
        src/gui/MessageMenu.o \
        src/gui/MinUICommandDialog.o \
        src/gui/NavigationWidget.o \
        src/gui/OptionsDialog.o \
        src/gui/OptionsMenu.o \
        src/gui/PlusRomsMenu.o\
        src/gui/PlusRomsSetupDialog.o \
        src/gui/PopUpWidget.o \
        src/gui/ProgressDialog.o \
        src/gui/QuadTariDialog.o \
        src/gui/R77HelpDialog.o \
        src/gui/RadioButtonWidget.o \
        src/gui/RomAuditDialog.o \
        src/gui/RomImageWidget.o \
        src/gui/RomInfoWidget.o \
        src/gui/ScrollBarWidget.o \
        src/gui/SnapshotDialog.o \
        src/gui/StellaSettingsDialog.o \
        src/gui/StringListWidget.o \
        src/gui/TabWidget.o \
        src/gui/TimeLineWidget.o \
        src/gui/TimeMachineDialog.o \
        src/gui/TimeMachine.o \
        src/gui/ToolTip.o \
        src/gui/UndoHandler.o \
        src/gui/UIDialog.o \
        src/gui/VideoAudioDialog.o \
        src/gui/WhatsNewDialog.o \
        src/gui/Widget.o

MODULE_DIRS += \
        src/gui

# Include common rules
include $(srcdir)/common.rules
