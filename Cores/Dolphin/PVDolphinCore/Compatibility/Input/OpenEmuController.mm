#include "DolphinGameCore.h"
#include "DolHost.h"
#include "OpenEmuInput.h"
#include "OpenEmuController.h"

#include "Core/ConfigManager.h"

void input_poll_f()
{
    //This is called every chance the Dolphin Emulator has to poll input from the frontend
    //  OpenEmu handles this, so it could be used to perfom a task per per input polling
    return;
};

int16_t input_state_f(unsigned port, unsigned device, unsigned index, unsigned button)
{
    if (SConfig::GetInstance().bWii && !SConfig::GetInstance().m_bt_passthrough_enabled)
    {
        //This is where we must translate the OpenEmu frontend keys presses stored in the keymap to bitmasks for Dolphin.
        return WiiRemotes[port].wiimote_keymap[button].value;
    } else {
        return GameCubePads[port].gc_pad_keymap[button].value;
    }
};

void init_Callback() {
    //Dolphin Polling Callback
    Input::openemu_set_input_poll(input_poll_f);
    
    //Controller input Callbacks
    Input::openemu_set_input_state(input_state_f);
}

void setGameCubeButton(int pad_num, int button , int value) {
    GameCubePads[pad_num].gc_pad_keymap[button].value = value;
}

void setGameCubeAxis(int pad_num, int button , float value)
{
    switch (button)
    {
        case OEGCAnalogUp:
        case OEGCAnalogLeft:
        case OEGCAnalogCUp:
        case OEGCAnalogCLeft:
            value *= -0x8000;
            break;
        default:
            value *= 0x7FFF;
            break;
    }
    GameCubePads[pad_num].gc_pad_keymap[button].value = value;
}

void setWiiButton(int pad_num, int button , int value) {
    WiiRemotes[pad_num].wiimote_keymap[button].value = value;
}

void setWiiAxis(int pad_num, int button , float value)
{
    switch (button)
    {
        
        case OEWiiMoteTiltLeft:
        case OEWiiMoteTiltForward:
            value *= -180;
            break;
        case OEWiiMoteTiltRight:
        case OEWiiMoteTiltBackward:
            value *= 180;
            break;
            
        case OEWiiNunchukAnalogUp:
        case OEWiiNunchukAnalogLeft:
        case OEWiiClassicAnalogLUp:
        case OEWiiClassicAnalogLLeft:
        case OEWiiClassicAnalogRUp:
        case OEWiiClassicAnalogRLeft:
            value *= -0x8000;
            break;
        default:
            value *= 0x7FFF;
            break;
    }
    WiiRemotes[pad_num].wiimote_keymap[button].value = value;
}
