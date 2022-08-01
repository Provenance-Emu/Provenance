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

#ifndef CARTRIDGECDF_WIDGET_HXX
#define CARTRIDGECDF_WIDGET_HXX

class PopUpWidget;
class CheckboxWidget;
class DataGridWidget;
class StaticTextWidget;
class EditTextWidget;
class SliderWidget;

#include "CartCDF.hxx"
#include "CartARMWidget.hxx"

class CartridgeCDFWidget : public CartridgeARMWidget
{
  public:
    CartridgeCDFWidget(GuiObject* boss, const GUI::Font& lfont,
                       const GUI::Font& nfont,
                       int x, int y, int w, int h,
                       CartridgeCDF& cart);
    ~CartridgeCDFWidget() override = default;

  private:
    struct CartState {
      ByteArray fastfetchoffset;
      IntArray datastreampointers;
      IntArray datastreamincrements;
      IntArray addressmaps;
      IntArray mcounters;
      IntArray mfreqs;
      IntArray mwaves;
      IntArray mwavesizes;
      IntArray samplepointer;
      uInt32 random{0};
      ByteArray internalram;
    };

    CartridgeCDF& myCart;
    PopUpWidget* myBank{nullptr};

    DataGridWidget* myDatastreamPointers{nullptr};
    DataGridWidget* myDatastreamIncrements{nullptr};
    DataGridWidget* myCommandStreamPointer{nullptr};
    DataGridWidget* myCommandStreamIncrement{nullptr};
    DataGridWidget* myJumpStreamPointers{nullptr};
    DataGridWidget* myJumpStreamIncrements{nullptr};
    DataGridWidget* myMusicCounters{nullptr};
    DataGridWidget* myMusicFrequencies{nullptr};
    DataGridWidget* myMusicWaveforms{nullptr};
    DataGridWidget* myMusicWaveformSizes{nullptr};
    DataGridWidget* mySamplePointer{nullptr};
    DataGridWidget* myFastFetcherOffset{nullptr};
    std::array<StaticTextWidget*, 10> myDatastreamLabels{nullptr};

    CheckboxWidget* myFastFetch{nullptr};
    CheckboxWidget* myDigitalSample{nullptr};

    CartState myOldState;

    enum { kBankChanged = 'bkCH' };

  private:
    bool isCDFJ() const;
    bool isCDFJplus() const;

    static string describeCDFVersion(CartridgeCDF::CDFSubtype subtype);

    void saveOldState() override;
    void loadConfig() override;

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    string bankState() override;

    // start of functions for Cartridge RAM tab
    uInt32 internalRamSize() override;
    uInt32 internalRamRPort(int start) override;
    string internalRamDescription() override;
    const ByteArray& internalRamOld(int start, int count) override;
    const ByteArray& internalRamCurrent(int start, int count) override;
    void internalRamSetValue(int addr, uInt8 value) override;
    uInt8 internalRamGetValue(int addr) override;
    // end of functions for Cartridge RAM tab

    // Following constructors and assignment operators not supported
    CartridgeCDFWidget() = delete;
    CartridgeCDFWidget(const CartridgeCDFWidget&) = delete;
    CartridgeCDFWidget(CartridgeCDFWidget&&) = delete;
    CartridgeCDFWidget& operator=(const CartridgeCDFWidget&) = delete;
    CartridgeCDFWidget& operator=(CartridgeCDFWidget&&) = delete;
};

#endif
