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
#include "Base.hxx"
#include "Control.hxx"
#include "Cart.hxx"
#include "CartDPC.hxx"
#include "Dialog.hxx"
#include "BrowserDialog.hxx"
#include "OSystem.hxx"
#include "EditTextWidget.hxx"
#include "PopUpWidget.hxx"
#include "ColorWidget.hxx"
#include "Console.hxx"
#include "PaletteHandler.hxx"
#include "TIA.hxx"
#include "Settings.hxx"
#include "Sound.hxx"
#include "AudioSettings.hxx"
#include "Widget.hxx"
#include "Font.hxx"
#include "TabWidget.hxx"
#include "NTSCFilter.hxx"
#include "TIASurface.hxx"

#include "VideoAudioDialog.hxx"

#define CREATE_CUSTOM_SLIDERS(obj, desc, cmd)                            \
  myTV ## obj =                                                          \
    new SliderWidget(myTab, _font, xpos, ypos-1, swidth, lineHeight,     \
                     desc, lwidth, cmd, fontWidth*4, "%");               \
  myTV ## obj->setMinValue(0); myTV ## obj->setMaxValue(100);            \
  myTV ## obj->setStepValue(1);                                          \
  myTV ## obj->setTickmarkIntervals(2);                                  \
  wid.push_back(myTV ## obj);                                            \
  ypos += lineHeight + VGAP;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VideoAudioDialog::VideoAudioDialog(OSystem& osystem, DialogContainer& parent,
                         const GUI::Font& font, int max_w, int max_h)
  : Dialog(osystem, parent, font, "Video & Audio settings")
{
  const int lineHeight   = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();

  // Set real dimensions
  setSize(44 * fontWidth + HBORDER * 2 + PopUpWidget::dropDownWidth(font) * 2,
          _th + VGAP * 5 + lineHeight + 11 * (lineHeight + VGAP) + buttonHeight + VBORDER * 3,
          max_w, max_h);

  // The tab widget
  constexpr int xpos = 2;
  const int ypos = VGAP;
  myTab = new TabWidget(this, font, xpos, ypos + _th,
                        _w - 2*xpos,
                        _h - _th - VGAP - buttonHeight - VBORDER * 2);
  addTabWidget(myTab);

  addDisplayTab();
  addPaletteTab();
  addTVEffectsTab();
#ifdef IMAGE_SUPPORT
  addBezelTab();
#endif
  addAudioTab();

  // Add Defaults, OK and Cancel buttons
  WidgetArray wid;
  addDefaultsOKCancelBGroup(wid, _font);
  addBGroupToFocusList(wid);

  // Activate the first tab
  myTab->setActiveTab(0);

  setHelpAnchor("VideoAudio");

  // Disable certain functions when we know they aren't present
#ifndef WINDOWED_SUPPORT
  myFullscreen->clearFlags(Widget::FLAG_ENABLED);
  myUseStretch->clearFlags(Widget::FLAG_ENABLED);
  myTVOverscan->clearFlags(Widget::FLAG_ENABLED);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::addDisplayTab()
{
  const GUI::Font& ifont = instance().frameBuffer().infoFont();
  const int lineHeight = Dialog::lineHeight(),
            fontHeight = Dialog::fontHeight(),
            fontWidth  = Dialog::fontWidth(),
            VBORDER    = Dialog::vBorder(),
            HBORDER    = Dialog::hBorder(),
            VGAP       = Dialog::vGap();
  const int INDENT = CheckboxWidget::prefixSize(_font);
  const int lwidth = _font.getStringWidth("V-Size adjust "),
            pwidth = _font.getStringWidth("Direct3D 12");
  const int xpos = HBORDER;
  int ypos = VBORDER;
  WidgetArray wid;
  const int tabID = myTab->addTab(" Display ", TabWidget::AUTO_WIDTH);

  // Video renderer
  myRenderer = new PopUpWidget(myTab, _font, xpos, ypos, pwidth, lineHeight,
                               instance().frameBuffer().supportedRenderers(),
                               "Renderer ", lwidth, kRendererChanged);
  myRenderer->setToolTip("Select renderer used for displaying screen.");
  wid.push_back(myRenderer);
  const int swidth = myRenderer->getWidth() - lwidth;
  ypos += lineHeight + VGAP;

  // TIA interpolation
  myTIAInterpolate = new CheckboxWidget(myTab, _font, xpos, ypos + 1, "Interpolation ");
  myTIAInterpolate->setToolTip("Blur emulated display.", Event::ToggleInter);
  wid.push_back(myTIAInterpolate);

  ypos += lineHeight + VGAP * 4;
  // TIA zoom levels (will be dynamically filled later)
  myTIAZoom = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                               "Zoom ", lwidth, 0, fontWidth * 4, "%");
  myTIAZoom->setMinValue(200); myTIAZoom->setStepValue(FrameBuffer::ZOOM_STEPS * 100);
  myTIAZoom->setToolTip(Event::VidmodeDecrease, Event::VidmodeIncrease);
  wid.push_back(myTIAZoom);
  ypos += lineHeight + VGAP;

  // Fullscreen
  myFullscreen = new CheckboxWidget(myTab, _font, xpos, ypos + 1, "Fullscreen", kFullScreenChanged);
  myFullscreen->setToolTip(Event::ToggleFullScreen);
  wid.push_back(myFullscreen);
  ypos += lineHeight + VGAP;

  // FS stretch
  myUseStretch = new CheckboxWidget(myTab, _font, xpos + INDENT, ypos + 1, "Stretch");
  myUseStretch->setToolTip("Stretch emulated display to fill whole screen.");
  wid.push_back(myUseStretch);

#ifdef ADAPTABLE_REFRESH_SUPPORT
  // Adapt refresh rate
  ypos += lineHeight + VGAP;
  myRefreshAdapt = new CheckboxWidget(myTab, _font, xpos + INDENT, ypos + 1, "Adapt display refresh rate");
  myRefreshAdapt->setToolTip("Select optimal display refresh rate for each ROM.", Event::ToggleAdaptRefresh);
  wid.push_back(myRefreshAdapt);
#else
  myRefreshAdapt = nullptr;
#endif

  // FS overscan
  ypos += lineHeight + VGAP;
  myTVOverscan = new SliderWidget(myTab, _font, xpos + INDENT, ypos - 1, swidth, lineHeight,
                                  "Overscan", lwidth - INDENT, kOverscanChanged, fontWidth * 3, "%");
  myTVOverscan->setMinValue(0); myTVOverscan->setMaxValue(10);
  myTVOverscan->setTickmarkIntervals(2);
  myTVOverscan->setToolTip(Event::OverscanDecrease, Event::OverscanIncrease);
  wid.push_back(myTVOverscan);

  // Aspect ratio correction
  ypos += lineHeight + VGAP * 4;
  myCorrectAspect = new CheckboxWidget(myTab, _font, xpos, ypos + 1, "Correct aspect ratio (*)");
  myCorrectAspect->setToolTip("Uncheck to disable real world aspect ratio correction.",
    Event::ToggleCorrectAspectRatio);
  wid.push_back(myCorrectAspect);

  // Vertical size
  ypos += lineHeight + VGAP;
  myVSizeAdjust =
    new SliderWidget(myTab, _font, xpos, ypos-1, swidth, lineHeight,
                     "V-Size adjust", lwidth, kVSizeChanged, fontWidth * 7, "%", 0, true);
  myVSizeAdjust->setMinValue(-5); myVSizeAdjust->setMaxValue(5);
  myVSizeAdjust->setTickmarkIntervals(2);
  myVSizeAdjust->setToolTip("Adjust vertical size to match emulated TV display.",
    Event::VSizeAdjustDecrease, Event::VSizeAdjustIncrease);
  wid.push_back(myVSizeAdjust);


  // Add message concerning usage
  ypos = myTab->getHeight() - fontHeight - ifont.getFontHeight() - VGAP - VBORDER;
  const int iwidth =
    ifont.getStringWidth("(*) Change may require an application restart");
  new StaticTextWidget(myTab, ifont, xpos, ypos,
                       std::min(iwidth, _w - HBORDER * 2), ifont.getFontHeight(),
                       "(*) Change may require an application restart");

  // Add items for tab 0
  addToFocusList(wid, myTab, tabID);

  myTab->parentWidget(tabID)->setHelpAnchor("VideoAudioDisplay");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::addPaletteTab()
{
  const int lineHeight = Dialog::lineHeight(),
            fontWidth  = Dialog::fontWidth(),
            VBORDER    = Dialog::vBorder(),
            HBORDER    = Dialog::hBorder(),
            VGAP       = Dialog::vGap(),
            INDENT     = Dialog::indent();
  const int lwidth = _font.getStringWidth("  NTSC phase ");
  const int pwidth = _font.getStringWidth("Standard");
  int xpos = HBORDER,
      ypos = VBORDER;
  WidgetArray wid;
  VariantList items;
  const int tabID = myTab->addTab(" Palettes ", TabWidget::AUTO_WIDTH);

  // TIA Palette
  items.clear();
  VarList::push_back(items, "Standard", PaletteHandler::SETTING_STANDARD);
  VarList::push_back(items, "z26", PaletteHandler::SETTING_Z26);
  if (instance().checkUserPalette())
    VarList::push_back(items, "User", PaletteHandler::SETTING_USER);
  VarList::push_back(items, "Custom", PaletteHandler::SETTING_CUSTOM);
  myTIAPalette = new PopUpWidget(myTab, _font, xpos, ypos, pwidth,
                                 lineHeight, items, "Palette ", lwidth, kPaletteChanged);
  myTIAPalette->setToolTip(Event::PaletteDecrease, Event::PaletteIncrease);
  wid.push_back(myTIAPalette);
  ypos += lineHeight + VGAP;

  const int swidth = myTIAPalette->getWidth() - lwidth;
  const int plWidth = _font.getStringWidth("NTSC phase ");
  const int pswidth = swidth - INDENT + lwidth - plWidth;
  xpos += INDENT;

  myPhaseShift =
    new SliderWidget(myTab, _font, xpos, ypos - 1, pswidth, lineHeight,
                     "NTSC phase", plWidth, kPhaseShiftChanged, fontWidth * 5);
  wid.push_back(myPhaseShift);
  ypos += lineHeight + VGAP;

  const int rgblWidth = _font.getStringWidth("R ");
  const int rgbsWidth = (myTIAPalette->getWidth() - INDENT - rgblWidth - fontWidth * 5) / 2;

  myTVRedScale =
    new SliderWidget(myTab, _font, xpos, ypos - 1, rgbsWidth, lineHeight,
                     "R", rgblWidth, kPaletteUpdated, fontWidth * 4, "%");
  myTVRedScale->setMinValue(0);
  myTVRedScale->setMaxValue(100);
  myTVRedScale->setTickmarkIntervals(2);
  myTVRedScale->setToolTip("Adjust red saturation of 'Custom' palette.");
  wid.push_back(myTVRedScale);

  const int xposr = myTIAPalette->getRight() - rgbsWidth;
  myTVRedShift =
    new SliderWidget(myTab, _font, xposr, ypos - 1, rgbsWidth, lineHeight,
                     "", 0, kRedShiftChanged, fontWidth * 6);
  myTVRedShift->setMinValue((PaletteHandler::DEF_RGB_SHIFT - PaletteHandler::MAX_RGB_SHIFT) * 10);
  myTVRedShift->setMaxValue((PaletteHandler::DEF_RGB_SHIFT + PaletteHandler::MAX_RGB_SHIFT) * 10);
  myTVRedShift->setTickmarkIntervals(2);
  myTVRedShift->setToolTip("Adjust red shift of 'Custom' palette.");
  wid.push_back(myTVRedShift);
  ypos += lineHeight + VGAP;

  myTVGreenScale =
    new SliderWidget(myTab, _font, xpos, ypos - 1, rgbsWidth, lineHeight,
                     "G", rgblWidth, kPaletteUpdated, fontWidth * 4, "%");
  myTVGreenScale->setMinValue(0);
  myTVGreenScale->setMaxValue(100);
  myTVGreenScale->setTickmarkIntervals(2);
  myTVGreenScale->setToolTip("Adjust green saturation of 'Custom' palette.");
  wid.push_back(myTVGreenScale);

  myTVGreenShift =
    new SliderWidget(myTab, _font, xposr, ypos - 1, rgbsWidth, lineHeight,
                     "", 0, kGreenShiftChanged, fontWidth * 6);
  myTVGreenShift->setMinValue((PaletteHandler::DEF_RGB_SHIFT - PaletteHandler::MAX_RGB_SHIFT) * 10);
  myTVGreenShift->setMaxValue((PaletteHandler::DEF_RGB_SHIFT + PaletteHandler::MAX_RGB_SHIFT) * 10);
  myTVGreenShift->setTickmarkIntervals(2);
  myTVGreenShift->setToolTip("Adjust green shift of 'Custom' palette.");
  wid.push_back(myTVGreenShift);
  ypos += lineHeight + VGAP;

  myTVBlueScale =
    new SliderWidget(myTab, _font, xpos, ypos - 1, rgbsWidth, lineHeight,
                     "B", rgblWidth, kPaletteUpdated, fontWidth * 4, "%");
  myTVBlueScale->setMinValue(0);
  myTVBlueScale->setMaxValue(100);
  myTVBlueScale->setTickmarkIntervals(2);
  myTVBlueScale->setToolTip("Adjust blue saturation of 'Custom' palette.");
  wid.push_back(myTVBlueScale);

  myTVBlueShift =
    new SliderWidget(myTab, _font, xposr, ypos - 1, rgbsWidth, lineHeight,
                     "", 0, kBlueShiftChanged, fontWidth * 6);
  myTVBlueShift->setMinValue((PaletteHandler::DEF_RGB_SHIFT - PaletteHandler::MAX_RGB_SHIFT) * 10);
  myTVBlueShift->setMaxValue((PaletteHandler::DEF_RGB_SHIFT + PaletteHandler::MAX_RGB_SHIFT) * 10);
  myTVBlueShift->setTickmarkIntervals(2);
  myTVBlueShift->setToolTip("Adjust blue shift of 'Custom' palette.");
  wid.push_back(myTVBlueShift);
  ypos += lineHeight + VGAP * 2;
  xpos -= INDENT;

  CREATE_CUSTOM_SLIDERS(Hue, "Hue ", kPaletteUpdated)
  CREATE_CUSTOM_SLIDERS(Satur, "Saturation ", kPaletteUpdated)
  CREATE_CUSTOM_SLIDERS(Contrast, "Contrast ", kPaletteUpdated)
  CREATE_CUSTOM_SLIDERS(Bright, "Brightness ", kPaletteUpdated)
  CREATE_CUSTOM_SLIDERS(Gamma, "Gamma ", kPaletteUpdated)

  ypos += VGAP;
  auto* s = new StaticTextWidget(myTab, _font, xpos, ypos + 1, "Autodetection");

  myDetectPal60 = new CheckboxWidget(myTab, _font, s->getRight() + fontWidth * 2, ypos + 1, "PAL-60");
  myDetectPal60 ->setToolTip("Enable autodetection of PAL-60 based on colors used.");
  wid.push_back(myDetectPal60 );

  myDetectNtsc50 = new CheckboxWidget(myTab, _font, myDetectPal60->getRight() + fontWidth * 2, ypos + 1, "NTSC-50");
  myDetectNtsc50 ->setToolTip("Enable autodetection of NTSC-50 based on colors used.");
  wid.push_back(myDetectNtsc50 );

  // The resulting palette
  xpos = myPhaseShift->getRight() + fontWidth * 2;
  addPalette(xpos, VBORDER, _w - 2 * 2 - HBORDER - xpos,
             myTVGamma->getBottom() -  myTIAPalette->getTop());

  // Add items for tab 1
  addToFocusList(wid, myTab, tabID);

  myTab->parentWidget(tabID)->setHelpAnchor("VideoAudioPalettes");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::addTVEffectsTab()
{
  const int lineHeight   = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = Dialog::buttonWidth("Clone Bad Adjust"),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
  const int INDENT = CheckboxWidget::prefixSize(_font);// fontWidth * 2;
  int xpos = HBORDER,
      ypos = VBORDER;
  const int lwidth = _font.getStringWidth("Saturation ");
  int pwidth = _font.getStringWidth("Bad adjust  ");
  WidgetArray wid;
  VariantList items;
  const int tabID = myTab->addTab("TV Effects", TabWidget::AUTO_WIDTH);

  items.clear();
  VarList::push_back(items, "Disabled", static_cast<uInt32>(NTSCFilter::Preset::OFF));
  VarList::push_back(items, "RGB", static_cast<uInt32>(NTSCFilter::Preset::RGB));
  VarList::push_back(items, "S-Video", static_cast<uInt32>(NTSCFilter::Preset::SVIDEO));
  VarList::push_back(items, "Composite", static_cast<uInt32>(NTSCFilter::Preset::COMPOSITE));
  VarList::push_back(items, "Bad adjust", static_cast<uInt32>(NTSCFilter::Preset::BAD));
  VarList::push_back(items, "Custom", static_cast<uInt32>(NTSCFilter::Preset::CUSTOM));
  myTVMode = new PopUpWidget(myTab, _font, xpos, ypos, pwidth, lineHeight,
                             items, "TV mode ", 0, kTVModeChanged);
  myTVMode->setToolTip(Event::PreviousVideoMode, Event::NextVideoMode);
  wid.push_back(myTVMode);
  ypos += lineHeight + VGAP;

  // Custom adjustables (using macro voodoo)
  const int swidth = myTVMode->getWidth() - INDENT - lwidth;
  xpos += INDENT;

  CREATE_CUSTOM_SLIDERS(Sharp, "Sharpness ", 0)
  CREATE_CUSTOM_SLIDERS(Res, "Resolution ", 0)
  CREATE_CUSTOM_SLIDERS(Artifacts, "Artifacts ", 0)
  CREATE_CUSTOM_SLIDERS(Fringe, "Fringing ", 0)
  CREATE_CUSTOM_SLIDERS(Bleed, "Bleeding ", 0)

  ypos += VGAP * 3;
  xpos = HBORDER;

  // TV Phosphor effect
  items.clear();
  VarList::push_back(items, "by ROM", PhosphorHandler::VALUE_BYROM);
  VarList::push_back(items, "always", PhosphorHandler::VALUE_ALWAYS);
  VarList::push_back(items, "auto on", PhosphorHandler::VALUE_AUTO_ON);
  VarList::push_back(items, "auto on/off", PhosphorHandler::VALUE_AUTO);
  myTVPhosphor = new PopUpWidget(myTab, _font, xpos, ypos,
                                 _font.getStringWidth("auto on/off"), lineHeight,
                                 items, "Phosphor ", 0, kPhosphorChanged);
  myTVPhosphor->setToolTip(Event::PhosphorModeDecrease, Event::PhosphorModeIncrease);
  wid.push_back(myTVPhosphor);
  ypos += lineHeight + VGAP / 2;

  // TV Phosphor blend level
  xpos += INDENT;
  CREATE_CUSTOM_SLIDERS(PhosLevel, "Blend", kPhosBlendChanged)
  ypos += VGAP;

  // Scanline intensity and interpolation
  xpos -= INDENT;
  myTVScanLabel = new StaticTextWidget(myTab, _font, xpos, ypos, "Scanlines:");
  ypos += lineHeight + VGAP / 2;

  xpos += INDENT;
  CREATE_CUSTOM_SLIDERS(ScanIntense, "Intensity", kScanlinesChanged)
  myTVScanIntense->setToolTip(Event::ScanlinesDecrease, Event::ScanlinesIncrease);

  items.clear();
  VarList::push_back(items, "Standard", TIASurface::SETTING_STANDARD);
  VarList::push_back(items, "Thin lines", TIASurface::SETTING_THIN);
  VarList::push_back(items, "Pixelated", TIASurface::SETTING_PIXELS);
  VarList::push_back(items, "Aperture Gr.", TIASurface::SETTING_APERTURE);
  VarList::push_back(items, "MAME", TIASurface::SETTING_MAME);

  xpos = myTVScanIntense->getRight() + fontWidth * 2;
  pwidth = _w - HBORDER - xpos - fontWidth * 5 - PopUpWidget::dropDownWidth(_font) - 2 * 2;
  myTVScanMask = new PopUpWidget(myTab, _font, xpos,
    myTVScanIntense->getTop() + 1, pwidth, lineHeight, items, "Mask ");
  myTVScanMask->setToolTip(Event::PreviousScanlineMask, Event::NextScanlineMask);
  wid.push_back(myTVScanMask);

  // Create buttons in 2nd column
  xpos = _w - HBORDER - 2 * 2 - buttonWidth;
  ypos = VBORDER - VGAP / 2;

  // Adjustable presets
#define CREATE_CLONE_BUTTON(obj, desc)                                 \
  myClone ## obj =                                                     \
    new ButtonWidget(myTab, _font, xpos, ypos, buttonWidth, buttonHeight,\
                     desc, kClone ## obj ##Cmd);                       \
  wid.push_back(myClone ## obj);                                       \
  ypos += buttonHeight + VGAP;

  ypos += VGAP;
  CREATE_CLONE_BUTTON(RGB, "Clone RGB")
  CREATE_CLONE_BUTTON(Svideo, "Clone S-Video")
  CREATE_CLONE_BUTTON(Composite, "Clone Composite")
  CREATE_CLONE_BUTTON(Bad, "Clone Bad adjust")
  CREATE_CLONE_BUTTON(Custom, "Revert")

  // Add items for tab 2
  addToFocusList(wid, myTab, tabID);

  myTab->parentWidget(tabID)->setHelpAnchor("VideoAudioEffects");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::addBezelTab()
{
  const int lineHeight = Dialog::lineHeight(),
            buttonHeight = Dialog::buttonHeight(),
            fontWidth = Dialog::fontWidth(),
            VBORDER = Dialog::vBorder(),
            HBORDER = Dialog::hBorder(),
            VGAP = Dialog::vGap();
  const int INDENT = CheckboxWidget::prefixSize(_font);
  int xpos = HBORDER,
      ypos = VBORDER;
  WidgetArray wid;
  const int tabID = myTab->addTab(" Bezels ", TabWidget::AUTO_WIDTH);

  // Enable bezels
  myBezelEnableCheckbox = new CheckboxWidget(myTab, _font, xpos, ypos,
                                             "Enable bezels", kBezelEnableChanged);
  myBezelEnableCheckbox->setToolTip(Event::ToggleBezel);
  wid.push_back(myBezelEnableCheckbox);
  xpos += INDENT;
  ypos += lineHeight + VGAP;

  // Bezel path
  const int bwidth = _font.getStringWidth("Bezel path" + ELLIPSIS) + fontWidth * 2 + 1;
  myOpenBrowserButton = new ButtonWidget(myTab, _font, xpos, ypos, bwidth, buttonHeight,
                                         "Bezel path" + ELLIPSIS, kChooseBezelDirCmd);
  myOpenBrowserButton->setToolTip("Select path for bezels.");
  wid.push_back(myOpenBrowserButton);

  myBezelPath = new EditTextWidget(myTab, _font, xpos + bwidth + fontWidth,
                                   ypos + (buttonHeight - lineHeight) / 2 - 1,
                                   _w - xpos - bwidth - fontWidth - HBORDER - 2, lineHeight, "");
  wid.push_back(myBezelPath);

  ypos += lineHeight + VGAP * 3;
  myBezelShowWindowed = new CheckboxWidget(myTab, _font, xpos, ypos,
                                           "Windowed modes");
  myBezelShowWindowed->setToolTip("Enable bezels in windowed modes as well.");
  wid.push_back(myBezelShowWindowed);

  // Disable auto borders
  ypos += lineHeight + VGAP * 1;
  myManualWindow = new CheckboxWidget(myTab, _font, xpos, ypos,
                                      "Manual emulation window", kAutoWindowChanged);
  myManualWindow->setToolTip("Enable if automatic window detection fails.");
  wid.push_back(myManualWindow);
  xpos += INDENT;

  const int lWidth = _font.getStringWidth("Bottom ");
  const int sWidth = myBezelPath->getRight() - xpos - lWidth - 4.5 * fontWidth; // _w - HBORDER - xpos - lwidth;
  ypos += lineHeight + VGAP * 1;
  myWinLeftSlider = new SliderWidget(myTab, _font, xpos, ypos, sWidth, lineHeight,
                                     "Left   ", 0, 0, 4 * fontWidth, "%");
  myWinLeftSlider->setMinValue(0); myWinLeftSlider->setMaxValue(40);
  myWinLeftSlider->setTickmarkIntervals(4);
  wid.push_back(myWinLeftSlider);

  ypos += lineHeight + VGAP * 1;
  myWinRightSlider = new SliderWidget(myTab, _font, xpos, ypos, sWidth, lineHeight,
                                      "Right  ", 0, 0, 4 * fontWidth, "%");
  myWinRightSlider->setMinValue(0); myWinRightSlider->setMaxValue(40);
  myWinRightSlider->setTickmarkIntervals(4);
  wid.push_back(myWinRightSlider);

  ypos += lineHeight + VGAP * 1;
  myWinTopSlider = new SliderWidget(myTab, _font, xpos, ypos, sWidth, lineHeight,
                                    "Top    ", 0, 0, 4 * fontWidth, "%");
  myWinTopSlider->setMinValue(0); myWinTopSlider->setMaxValue(40);
  myWinTopSlider->setTickmarkIntervals(4);
  wid.push_back(myWinTopSlider);

  ypos += lineHeight + VGAP;
  myWinBottomSlider = new SliderWidget(myTab, _font, xpos, ypos, sWidth, lineHeight,
                                       "Bottom ", 0, 0, 4 * fontWidth, "%");
  myWinBottomSlider->setMinValue(0); myWinBottomSlider->setMaxValue(40);
  myWinBottomSlider->setTickmarkIntervals(4);
  wid.push_back(myWinBottomSlider);

  // Add items for tab 3

  myTab->parentWidget(tabID)->setHelpAnchor("VideoAudioBezels");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::addAudioTab()
{
  const int lineHeight = Dialog::lineHeight(),
            fontWidth  = Dialog::fontWidth(),
            VBORDER    = Dialog::vBorder(),
            HBORDER    = Dialog::hBorder(),
            VGAP       = Dialog::vGap();
  const int INDENT = CheckboxWidget::prefixSize(_font);
  int lwidth = _font.getStringWidth("Volume "), pwidth = 0;
  WidgetArray wid;
  VariantList items;
  const int tabID = myTab->addTab(" Audio ", TabWidget::AUTO_WIDTH);

  int xpos = HBORDER, ypos = VBORDER;

  // Enable sound
  mySoundEnableCheckbox = new CheckboxWidget(myTab, _font, xpos, ypos,
                                             "Enable sound", kSoundEnableChanged);
  mySoundEnableCheckbox->setToolTip(Event::SoundToggle);
  wid.push_back(mySoundEnableCheckbox);
  ypos += lineHeight + VGAP;
  xpos += INDENT;

  // Volume
  myVolumeSlider = new SliderWidget(myTab, _font, xpos, ypos,
                                    "Volume", lwidth, 0, 4 * fontWidth, "%");
  myVolumeSlider->setMinValue(1); myVolumeSlider->setMaxValue(100);
  myVolumeSlider->setTickmarkIntervals(4);
  myVolumeSlider->setToolTip(Event::VolumeDecrease, Event::VolumeIncrease);
  wid.push_back(myVolumeSlider);
  ypos += lineHeight + VGAP;

  // Device
  myDevicePopup = new PopUpWidget(myTab, _font, xpos, ypos,
                                  _w - xpos - lwidth - HBORDER - PopUpWidget::dropDownWidth(_font) - 2, lineHeight,
                                  instance().sound().supportedDevices(),
                                  "Device", lwidth, kDeviceChanged);
  wid.push_back(myDevicePopup);
  ypos += lineHeight + VGAP;

  // Mode
  items.clear();
  VarList::push_back(items, "Low quality, medium lag", static_cast<int>(AudioSettings::Preset::lowQualityMediumLag));
  VarList::push_back(items, "High quality, medium lag", static_cast<int>(AudioSettings::Preset::highQualityMediumLag));
  VarList::push_back(items, "High quality, low lag", static_cast<int>(AudioSettings::Preset::highQualityLowLag));
  VarList::push_back(items, "Ultra quality, minimal lag", static_cast<int>(AudioSettings::Preset::ultraQualityMinimalLag));
  VarList::push_back(items, "Custom", static_cast<int>(AudioSettings::Preset::custom));
  myModePopup = new PopUpWidget(myTab, _font, xpos, ypos,
                                _font.getStringWidth("Ultra quality, minimal lag"), lineHeight,
                                items, "Mode", lwidth, kModeChanged);
  wid.push_back(myModePopup);
  ypos += lineHeight + VGAP;
  xpos += INDENT;

  // Fragment size
  lwidth = _font.getStringWidth("Resampling quality ");
  pwidth = myModePopup->getRight() - xpos - lwidth - PopUpWidget::dropDownWidth(_font);
  items.clear();
  VarList::push_back(items, "128 samples", 128);
  VarList::push_back(items, "256 samples", 256);
  VarList::push_back(items, "512 samples", 512);
  VarList::push_back(items, "1k samples", 1024);
  VarList::push_back(items, "2k samples", 2048);
  VarList::push_back(items, "4K samples", 4096);
  myFragsizePopup = new PopUpWidget(myTab, _font, xpos, ypos,
                                    pwidth, lineHeight,
                                    items, "Fragment size", lwidth);
  wid.push_back(myFragsizePopup);
  ypos += lineHeight + VGAP;

  // Output frequency
  items.clear();
  VarList::push_back(items, "44100 Hz", 44100);
  VarList::push_back(items, "48000 Hz", 48000);
  VarList::push_back(items, "96000 Hz", 96000);
  myFreqPopup = new PopUpWidget(myTab, _font, xpos, ypos,
                                pwidth, lineHeight,
                                items, "Sample rate", lwidth);
  wid.push_back(myFreqPopup);
  ypos += lineHeight + VGAP;

  // Resampling quality
  items.clear();
  VarList::push_back(items, "Low", static_cast<int>(AudioSettings::ResamplingQuality::nearestNeightbour));
  VarList::push_back(items, "High", static_cast<int>(AudioSettings::ResamplingQuality::lanczos_2));
  VarList::push_back(items, "Ultra", static_cast<int>(AudioSettings::ResamplingQuality::lanczos_3));
  myResamplingPopup = new PopUpWidget(myTab, _font, xpos, ypos,
                                      pwidth, lineHeight,
                                      items, "Resampling quality ", lwidth);
  wid.push_back(myResamplingPopup);
  ypos += lineHeight + VGAP;

  // Param 1
  int swidth = pwidth + PopUpWidget::dropDownWidth(_font);
  myHeadroomSlider = new SliderWidget(myTab, _font, xpos, ypos, swidth, lineHeight,
                                      "Headroom           ", 0, kHeadroomChanged, 10 * fontWidth);
  myHeadroomSlider->setMinValue(0); myHeadroomSlider->setMaxValue(AudioSettings::MAX_HEADROOM);
  myHeadroomSlider->setTickmarkIntervals(5);
  wid.push_back(myHeadroomSlider);
  ypos += lineHeight + VGAP;

  // Param 2
  myBufferSizeSlider = new SliderWidget(myTab, _font, xpos, ypos, swidth, lineHeight,
                                        "Buffer size        ", 0, kBufferSizeChanged, 10 * fontWidth);
  myBufferSizeSlider->setMinValue(0); myBufferSizeSlider->setMaxValue(AudioSettings::MAX_BUFFER_SIZE);
  myBufferSizeSlider->setTickmarkIntervals(5);
  wid.push_back(myBufferSizeSlider);
  ypos += lineHeight + VGAP;

  // Stereo sound
  xpos -= INDENT;
  myStereoSoundCheckbox = new CheckboxWidget(myTab, _font, xpos, ypos,
                                             "Stereo for all ROMs");
  wid.push_back(myStereoSoundCheckbox);
  ypos += lineHeight + VGAP;

  swidth += INDENT - fontWidth * 4;
  myDpcPitch = new SliderWidget(myTab, _font, xpos, ypos, swidth, lineHeight,
                                "Pitfall II music pitch ", 0, 0, 5 * fontWidth);
  myDpcPitch->setMinValue(10000); myDpcPitch->setMaxValue(30000);
  myDpcPitch->setStepValue(100);
  myDpcPitch->setTickmarkIntervals(2);
  wid.push_back(myDpcPitch);

  // Add items for tab 4
  addToFocusList(wid, myTab, tabID);

  myTab->parentWidget(tabID)->setHelpAnchor("VideoAudioAudio");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::loadConfig()
{
  const Settings& settings = instance().settings();

  // Display tab
  // Renderer settings
  myRenderer->setSelected(settings.getString("video"), "default");
  handleRendererChanged();

  // TIA interpolation
  myTIAInterpolate->setState(settings.getBool("tia.inter"));

  // TIA zoom levels
  // These are dynamically loaded, since they depend on the size of
  // the desktop and which renderer we're using
  const float minZoom = instance().frameBuffer().supportedTIAMinZoom(); // or 2 if we allow lower values
  const float maxZoom = instance().frameBuffer().supportedTIAMaxZoom();

  myTIAZoom->setMinValue(minZoom * 100);
  myTIAZoom->setMaxValue(maxZoom * 100);
  myTIAZoom->setTickmarkIntervals((maxZoom - minZoom) * 2); // every ~50%
  myTIAZoom->setValue(settings.getFloat("tia.zoom") * 100);

  // Fullscreen
  myFullscreen->setState(settings.getBool("fullscreen"));
  // Fullscreen stretch setting
  myUseStretch->setState(settings.getBool("tia.fs_stretch"));
#ifdef ADAPTABLE_REFRESH_SUPPORT
  // Adapt refresh rate
  myRefreshAdapt->setState(settings.getBool("tia.fs_refresh"));
#endif
  // Fullscreen overscan setting
  myTVOverscan->setValue(settings.getInt("tia.fs_overscan"));
  handleFullScreenChange();

  // Aspect ratio correction
  myCorrectAspect->setState(settings.getBool("tia.correct_aspect"));

  // Aspect ratio setting (NTSC and PAL)
  myVSizeAdjust->setValue(settings.getInt("tia.vsizeadjust"));

  /////////////////////////////////////////////////////////////////////////////
  // Palettes tab
  // TIA Palette
  myPalette = settings.getString("palette");
  myTIAPalette->setSelected(myPalette, PaletteHandler::SETTING_STANDARD);

  // Palette adjustables
  const bool isPAL = instance().hasConsole()
    && instance().console().timing() == ConsoleTiming::pal;

  instance().frameBuffer().tiaSurface().paletteHandler().getAdjustables(myPaletteAdj);
  if(isPAL)
  {
    myPhaseShift->setLabel("PAL phase");
    myPhaseShift->setMinValue((PaletteHandler::DEF_PAL_SHIFT - PaletteHandler::MAX_PHASE_SHIFT) * 10);
    myPhaseShift->setMaxValue((PaletteHandler::DEF_PAL_SHIFT + PaletteHandler::MAX_PHASE_SHIFT) * 10);
    myPhaseShift->setTickmarkIntervals(4);
    myPhaseShift->setToolTip("Adjust PAL phase shift of 'Custom' palette.");
    myPhaseShift->setValue(myPaletteAdj.phasePal);
  }
  else
  {
    myPhaseShift->setLabel("NTSC phase");
    myPhaseShift->setMinValue((PaletteHandler::DEF_NTSC_SHIFT - PaletteHandler::MAX_PHASE_SHIFT) * 10);
    myPhaseShift->setMaxValue((PaletteHandler::DEF_NTSC_SHIFT + PaletteHandler::MAX_PHASE_SHIFT) * 10);
    myPhaseShift->setTickmarkIntervals(4);
    myPhaseShift->setToolTip("Adjust NTSC phase shift of 'Custom' palette.");
    myPhaseShift->setValue(myPaletteAdj.phaseNtsc);
  }
  myTVRedScale->setValue(myPaletteAdj.redScale);
  myTVRedShift->setValue(myPaletteAdj.redShift);
  myTVGreenScale->setValue(myPaletteAdj.greenScale);
  myTVGreenShift->setValue(myPaletteAdj.greenShift);
  myTVBlueScale->setValue(myPaletteAdj.blueScale);
  myTVBlueShift->setValue(myPaletteAdj.blueShift);
  myTVHue->setValue(myPaletteAdj.hue);
  myTVBright->setValue(myPaletteAdj.brightness);
  myTVContrast->setValue(myPaletteAdj.contrast);
  myTVSatur->setValue(myPaletteAdj.saturation);
  myTVGamma->setValue(myPaletteAdj.gamma);
  handlePaletteChange();
  colorPalette();

  // Autodetection
  myDetectPal60->setState(settings.getBool("detectpal60"));
  myDetectNtsc50->setState(settings.getBool("detectntsc50"));

  /////////////////////////////////////////////////////////////////////////////
  // TV Effects tab
  // TV Mode
  myTVMode->setSelected(
    settings.getString("tv.filter"), "0");
  const int preset = settings.getInt("tv.filter");
  handleTVModeChange(static_cast<NTSCFilter::Preset>(preset));

  // TV Custom adjustables
  loadTVAdjustables(NTSCFilter::Preset::CUSTOM);

  // TV phosphor mode & blend
  myTVPhosphor->setSelected(settings.getString(PhosphorHandler::SETTING_MODE), PhosphorHandler::VALUE_BYROM);
  myTVPhosLevel->setValue(settings.getInt(PhosphorHandler::SETTING_BLEND));
  handlePhosphorChange();

  // TV scanline intensity & mask
  myTVScanIntense->setValue(settings.getInt("tv.scanlines"));
  myTVScanMask->setSelected(settings.getString("tv.scanmask"), TIASurface::SETTING_STANDARD);

  /////////////////////////////////////////////////////////////////////////////
#ifdef IMAGE_SUPPORT
  // Bezel tab
  myBezelEnableCheckbox->setState(settings.getBool("bezel.show"));
  myBezelPath->setText(settings.getString("bezel.dir"));
  myBezelShowWindowed->setState(settings.getBool("bezel.windowed"));
  myManualWindow->setState(!settings.getBool("bezel.win.auto"));
  myWinLeftSlider->setValue(settings.getInt("bezel.win.left"));
  myWinRightSlider->setValue(settings.getInt("bezel.win.right"));
  myWinTopSlider->setValue(settings.getInt("bezel.win.top"));
  myWinBottomSlider->setValue(settings.getInt("bezel.win.bottom"));
  handleBezelChange();
#endif

  /////////////////////////////////////////////////////////////////////////////
  // Audio tab
  AudioSettings& audioSettings = instance().audioSettings();

  // Enable sound
#ifdef SOUND_SUPPORT
  mySoundEnableCheckbox->setState(audioSettings.enabled());
#else
  mySoundEnableCheckbox->setState(false);
#endif

  // Volume
  myVolumeSlider->setValue(audioSettings.volume());

  // Device
  const uInt32 deviceId = BSPF::clamp(audioSettings.device(), 0U,
      static_cast<uInt32>(instance().sound().supportedDevices().size() - 1));
  myDevicePopup->setSelected(deviceId);

  // Stereo
  myStereoSoundCheckbox->setState(audioSettings.stereo());

  // DPC Pitch
  myDpcPitch->setValue(audioSettings.dpcPitch());

  // Preset / mode
  myModePopup->setSelected(static_cast<int>(audioSettings.preset()));

  updateSettingsWithPreset(instance().audioSettings());

  updateAudioEnabledState();

  myTab->loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::updateSettingsWithPreset(AudioSettings& audioSettings)
{
  // Fragsize
  myFragsizePopup->setSelected(audioSettings.fragmentSize());

  // Output frequency
  myFreqPopup->setSelected(audioSettings.sampleRate());

  // Headroom
  myHeadroomSlider->setValue(audioSettings.headroom());

  // Buffer size
  myBufferSizeSlider->setValue(audioSettings.bufferSize());

  // Resampling quality
  myResamplingPopup->setSelected(static_cast<int>(audioSettings.resamplingQuality()));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::saveConfig()
{
  Settings& settings = instance().settings();

  /////////////////////////////////////////////////////////////////////////////
  // Display tab
  // Renderer setting
  settings.setValue("video", myRenderer->getSelectedTag().toString());

  // TIA interpolation
  settings.setValue("tia.inter", myTIAInterpolate->getState());

  // Fullscreen
  settings.setValue("fullscreen", myFullscreen->getState());
  // Fullscreen stretch setting
  settings.setValue("tia.fs_stretch", myUseStretch->getState());
#ifdef ADAPTABLE_REFRESH_SUPPORT
  // Adapt refresh rate
  settings.setValue("tia.fs_refresh", myRefreshAdapt->getState());
#endif
  // Fullscreen overscan
  settings.setValue("tia.fs_overscan", myTVOverscan->getValueLabel());

  // TIA zoom levels
  settings.setValue("tia.zoom", myTIAZoom->getValue() / 100.0);

  // Aspect ratio correction
  settings.setValue("tia.correct_aspect", myCorrectAspect->getState());

  // Aspect ratio setting (NTSC and PAL)
  const int oldAdjust = settings.getInt("tia.vsizeadjust");
  const int newAdjust = myVSizeAdjust->getValue();
  const bool vsizeChanged = oldAdjust != newAdjust;

  settings.setValue("tia.vsizeadjust", newAdjust);

  Logger::debug("Saving palette settings...");
  instance().frameBuffer().tiaSurface().paletteHandler().saveConfig(settings);

  // Autodetection
  settings.setValue("detectpal60", myDetectPal60->getState());
  settings.setValue("detectntsc50", myDetectNtsc50->getState());

  /////////////////////////////////////////////////////////////////////////////
  // TV Effects tab
  // TV Mode
  settings.setValue("tv.filter", myTVMode->getSelectedTag().toString());
  // TV Custom adjustables
  NTSCFilter::Adjustable ntscAdj;
  ntscAdj.sharpness = myTVSharp->getValue();
  ntscAdj.resolution = myTVRes->getValue();
  ntscAdj.artifacts = myTVArtifacts->getValue();
  ntscAdj.fringing = myTVFringe->getValue();
  ntscAdj.bleed = myTVBleed->getValue();
  NTSCFilter::setCustomAdjustables(ntscAdj);

  Logger::debug("Saving TV effects options ...");
  NTSCFilter::saveConfig(settings);

  // TV phosphor mode & blend
  settings.setValue(PhosphorHandler::SETTING_MODE, myTVPhosphor->getSelectedTag());
  settings.setValue(PhosphorHandler::SETTING_BLEND, myTVPhosLevel->getValueLabel() == "Off"
                    ? "0" : myTVPhosLevel->getValueLabel());

  // TV scanline intensity & mask
  settings.setValue("tv.scanlines", myTVScanIntense->getValueLabel());
  settings.setValue("tv.scanmask", myTVScanMask->getSelectedTag());

  /////////////////////////////////////////////////////////////////////////////
#ifdef IMAGE_SUPPORT
  // Bezel tab
  settings.setValue("bezel.show", myBezelEnableCheckbox->getState());
  settings.setValue("bezel.dir", myBezelPath->getText());
  settings.setValue("bezel.windowed", myBezelShowWindowed->getState());
  settings.setValue("bezel.win.auto", !myManualWindow->getState());
  settings.setValue("bezel.win.left", myWinLeftSlider->getValueLabel());
  settings.setValue("bezel.win.right", myWinRightSlider->getValueLabel());
  settings.setValue("bezel.win.top", myWinTopSlider->getValueLabel());
  settings.setValue("bezel.win.bottom", myWinBottomSlider->getValueLabel());
#endif

  // Note: The following has to happen after all video related setting have been saved
  if(instance().hasConsole())
  {
    instance().console().setTIAProperties();

    if(vsizeChanged)
    {
      instance().console().tia().clearFrameBuffer();
      instance().console().initializeVideo();
    }
  }

  // Finally, issue a complete framebuffer re-initialization...
  instance().createFrameBuffer();

  // ... and apply potential setting changes to the TIA surface
  instance().frameBuffer().tiaSurface().updateSurfaceSettings();

  /////////////////////////////////////////////////////////////////////////////
  // Audio tab
  AudioSettings& audioSettings = instance().audioSettings();

  // Enabled
  audioSettings.setEnabled(mySoundEnableCheckbox->getState());
  instance().sound().setEnabled(mySoundEnableCheckbox->getState());

  // Volume
  audioSettings.setVolume(myVolumeSlider->getValue());
  instance().sound().setVolume(myVolumeSlider->getValue());

  // Device
  audioSettings.setDevice(myDevicePopup->getSelected());

  // Stereo
  audioSettings.setStereo(myStereoSoundCheckbox->getState());

  // DPC Pitch
  audioSettings.setDpcPitch(myDpcPitch->getValue());
  // update if current cart is Pitfall II
  if (instance().hasConsole() &&
      instance().console().cartridge().name() == "CartridgeDPC")
  {
    auto& cart = static_cast<CartridgeDPC&>(instance().console().cartridge());
    cart.setDpcPitch(myDpcPitch->getValue());
  }

  const auto preset = static_cast<AudioSettings::Preset>
      (myModePopup->getSelectedTag().toInt());
  audioSettings.setPreset(preset);

  if (preset == AudioSettings::Preset::custom) {
    // Fragsize
    audioSettings.setFragmentSize(myFragsizePopup->getSelectedTag().toInt());
    audioSettings.setSampleRate(myFreqPopup->getSelectedTag().toInt());
    audioSettings.setHeadroom(myHeadroomSlider->getValue());
    audioSettings.setBufferSize(myBufferSizeSlider->getValue());
    audioSettings.setResamplingQuality(static_cast<AudioSettings::ResamplingQuality>(myResamplingPopup->getSelectedTag().toInt()));
  }

  // Only force a re-initialization when necessary, since it can
  // be a time-consuming operation
  if(instance().hasConsole())
    instance().console().initializeAudio();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::setDefaults()
{
  switch(myTab->getActiveTab())
  {
    case 0:  // General
    {
      myRenderer->setSelectedIndex(0);
      myTIAInterpolate->setState(false);
      // screen size
      myFullscreen->setState(false);
      myUseStretch->setState(false);
    #ifdef ADAPTABLE_REFRESH_SUPPORT
      myRefreshAdapt->setState(false);
    #endif
      myTVOverscan->setValue(0);
      myTIAZoom->setValue(300);
      myCorrectAspect->setState(true);
      myVSizeAdjust->setValue(0);

      handleFullScreenChange();
      break;
    }

    case 1:  // Palettes
    {
      const bool isPAL = instance().hasConsole()
        && instance().console().timing() == ConsoleTiming::pal;

      myTIAPalette->setSelected(PaletteHandler::SETTING_STANDARD);
      myPhaseShift->setValue(isPAL
                             ? PaletteHandler::DEF_PAL_SHIFT * 10
                             : PaletteHandler::DEF_NTSC_SHIFT * 10);
      myTVRedScale->setValue(50);
      myTVRedShift->setValue(PaletteHandler::DEF_RGB_SHIFT);
      myTVGreenScale->setValue(50);
      myTVGreenShift->setValue(PaletteHandler::DEF_RGB_SHIFT);
      myTVBlueScale->setValue(50);
      myTVBlueShift->setValue(PaletteHandler::DEF_RGB_SHIFT);
      myTVHue->setValue(50);
      myTVSatur->setValue(50);
      myTVContrast->setValue(50);
      myTVBright->setValue(50);
      myTVGamma->setValue(50);
      handlePaletteChange();
      handlePaletteUpdate();
      myDetectPal60->setState(false);
      myDetectNtsc50->setState(false);
      break;
    }

    case 2:  // TV effects
    {
      myTVMode->setSelected("0", "0");

      // TV phosphor mode & blend
      myTVPhosphor->setSelected(PhosphorHandler::VALUE_BYROM);
      myTVPhosLevel->setValue(50);

      // TV scanline intensity & mask
      myTVScanIntense->setValue(0);
      myTVScanMask->setSelected(TIASurface::SETTING_STANDARD);

      // Make sure that mutually-exclusive items are not enabled at the same time
      handleTVModeChange(NTSCFilter::Preset::OFF);
      handlePhosphorChange();
      loadTVAdjustables(NTSCFilter::Preset::CUSTOM);
      break;
    }
    case 3: // Bezels
#ifdef IMAGE_SUPPORT
      myBezelEnableCheckbox->setState(true);
      myBezelPath->setText(instance().userDir().getShortPath());
      myBezelShowWindowed->setState(false);
      myManualWindow->setState(false);
      handleBezelChange();
      break;

    case 4:  // Audio
#endif
      mySoundEnableCheckbox->setState(AudioSettings::DEFAULT_ENABLED);
      myVolumeSlider->setValue(AudioSettings::DEFAULT_VOLUME);
      myDevicePopup->setSelected(AudioSettings::DEFAULT_DEVICE);
      myStereoSoundCheckbox->setState(AudioSettings::DEFAULT_STEREO);
      myDpcPitch->setValue(AudioSettings::DEFAULT_DPC_PITCH);
      myModePopup->setSelected(static_cast<int>(AudioSettings::DEFAULT_PRESET));

      if constexpr(AudioSettings::DEFAULT_PRESET == AudioSettings::Preset::custom) {
        myResamplingPopup->setSelected(static_cast<int>(AudioSettings::DEFAULT_RESAMPLING_QUALITY));
        myFragsizePopup->setSelected(AudioSettings::DEFAULT_FRAGMENT_SIZE);
        myFreqPopup->setSelected(AudioSettings::DEFAULT_SAMPLE_RATE);
        myHeadroomSlider->setValue(AudioSettings::DEFAULT_HEADROOM);
        myBufferSizeSlider->setValue(AudioSettings::DEFAULT_BUFFER_SIZE);
      }
      else updatePreset();

      updateAudioEnabledState();
      break;

    default:  // satisfy compiler
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handleTVModeChange(NTSCFilter::Preset preset)
{
  const bool enable = preset == NTSCFilter::Preset::CUSTOM;

  myTVSharp->setEnabled(enable);
  myTVRes->setEnabled(enable);
  myTVArtifacts->setEnabled(enable);
  myTVFringe->setEnabled(enable);
  myTVBleed->setEnabled(enable);
  myCloneComposite->setEnabled(enable);
  myCloneSvideo->setEnabled(enable);
  myCloneRGB->setEnabled(enable);
  myCloneBad->setEnabled(enable);
  myCloneCustom->setEnabled(enable);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::loadTVAdjustables(NTSCFilter::Preset preset)
{
  NTSCFilter::Adjustable adj;
  NTSCFilter::getAdjustables(adj, preset);
  myTVSharp->setValue(adj.sharpness);
  myTVRes->setValue(adj.resolution);
  myTVArtifacts->setValue(adj.artifacts);
  myTVFringe->setValue(adj.fringing);
  myTVBleed->setValue(adj.bleed);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handleRendererChanged()
{
  const bool enable = myRenderer->getSelectedTag().toString() != "software";
  myTIAInterpolate->setEnabled(enable);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handlePaletteChange()
{
  const bool enable = myTIAPalette->getSelectedTag().toString() == "custom";

  myPhaseShift->setEnabled(enable);
  myTVRedScale->setEnabled(enable);
  myTVRedShift->setEnabled(enable);
  myTVGreenScale->setEnabled(enable);
  myTVGreenShift->setEnabled(enable);
  myTVBlueScale->setEnabled(enable);
  myTVBlueShift->setEnabled(enable);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handleShiftChanged(SliderWidget* widget)
{
  std::ostringstream ss;

  ss << std::setw(4) << std::fixed << std::setprecision(1)
    << (0.1 * (widget->getValue())) << DEGREE;
  widget->setValueLabel(ss.str());
  handlePaletteUpdate();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handlePaletteUpdate()
{
  // TIA Palette
  instance().settings().setValue("palette",
                                  myTIAPalette->getSelectedTag().toString());
  // Palette adjustables
  PaletteHandler::Adjustable paletteAdj;
  const bool isPAL = instance().hasConsole()
    && instance().console().timing() == ConsoleTiming::pal;

  if(isPAL)
  {
    paletteAdj.phaseNtsc = myPaletteAdj.phaseNtsc; // unchanged
    paletteAdj.phasePal = myPhaseShift->getValue();
  }
  else
  {
    paletteAdj.phaseNtsc = myPhaseShift->getValue();
    paletteAdj.phasePal = myPaletteAdj.phasePal; // unchanged
  }
  paletteAdj.redScale   = myTVRedScale->getValue();
  paletteAdj.redShift   = myTVRedShift->getValue();
  paletteAdj.greenScale = myTVGreenScale->getValue();
  paletteAdj.greenShift = myTVGreenShift->getValue();
  paletteAdj.blueScale  = myTVBlueScale->getValue();
  paletteAdj.blueShift  = myTVBlueShift->getValue();
  paletteAdj.hue        = myTVHue->getValue();
  paletteAdj.saturation = myTVSatur->getValue();
  paletteAdj.contrast   = myTVContrast->getValue();
  paletteAdj.brightness = myTVBright->getValue();
  paletteAdj.gamma      = myTVGamma->getValue();
  instance().frameBuffer().tiaSurface().paletteHandler().setAdjustables(paletteAdj);

  if(instance().hasConsole())
  {
    instance().frameBuffer().tiaSurface().paletteHandler().setPalette();

    constexpr int NUM_LUMA = 8;
    constexpr int NUM_CHROMA = 16;

    for(int idx = 0; idx < NUM_CHROMA; ++idx)  // NOLINT
      for(int lum = 0; lum < NUM_LUMA; ++lum)  // NOLINT
        myColor[idx][lum]->setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handleFullScreenChange()
{
  const bool enable = myFullscreen->getState();
  myUseStretch->setEnabled(enable);
#ifdef ADAPTABLE_REFRESH_SUPPORT
  myRefreshAdapt->setEnabled(enable);
#endif
  myTVOverscan->setEnabled(enable);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handleOverscanChange()
{
  if (myTVOverscan->getValue() == 0)
  {
    myTVOverscan->setValueLabel("Off");
    myTVOverscan->setValueUnit("");
  }
  else
    myTVOverscan->setValueUnit("%");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handlePhosphorChange()
{
  myTVPhosLevel->setEnabled(myTVPhosphor->getSelectedTag() != PhosphorHandler::VALUE_BYROM);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handleBezelChange()
{
  const bool enable = myBezelEnableCheckbox->getState();
  const bool nonAuto = myManualWindow->getState();

  myOpenBrowserButton->setEnabled(enable);
  myBezelPath->setEnabled(enable);
  myBezelShowWindowed->setEnabled(enable);
  myWinLeftSlider->setEnabled(enable && nonAuto);
  myWinRightSlider->setEnabled(enable && nonAuto);
  myWinTopSlider->setEnabled(enable && nonAuto);
  myWinBottomSlider->setEnabled(enable && nonAuto);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::handleCommand(CommandSender* sender, int cmd,
                                     int data, int id)
{
  switch (cmd)
  {
    case GuiObject::kOKCmd:
      saveConfig();
      close();
      break;

    case GuiObject::kCloseCmd:
      // restore palette settings
      instance().frameBuffer().tiaSurface().paletteHandler().setAdjustables(myPaletteAdj);
      instance().frameBuffer().tiaSurface().paletteHandler().setPalette(myPalette);
      Dialog::handleCommand(sender, cmd, data, 0);
      break;

    case GuiObject::kDefaultsCmd:
      setDefaults();
      break;

    case kPaletteChanged:
      handlePaletteChange();
      handlePaletteUpdate();
      break;

    case kPaletteUpdated:
      handlePaletteUpdate();
      break;

    case kPhaseShiftChanged:
      handleShiftChanged(myPhaseShift);
      break;

    case kRedShiftChanged:
      handleShiftChanged(myTVRedShift);
      break;

    case kGreenShiftChanged:
      handleShiftChanged(myTVGreenShift);
      break;

    case kBlueShiftChanged:
      handleShiftChanged(myTVBlueShift);
      break;

    case kRendererChanged:
      handleRendererChanged();
      break;

    case kVSizeChanged:
    {
      const int adjust = myVSizeAdjust->getValue();

      if (!adjust)
      {
        myVSizeAdjust->setValueLabel("Default");
        myVSizeAdjust->setValueUnit("");
      }
      else
        myVSizeAdjust->setValueUnit("%");
      break;
    }
    case kFullScreenChanged:
      handleFullScreenChange();
      break;

    case kOverscanChanged:
      handleOverscanChange();
      break;

    case kTVModeChanged:
      handleTVModeChange(static_cast<NTSCFilter::Preset>(myTVMode->getSelectedTag().toInt()));
      break;

    case kCloneCompositeCmd: loadTVAdjustables(NTSCFilter::Preset::COMPOSITE);
      break;
    case kCloneSvideoCmd: loadTVAdjustables(NTSCFilter::Preset::SVIDEO);
      break;
    case kCloneRGBCmd: loadTVAdjustables(NTSCFilter::Preset::RGB);
      break;
    case kCloneBadCmd: loadTVAdjustables(NTSCFilter::Preset::BAD);
      break;
    case kCloneCustomCmd: loadTVAdjustables(NTSCFilter::Preset::CUSTOM);
      break;

    case kScanlinesChanged:
      if (myTVScanIntense->getValue() == 0)
      {
        myTVScanIntense->setValueLabel("Off");
        myTVScanIntense->setValueUnit("");
        myTVScanMask->setEnabled(false);
      }
      else
      {
        myTVScanIntense->setValueUnit("%");
        myTVScanMask->setEnabled(true);
      }
      break;

    case kPhosphorChanged:
      handlePhosphorChange();
      break;

    case kPhosBlendChanged:
      if (myTVPhosLevel->getValue() == 0)
      {
        myTVPhosLevel->setValueLabel("Off");
        myTVPhosLevel->setValueUnit("");
      }
      else
        myTVPhosLevel->setValueUnit("%");
      break;

    case kBezelEnableChanged:
    case kAutoWindowChanged:
      handleBezelChange();
      break;

    case kChooseBezelDirCmd:
      BrowserDialog::show(this, _font, "Select Bezel Directory",
                          myBezelPath->getText(),
                          BrowserDialog::Mode::Directories,
                          [this](bool OK, const FSNode& node) {
                            if(OK) myBezelPath->setText(node.getShortPath());
                          });
      break;

    case kSoundEnableChanged:
      updateAudioEnabledState();
      break;

    case kModeChanged:
      updatePreset();
      updateAudioEnabledState();
      break;

    case kHeadroomChanged:
    {
      std::ostringstream ss;
      ss << std::fixed << std::setprecision(1) << (0.5 * myHeadroomSlider->getValue()) << " frames";
      myHeadroomSlider->setValueLabel(ss.str());
      break;
    }
    case kBufferSizeChanged:
    {
      std::ostringstream ss;
      ss << std::fixed << std::setprecision(1) << (0.5 * myBufferSizeSlider->getValue()) << " frames";
      myBufferSizeSlider->setValueLabel(ss.str());
      break;
    }

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::addPalette(int x, int y, int w, int h)
{
  constexpr int NUM_LUMA = 8;
  constexpr int NUM_CHROMA = 16;
  const GUI::Font& ifont = instance().frameBuffer().infoFont();
  const int lwidth = ifont.getMaxCharWidth() * 1.5;
  const float COLW = static_cast<float>(w - lwidth) / NUM_LUMA;
  const float COLH = static_cast<float>(h) / NUM_CHROMA;
  const int yofs = (COLH - ifont.getFontHeight() + 1) / 2;

  for(int idx = 0; idx < NUM_CHROMA; ++idx)
  {
    myColorLbl[idx] = new StaticTextWidget(myTab, ifont, x, y + yofs + idx * COLH, " ");
    for(int lum = 0; lum < NUM_LUMA; ++lum)
    {
      myColor[idx][lum] = new ColorWidget(myTab, _font, x + lwidth + lum * COLW, y + idx * COLH,
                                          COLW + 1, COLH + 1, 0, false);
      myColor[idx][lum]->clearFlags(FLAG_CLEARBG | FLAG_RETAIN_FOCUS | FLAG_MOUSE_FOCUS | FLAG_BORDER);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::colorPalette()
{
  constexpr int NUM_LUMA = 8;
  constexpr int NUM_CHROMA = 16;

  if(instance().hasConsole())
  {
    static constexpr int order[2][NUM_CHROMA] =
    {
      {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
      {0, 1, 2, 4, 6, 8, 10, 12, 13, 11, 9, 7, 5, 3, 14, 15}
    };
    const int type = instance().console().timing() == ConsoleTiming::pal ? 1 : 0;

    for(int idx = 0; idx < NUM_CHROMA; ++idx)
    {
      ostringstream ss;
      const int color = order[type][idx];

      ss << Common::Base::HEX1 << std::uppercase << color;
      myColorLbl[idx]->setLabel(ss.str());
      for(int lum = 0; lum < NUM_LUMA; ++lum)
        myColor[idx][lum]->setColor(color * NUM_CHROMA + lum * 2); // skip grayscale colors
    }
  }
  else
    // disable palette
    for(int idx = 0; idx < NUM_CHROMA; ++idx)  // NOLINT
      for(int lum = 0; lum < NUM_LUMA; ++lum)  // NOLINT
        myColor[idx][lum]->setEnabled(false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::updateAudioEnabledState()
{
  const bool active = mySoundEnableCheckbox->getState();
  const auto preset = static_cast<AudioSettings::Preset>
      (myModePopup->getSelectedTag().toInt());
  const bool userMode = preset == AudioSettings::Preset::custom;

  myVolumeSlider->setEnabled(active);
  myDevicePopup->setEnabled(active);
  myStereoSoundCheckbox->setEnabled(active);
  myModePopup->setEnabled(active);
  // enable only for Pitfall II cart
  myDpcPitch->setEnabled(active && instance().hasConsole() &&
      instance().console().cartridge().name() == "CartridgeDPC");

  myFragsizePopup->setEnabled(active && userMode);
  myFreqPopup->setEnabled(active && userMode);
  myResamplingPopup->setEnabled(active && userMode);
  myHeadroomSlider->setEnabled(active && userMode);
  myBufferSizeSlider->setEnabled(active && userMode);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoAudioDialog::updatePreset()
{
  const auto preset = static_cast<AudioSettings::Preset>
      (myModePopup->getSelectedTag().toInt());

  // Make a copy that does not affect the actual settings...
  AudioSettings audioSettings = instance().audioSettings();
  audioSettings.setPersistent(false);
  // ... and set the requested preset
  audioSettings.setPreset(preset);

  updateSettingsWithPreset(audioSettings);
}
