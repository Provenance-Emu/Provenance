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

#include <cmath>

#include "OSystem.hxx"
#include "Console.hxx"
#include "EventHandler.hxx"
#include "FBSurface.hxx"
#include "PNGLibrary.hxx"
#include "PropsSet.hxx"

#include "Bezel.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Bezel::Bezel(OSystem& osystem)
  : myOSystem{osystem},
    myFB{osystem.frameBuffer()}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Bezel::getName(const string& path, const Properties& props)
{
  string imageName;
  int index = 1; // skip property name

  do
  {
    imageName = getName(props, index);
    if(imageName != EmptyString)
    {
      // Note: JPG does not support transparency
      const string imagePath = path + imageName + ".png";
      const FSNode node(imagePath);
      if(node.exists())
        break;
    }
  } while(index != -1);

  return imageName;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Bezel::getName(const Properties& props, int& index)
{
  if(++index == 1)
    return props.get(PropType::Bezel_Name);

  // Try to generate bezel name from cart name
  const string& cartName = props.get(PropType::Cart_Name);
  size_t pos = cartName.find_first_of('(');
  if(pos == std::string::npos)
    pos = cartName.length() + 1;
  if(index < 10 && pos != std::string::npos && pos > 0)
  {
    // The following suffixes are from "The Official No-Intro Convention",
    // covering all used combinations by "The Bezel Project" (except single ones)
    // (Unl) = unlicensed (Homebrews)
    const std::array<string, 8> suffixes = {
      " (USA)", " (USA) (Proto)", " (USA) (Unl)", " (USA) (Hack)",
      " (Europe)", " (Germany)", " (France) (Unl)", " (Australia)"
    };
    return cartName.substr(0, pos - 1) + suffixes[index - 2];
  }

  if(index == 10)
  {
    return "Atari-2600";
  }

  if(index == 11)
  {
    index = -1;
    return "default";
  }
  return "";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Bezel::getName(int& index) const
{
  return getName(myOSystem.console().properties(), index);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 Bezel::borderSize(uInt32 x, uInt32 y, uInt32 size, Int32 step) const
{
  uInt32 *pixels{nullptr}, pitch{0};

  mySurface->basePtr(pixels, pitch);
  pixels += x + y * pitch;

  for(uInt32 i = 0; i < size; ++i, pixels += step)
  {
    uInt8 r{0}, g{0}, b{0}, a{0};

    myFB.getRGBA(*pixels, &r, &g, &b, &a);
    if(a < 255) // transparent pixel?
      return i;
  }
  return size - 1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Bezel::load()
{
  const Settings& settings = myOSystem.settings();
  bool isValid = false;
  string imageName;

#ifdef IMAGE_SUPPORT
  const bool show = myOSystem.eventHandler().inTIAMode() &&
    settings.getBool("bezel.show") &&
    (settings.getBool("fullscreen") ||
     settings.getBool("bezel.windowed"));

  if(show)
  {
    if(!mySurface)
      mySurface = myFB.allocateSurface(1, 1); // dummy size
    try
    {
      const string& path = myOSystem.bezelDir().getPath();
      VariantList metaData;
      int index = 0;

      do
      {
        imageName = getName(index);
        if(imageName != EmptyString)
        {
          // Note: JPG does not support transparency
          const string imagePath = path + imageName + ".png";
          const FSNode node(imagePath);
          if(node.exists())
          {
            isValid = true;
            myOSystem.png().loadImage(imagePath, *mySurface, metaData);
            break;
          }
        }
      } while(index != -1);
    }
    catch(const runtime_error&) { cerr << "ERROR: Bezel load\n"; }
  }
#else
  const bool show = false;
#endif
  if(isValid)
  {
    const Int32 w = mySurface->width();
    const Int32 h = mySurface->height();
    uInt32 top{0}, bottom{0}, left{0}, right{0};

    if(settings.getBool("bezel.win.auto"))
    {
      // Determine transparent window inside bezel image
      const uInt32 xCenter = w >> 1;
      top = borderSize(xCenter, 0, h, w);
      bottom = h - 1 - borderSize(xCenter, h - 1, h, -w);
      const uInt32 yCenter = (bottom + top) >> 1;
      left = borderSize(0, yCenter, w, 1);
      right = w - 1 - borderSize(w - 1, yCenter, w, -1);
    }
    else
    {
      // BP: 13, 13,  0,  0%
      // HY: 12, 12,  0,  0%
      // P1: 25, 25, 11, 22%
      // P2: 23, 23,  7, 20%
      left = std::min(w - 1, static_cast<Int32>(w * settings.getInt("bezel.win.left") / 100. + .5)); // NOLINT
      right = w - 1 - std::min(w - 1, static_cast<Int32>(w * settings.getInt("bezel.win.right") / 100. + .5)); // NOLINT
      top = std::min(h - 1, static_cast<Int32>(h * settings.getInt("bezel.win.top") / 100. + .5)); // NOLINT
      bottom = h - 1 - std::min(h - 1, static_cast<Int32>(h * settings.getInt("bezel.win.bottom") / 100. + .5)); // NOLINT
    }

    //cerr << (int)(right - left + 1) << " x " << (int)(bottom - top + 1) << " = "
    //  << double((int)(right - left + 1)) / double((int)(bottom - top + 1));

    // Disable bezel is no transparent window was found
    if(left < right && top < bottom)
      myInfo = Info(Common::Size(w, h), Common::Rect(left, top, right, bottom));
    else
    {
      if(mySurface)
        myFB.deallocateSurface(mySurface);
      mySurface = nullptr;
      myInfo = Info();
      myFB.showTextMessage("Invalid bezel image ('" + imageName + "')!");
      isValid = false;
    }
  }
  else
  {
    myInfo = Info();
    if(show)
      myFB.showTextMessage("No bezel image found");
  }
  return isValid;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Bezel::apply()
{
  if(isShown())
  {
    const uInt32 bezelW =
      std::min(myFB.screenSize().w,
      static_cast<uInt32>(std::round(myFB.imageRect().w() * myInfo.ratioW())));
    const uInt32 bezelH =
      std::min(myFB.screenSize().h,
      static_cast<uInt32>(std::round(myFB.imageRect().h() * myInfo.ratioH())));

    // Position and scale bezel
    mySurface->setDstSize(bezelW, bezelH);
    mySurface->setDstPos((myFB.screenSize().w - bezelW) / 2, // center
                         (myFB.screenSize().h - bezelH) / 2);
    mySurface->setScalingInterpolation(ScalingInterpolation::sharp);
    // Note: Variable bezel window positions are handled in VideoModeHandler::Mode

    // Enable blending to allow overlaying the bezel over the TIA output
    mySurface->attributes().blending = true;
    mySurface->attributes().blendalpha = 100;
    mySurface->applyAttributes();
    mySurface->setVisible(true);
  }
  else
    if(mySurface)
      mySurface->setVisible(false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Bezel::render()
{
  if(mySurface)
    mySurface->render();
}
