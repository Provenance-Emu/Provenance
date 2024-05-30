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

#ifndef FBSURFACE_HXX
#define FBSURFACE_HXX

class FrameBuffer;
class TIASurface;

namespace GUI {
  class Font;
}
namespace Common {
  struct Rect;
}

#include "FrameBufferConstants.hxx"
#include "FrameBuffer.hxx"
#include "bspf.hxx"

/**
  This class is basically a thin wrapper around the video toolkit 'surface'
  structure.  We do it this way so the actual video toolkit won't be dragged
  into the depths of the codebase.  All drawing is done into FBSurfaces,
  which are then drawn into the FrameBuffer.  Each FrameBuffer-derived class
  is responsible for extending an FBSurface object suitable to the
  FrameBuffer type.

  NOTE: myPixels and myPitch MUST be set in child classes that inherit
        from this class

  @author  Stephen Anthony
*/
class FBSurface
{
  public:
    FBSurface() = default;
    virtual ~FBSurface() = default;

    /**
      This method returns the surface pixel pointer and pitch, which are
      used when one wishes to modify the surface pixels directly.
    */
    inline void basePtr(uInt32*& pixels, uInt32& pitch) const
    {
      pixels = myPixels;
      pitch = myPitch;
    }

    /**
      This method is called to get a copy of the specified ARGB data from
      the behind-the-scenes surface.

      @param buffer  A copy of the pixel data in ARGB8888 format
      @param pitch   The pitch (in bytes) for the pixel data
      @param rect    The bounding rectangle for the buffer
    */
    void readPixels(uInt8* buffer, uInt32 pitch, const Common::Rect& rect) const;

    //////////////////////////////////////////////////////////////////////////
    // Note:  The drawing primitives below will work, but do not take
    //        advantage of any acceleration whatsoever.  The methods are
    //        marked as 'virtual' so that child classes can choose to
    //        implement them more efficiently.
    //////////////////////////////////////////////////////////////////////////

    /**
      This method should be called to draw a single pixel.

      @param x      The x coordinate
      @param y      The y coordinate
      @param color  The color of the line
    */
    virtual void pixel(uInt32 x, uInt32 y, ColorId color);

    /**
      This method should be called to draw a line.

      @param x      The first x coordinate
      @param y      The first y coordinate
      @param x2     The second x coordinate
      @param y2     The second y coordinate
      @param color  The color of the line
    */
    virtual void line(uInt32 x, uInt32 y, uInt32 x2, uInt32 y2, ColorId color);

    /**
      This method should be called to draw a horizontal line.

      @param x      The first x coordinate
      @param y      The y coordinate
      @param x2     The second x coordinate
      @param color  The color of the line
    */
    virtual void hLine(uInt32 x, uInt32 y, uInt32 x2, ColorId color);

    /**
      This method should be called to draw a vertical line.

      @param x      The x coordinate
      @param y      The first y coordinate
      @param y2     The second y coordinate
      @param color  The color of the line
    */
    virtual void vLine(uInt32 x, uInt32 y, uInt32 y2, ColorId color);

    /**
      This method should be called to draw a filled rectangle.

      @param x      The x coordinate
      @param y      The y coordinate
      @param w      The width of the area
      @param h      The height of the area
      @param color  The fill color of the rectangle
    */
    virtual void fillRect(uInt32 x, uInt32 y, uInt32 w, uInt32 h,
                          ColorId color);

    /**
      This method should be called to draw the specified character.

      @param font   The font to use to draw the character
      @param c      The character to draw
      @param x      The x coordinate
      @param y      The y coordinate
      @param color  The color of the character
    */
    virtual void drawChar(const GUI::Font& font, uInt8 c, uInt32 x, uInt32 y,
                          ColorId color, ColorId shadowColor = kNone);

    /**
      This method should be called to draw the bitmap image.

      @param bitmap The data to draw
      @param x      The x coordinate
      @param y      The y coordinate
      @param color  The color of the bitmap
      @param h      The height of the data image
    */
    virtual void drawBitmap(const uInt32* bitmap, uInt32 x, uInt32 y, ColorId color,
                            uInt32 h = 8);

    /**
      This method should be called to draw the bitmap image.

      @param bitmap The data to draw
      @param x      The x coordinate
      @param y      The y coordinate
      @param color  The color of the bitmap
      @param w      The width of the data image
      @param h      The height of the data image
    */
    virtual void drawBitmap(const uInt32* bitmap, uInt32 x, uInt32 y, ColorId color,
                            uInt32 w, uInt32 h);

    /**
      This method should be called to convert and copy a given row of pixel
      data into a FrameBuffer surface.  The pixels must already be in the
      format used by the surface.

      @param data      The data in uInt8 R/G/B format
      @param x         The destination x-location to start drawing pixels
      @param y         The destination y-location to start drawing pixels
      @param numpixels The number of pixels to draw
    */
    virtual void drawPixels(const uInt32* data, uInt32 x, uInt32 y,
                            uInt32 numpixels);

    /**
      This method should be called to draw a rectangular box with sides
      at the specified coordinates.

      @param x      The x coordinate
      @param y      The y coordinate
      @param w      The width of the box
      @param h      The height of the box
      @param colorA Lighter color for outside line.
      @param colorB Darker color for inside line.
    */
    virtual void box(uInt32 x, uInt32 y, uInt32 w, uInt32 h,
                     ColorId colorA, ColorId colorB);

    /**
      This method should be called to draw a framed rectangle with
      several different possible styles.

      @param x      The x coordinate
      @param y      The y coordinate
      @param w      The width of the area
      @param h      The height of the area
      @param color  The color of the surrounding frame
      @param style  The 'FrameStyle' to use for the surrounding frame
    */
    virtual void frameRect(uInt32 x, uInt32 y, uInt32 w, uInt32 h,
                           ColorId color, FrameStyle style = FrameStyle::Solid);

    /**
      This method should be called to draw the specified string.

      @param font         The font to draw the string with
      @param s            The string to draw
      @param x            The x coordinate
      @param y            The y coordinate
      @param w            The width of the string area
      @param h            The height of the string area (for multi line strings)
      @param color        The color of the text
      @param align        The alignment of the text in the string width area
      @param deltax       The horizontal scroll offset
      @param useEllipsis  Whether to use '...' when the string is too long
      @param shadowColor  The shadow color of the text
      @param linkStart    The start position of a link in drawn string
      @param linkLen      The length of a link in drawn string
      @param underline    Whether to underline the link
      @return       Number of lines drawn
    */

    virtual int drawString(const GUI::Font& font, string_view s, int x, int y,
                           int w, int h, ColorId color,
                           TextAlign align = TextAlign::Left,
                           int deltax = 0, bool useEllipsis = true,
                           ColorId shadowColor = kNone,
                           size_t linkStart = string::npos,
                           size_t linkLen = string::npos,
                           bool underline = false);

    /**
      This method should be called to draw the specified string.

      @param font         The font to draw the string with
      @param s            The string to draw
      @param x            The x coordinate
      @param y            The y coordinate
      @param w            The width of the string area
      @param color        The color of the text
      @param align        The alignment of the text in the string width area
      @param deltax       The horizontal scroll offset
      @param useEllipsis  Whether to use '...' when the string is too long
      @param shadowColor  The shadow color of the text
      @param linkStart    The start position of a link in drawn string
      @param linkLen      The length of a link in drawn string
      @param underline    Whether to underline the link

      @return    x coordinate of end of string

    */
    virtual int drawString(const GUI::Font& font, string_view s, int x, int y,
                           int w, ColorId color, TextAlign align = TextAlign::Left,
                           int deltax = 0, bool useEllipsis = true,
                           ColorId shadowColor = kNone,
                           size_t linkStart = string::npos,
                           size_t linkLen = string::npos,
                           bool underline = false);

    /**
      Splits a given string to a given width considering whitespaces.

      @param font   The font to draw the string with
      @param s      The string to split
      @param w      The width of the string area
      @param left   The left part of the split string
      @param right  The right part of the split string
    */
    static void splitString(const GUI::Font& font, string_view s, int w,
                            string& left, string& right);

    /**
      The rendering attributes that can be modified for this texture.
      These probably can only be implemented in child FBSurfaces where
      the specific functionality actually exists.
    */
    struct Attributes {
      bool blending{false};    // Blending is enabled
      uInt32 blendalpha{100};  // Alpha to use in blending mode (0-100%)

      bool operator==(const Attributes& other) const {
        return blendalpha == other.blendalpha && blending == other.blending;
      }
    };

    /**
      Get the currently applied attributes.
    */
    Attributes& attributes() { return myAttributes; }

    //////////////////////////////////////////////////////////////////////////
    // Note:  The following methods are FBSurface-specific, and must be
    //        implemented in child classes.
    //
    //  For the following, 'src' indicates the actual data buffer area
    //  (non-scaled) and 'dst' indicates the rendered area (possibly scaled).
    //////////////////////////////////////////////////////////////////////////

    /**
      These methods answer the current *real* dimensions of the specified
      surface.
    */
    virtual uInt32 width() const = 0;
    virtual uInt32 height() const = 0;

    /**
      These methods answer the current *rendering* dimensions of the
      specified surface.
    */
    virtual const Common::Rect& srcRect() const = 0;
    virtual const Common::Rect& dstRect() const = 0;

    /**
      These methods set the origin point and width/height for the
      specified service.  They are defined as separate x/y and w/h
      methods since these items are sometimes set separately.
      Other times they are set together, so we can use a Rect instead.
    */
    virtual void setSrcPos(uInt32 x, uInt32 y)  = 0;
    virtual void setSrcSize(uInt32 w, uInt32 h) = 0;
    virtual void setSrcRect(const Common::Rect& r) = 0;
    virtual void setDstPos(uInt32 x, uInt32 y)  = 0;
    virtual void setDstSize(uInt32 w, uInt32 h) = 0;
    virtual void setDstRect(const Common::Rect& r) = 0;

    /**
      This method should be called to enable/disable showing the surface
      (ie, if hidden it will not be drawn under any circumstances.
    */
    virtual void setVisible(bool visible) = 0;

    /**
      This method should be called to translate the given coordinates
      to the (destination) surface coordinates.

      @param x  X coordinate to translate
      @param y  Y coordinate to translate
    */
    virtual void translateCoords(Int32& x, Int32& y) const = 0;

    /**
      This method should be called to draw the surface to the screen.
      It will return true if rendering actually occurred.
    */
    virtual bool render() = 0;

    /**
      This method should be called to reset the surface to empty
      pixels / colour black.
    */
    virtual void invalidate() {}

    /**
      This method should be called to reset a surface area to empty

      @param x      The x coordinate
      @param y      The y coordinate
      @param w      The width of the area
      @param h      The height of the area
    */
    virtual void invalidateRect(uInt32 x, uInt32 y, uInt32 w, uInt32 h) = 0;

    /**
      This method should be called to reload the surface data/state.
    */
    virtual void reload() = 0;

    /**
      This method should be called to resize the surface to the
      given dimensions and reload data/state.  The surface is not
      modified if it is larger than the given dimensions.
    */
    virtual void resize(uInt32 width, uInt32 height) = 0;

    /**
      Configure scaling interpolation.
     */
    virtual void setScalingInterpolation(ScalingInterpolation) = 0;

    /**
      The child class chooses which (if any) of the actual attributes
      can be applied.
    */
    virtual void applyAttributes() = 0;
    //////////////////////////////////////////////////////////////////////////

    static void setPalette(const FullPaletteArray& palette) { myPalette = palette; }

  protected:
    /**
      This method should be called to check if the given coordinates
      are in bounds of the surface.

      @param x      The x coordinate to check
      @param y      The y coordinate to check
      @return       True if coordinates are in bounds
    */
    bool checkBounds(const uInt32 x, const uInt32 y) const;

    /**
      Check if the given character is a whitespace.
      @param c      Character to check
      @return       True if whitespace character
    */
    static bool isWhiteSpace(const char c) {
      static constexpr string_view spaces{" ,.;:+-*/\\'([\n"};
      return spaces.find(c) != string_view::npos;
    }

  protected:
    uInt32* myPixels{nullptr};  // NOTE: MUST be set in child classes
    uInt32 myPitch{0};          // NOTE: MUST be set in child classes

    Attributes myAttributes;

    static FullPaletteArray myPalette;

  private:
    // Following constructors and assignment operators not supported
    FBSurface(const FBSurface&) = delete;
    FBSurface(FBSurface&&) = delete;
    FBSurface& operator=(const FBSurface&) = delete;
    FBSurface& operator=(FBSurface&&) = delete;
};

#endif
