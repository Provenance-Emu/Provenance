/*
Copyright (c) 2016, OpenEmu Team

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
* Neither the name of the OpenEmu Team nor the
names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVSupport-Swift.h>

//#import "OEGCSystemResponderClient.h"
//#import "Wii/OEWiiSystemResponderClient.h"

#include "Core/GeckoCode.h"
#include "Core/ActionReplay.h"
#include "Core/ARDecrypt.h"
#include "Common/Common.h"
#include "Common/CommonTypes.h"
#include "Common/IniFile.h"
#include "Core/ConfigManager.h"
#include "Core/HW/GCKeyboard.h"
#include "Core/HW/GCPad.h"
#include "Core/HW/GCPadEmu.h"
#include "Core/HW/Wiimote.h"
#include "Core/HW/WiimoteEmu/Extension/Classic.h"
#include "Core/HW/WiimoteEmu/Extension/Nunchuk.h"
#include "Core/HW/WiimoteEmu/WiimoteEmu.h"
#include "Core/HW/WiimoteReal/WiimoteReal.h"
#include "Core/Host.h"
//#include "OpenEmuInput.h"

#include "InputCommon/ControlReference/ControlReference.h"
#include "InputCommon/ControlReference/ExpressionParser.h"
#include "InputCommon/ControllerEmu/Control/Control.h"
#include "InputCommon/ControllerEmu/ControlGroup/Attachments.h"
#include "InputCommon/ControllerEmu/Setting/NumericSetting.h"
#include "InputCommon/ControllerInterface/ControllerInterface.h"
#include "InputCommon/GCAdapter.h"
#include "InputCommon/GCPadStatus.h"
#include "InputCommon/InputConfig.h"

#include "Device.h"

#include "DolphinNoGUI/Platform.h"

#include "DiscIO/Enums.h"

class DolHost {
public:
    static DolHost* GetInstance();
    void Init(std::string supportDirectoryPath, std::string cpath);

    bool LoadFileAtPath();
    void RequestStop();
    void Reset();
    void UpdateFrame();
    void Pause(bool);


    void RunCore();
    void SetPresentationFBO(int RenderFBO);
    void SetBackBufferSize(int width, int height);

    void setButtonState(int button, int state, int player);
    void SetAxis(int button, float value, int player);
    void SetIR(int player, float x, float y);

    void processSpecialKeys (int button , int player);
    void setWiimoteSideways (int player);
    void setWiimoteUpright (int player);
    void changeWiimoteExtension(int extension, int player);

    void toggleAudioMute();
    void volumeDown();
    void volumeUp();
    void SetVolume(float value);
    void DisplayMessage(std::string message);
    float GetFrameInterval();

    bool SaveState(std::string saveStateFile);
    bool LoadState(std::string saveStateFile);
    bool setAutoloadFile(std::string saveStateFile);

    bool CoreRunning();

    WindowSystemInfo GetWSI();
    
    void SetCheat(std::string code, std::string value, bool enabled);
    //Vector of all Codes
    std::vector<Gecko::GeckoCode> gcodes;
    std::vector<ActionReplay::ARCode> arcodes;
    //Individual codes
    Gecko::GeckoCode gcode;
    ActionReplay::ARCode arcode;
    
    private:
    
    static DolHost* m_instance;
    DolHost();

    void GetGameInfo();
    std::string GetDirOfCountry(DiscIO::Country country);
    std::string GetNameOfRegion(DiscIO::Region region);
    std::string _gamePath;
    std::string _gameID;
    std::string _gameName;
    DiscIO::Region _gameRegion;
    std::string _gameRegionName;
    DiscIO::Platform _gameType;
    DiscIO::Country _gameCountry;
    std::string _gameCountryDir;

    bool        _onBoot = true;
    bool        _wiiWAD;
    int         _wiiMoteType;
    
    bool _wiiChangeExtension[4] = { false, false, false, false };
    bool _wmSideways[4] = { false, false, false, false };
    bool _wmUpright[4] = { false, false, false, false };
    
    std::string autoSaveStateFile;

    void SetUpPlayerInputs();
    ciface::Core::Device::Input* m_playerInputs[4][18];
//    ciface::Core::Device::Input* m_playerInputs[4][PVWiiButtonCount];
    
    
};
