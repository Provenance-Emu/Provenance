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

#ifndef FRAMEBUFFER_CONSTANTS_HXX
#define FRAMEBUFFER_CONSTANTS_HXX

#include "TIAConstants.hxx"
#include "bspf.hxx"

// Minimum size for a framebuffer window
namespace FBMinimum {
  static constexpr uInt32 Width = TIAConstants::viewableWidth * 2;
  static constexpr uInt32 Height = TIAConstants::viewableHeight * 2;
}

// Return values for initialization of framebuffer window
enum class FBInitStatus {
  Success,
  FailComplete,
  FailTooLarge,
  FailNotSupported
};

enum class BufferType {
  None,
  Launcher,
  Emulator,
  Debugger
};

enum class ScalingInterpolation {
  none,
  sharp,
  blur
};

// Positions for onscreen/overlaid messages
enum class MessagePosition {
  TopLeft,
  TopCenter,
  TopRight,
  MiddleLeft,
  MiddleCenter,
  MiddleRight,
  BottomLeft,
  BottomCenter,
  BottomRight
};

// Colors indices to use for the various GUI elements
// Abstract away what a color actually is, so we can easily change it in
// the future, if necessary
using ColorId = uInt32;
static constexpr ColorId
  // *** Base colors ***
  kColor = 256,
  kBGColor = 257,
  kBGColorLo = 258,
  kBGColorHi = 259,
  kShadowColor = 260,
  // *** Text colors ***
  kTextColor = 261,
  kTextColorHi = 262,
  kTextColorEm = 263,
  kTextColorInv = 264,
  kTextColorLink = 265,
  // *** UI elements(dialog and widgets) ***
  kDlgColor = 266,
  kWidColor = 267,
  kWidColorHi = 268,
  kWidFrameColor = 269,
  // *** Button colors ***
  kBtnColor = 270,
  kBtnColorHi = 271,
  kBtnBorderColor = 272,
  kBtnBorderColorHi = 273,
  kBtnTextColor = 274,
  kBtnTextColorHi = 275,
  // *** Checkbox colors ***
  kCheckColor = 276,
  // *** Scrollbar colors ***
  kScrollColor = 277,
  kScrollColorHi = 278,
  // *** Debugger colors ***
  kDbgChangedColor = 279,
  kDbgChangedTextColor = 280,
  kDbgColorHi = 281,
  kDbgColorRed = 282, // Note: this must be < 0x11e (286)! (see PromptWidget::putcharIntern)
  // *** Slider colors ***
  kSliderColor = 283,
  kSliderColorHi = 284,
  kSliderBGColor = 285,
  kSliderBGColorHi = 286,
  kSliderBGColorLo = 287,
  // *** Other colors ***
  kColorInfo = 288,
  kColorTitleBar = 289,
  kColorTitleText = 290,
  kNumColors = 291,
  kNone = 0  // placeholder to represent default/no color
;

// Palette for normal TIA, UI and both combined
using PaletteArray = std::array<uInt32, kColor>;
using UIPaletteArray = std::array<uInt32, kNumColors-kColor>;
using FullPaletteArray = std::array<uInt32, kNumColors>;

// Text alignment modes for drawString()
enum class TextAlign {
  Left,
  Center,
  Right
};

// Line types for drawing rectangular frames
enum class FrameStyle {
  Solid,
  Dashed
};

#endif // FRAMEBUFFER_CONSTANTS_HXX
