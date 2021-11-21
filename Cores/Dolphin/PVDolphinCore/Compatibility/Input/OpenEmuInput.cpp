#include <algorithm>
#include <array>
#include <cassert>

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
#include "OpenEmuInput.h"

#include "InputCommon/ControlReference/ControlReference.h"
#include "InputCommon/ControlReference/ExpressionParser.h"
#include "InputCommon/ControllerEmu/Control/Control.h"
#include "InputCommon/ControllerEmu/ControlGroup/Attachments.h"
#include "InputCommon/ControllerEmu/Setting/NumericSetting.h"
#include "InputCommon/ControllerInterface/ControllerInterface.h"
#include "InputCommon/GCAdapter.h"
#include "InputCommon/GCPadStatus.h"
#include "InputCommon/InputConfig.h"

#include "DolHost.h"

static Input::openemu_input_state_t input_cb;
static Input::openemu_input_poll_t poll_cb;
static const std::string source = "OpenEmu";
static unsigned input_types[4];
static bool init_wiimotes = false;

    static std::string GetDeviceName(unsigned device)
    {
        switch (device)
        {
            case OEDolDevJoy:
                return "Joypad";
            case OEDolDevAnalog:
                return "Analog";
            case OEDolDevPointer:
                return "Pointer";
            case OEDolDevLightGun:
                return "LightGun";
            case OEDolDevKeyboard:
                return "Keyboard";
            case OEDolDevMouse:
                return "Mouse";
            
        }
        return "Unknown";
    }

    static std::string GetQualifiedName(unsigned port, unsigned device)
    {
        return ciface::Core::DeviceQualifier(source, port, GetDeviceName(device)).ToString();
    }


    class OEDevice : public ciface::Core::Device
    {
    private:
        class Button : public ciface::Core::Device::Input
        {
        public:
            Button(unsigned port, unsigned device, unsigned index, unsigned id, const char* name)
            : m_port(port), m_device(device), m_index(index), m_id(id), m_name(name)
            {
            }
            std::string GetName() const override { return m_name; }
            ControlState GetState() const override {
                return input_cb(m_port, m_device, m_index, m_id);
            }

        private:
            const unsigned m_port;
            const unsigned m_device;
            const unsigned m_index;
            const unsigned m_id;
            const char* m_name;
        };

        class Axis : public ciface::Core::Device::Input
        {
        public:
            Axis(unsigned port, unsigned device, unsigned index, unsigned id, s16 range, const char* name)
            : m_port(port), m_device(device), m_index(index), m_id(id), m_range(range), m_name(name)
            {
            }
            std::string GetName() const override { return m_name; }
            ControlState GetState() const override
            {
                return std::max(0.0, input_cb(m_port, m_device, m_index, m_id) / m_range);
            }

        private:
            const unsigned m_port;
            const unsigned m_device;
            const unsigned m_index;
            const unsigned m_id;
            const ControlState m_range;
            const char* m_name;
        };

        class Motor : public ciface::Core::Device::Output
        {
        public:
            Motor(u8 port) : m_port(port) {}
            std::string GetName() const override { return "Rumble"; }
            void SetState(ControlState state) override
            {
                uint16_t str = std::min(std::max(0.0, state), 1.0) * 0xFFFF;

            }

        private:
            const u8 m_port;
        };
        
        void AddButton(unsigned id, const char* name, unsigned index = 0)
        {
            AddInput(new Button(m_port, m_device, index, id, name));
        }
        void AddAxis(unsigned id, s16 range, const char* name, unsigned index = 0)
        {
            AddInput(new Axis(m_port, m_device, index, id, range, name));
        }
        void AddMotor() { AddOutput(new Motor(m_port)); }

    public:
        OEDevice(unsigned device, unsigned port);
        void UpdateInput() override
        {
            poll_cb();
        }
        std::string GetName() const override { return GetDeviceName(m_device); }
        std::string GetSource() const override { return source; }
        unsigned GetPort() const { return m_port; }

    private:
        unsigned m_device;
        unsigned m_port;
    };

    OEDevice::OEDevice(unsigned device, unsigned p) : m_device(device), m_port(p)
    {
        switch (device)
        {
            case OEDolDevJoy:
                //GC
                AddButton(OEGCButtonB, "B");
                AddButton(OEGCButtonY, "Y");
                AddButton(OEGCButtonStart, "Start");
                AddButton(OEGCButtonUp, "Up");
                AddButton(OEGCButtonDown, "Down");
                AddButton(OEGCButtonLeft, "Left");
                AddButton(OEGCButtonRight, "Right");
                AddButton(OEGCButtonA, "A");
                AddButton(OEGCButtonX, "X");
                AddButton(OEGCDigitalL, "L");
                AddButton(OEGCDigitalR, "R");
                AddButton(OEGCButtonZ, "Z");
                //Wiimote
                AddButton(OEWiiMoteButtonUp, "Up");
                AddButton(OEWiiMoteButtonDown, "Down");
                AddButton(OEWiiMoteButtonLeft, "Left");
                AddButton(OEWiiMoteButtonRight, "Right");
                AddButton(OEWiiMoteButtonA, "A");
                AddButton(OEWiiMoteButtonB, "B");
                AddButton(OEWiiMoteButton1, "1");
                AddButton(OEWiiMoteButton2, "2");
                AddButton(OEWiiMoteButtonPlus, "+");
                AddButton(OEWiiMoteButtonMinus, "-");
                AddButton(OEWiiMoteButtonHome, "Home");
                AddButton(OEWiiMoteShake, "wmShake");
                //Special Buttons
                AddButton(OEWiimoteSideways, "Sideways");
                AddButton(OEWiimoteUpright, "Upright");
                //Nunchuk
                AddButton(OEWiiNunchukButtonC, "C");
                AddButton(OEWiiNunchukButtonZ, "Z");
                AddButton(OEWiiNunchukShake, "ncShake");
                //Classic
                AddButton(OEWiiClassicButtonUp, "Up");
                AddButton(OEWiiClassicButtonDown, "Down");
                AddButton(OEWiiClassicButtonLeft, "Left");
                AddButton(OEWiiClassicButtonRight, "Right");
                AddButton(OEWiiClassicButtonA, "A");
                AddButton(OEWiiClassicButtonB, "B");
                AddButton(OEWiiClassicButtonX, "X");
                AddButton(OEWiiClassicButtonY, "Y");
                AddButton(OEWiiClassicButtonL, "L");
                AddButton(OEWiiClassicButtonR, "R");
                AddButton(OEWiiClassicButtonZl, "Zl");
                AddButton(OEWiiClassicButtonZr, "Zr");
                AddButton(OEWiiClassicButtonStart, "Start");
                AddButton(OEWiiClassicButtonSelect, "Select");
                AddButton(OEWiiClassicButtonHome, "Home");
                return;
                
            case OEDolDevAnalog:
                AddAxis(OEGCAnalogLeft, -0x8000, "X0-", 0);
                AddAxis(OEGCAnalogRight, 0x7FFF, "X0+", 0);
                AddAxis(OEGCAnalogUp, -0x8000, "Y0-", 0);
                AddAxis(OEGCAnalogDown, 0x7FFF, "Y0+", 0 );
                AddAxis(OEGCAnalogCLeft, -0x8000, "X1-", 1);
                AddAxis(OEGCAnalogCRight, 0x7FFF, "X1+", 1);
                AddAxis(OEGCAnalogCUp, -0x8000, "Y1-", 1);
                AddAxis(OEGCAnalogCDown, 0x7FFF, "Y1+", 1);
                AddAxis(OEGCButtonL, 0x7FFF, "LTrigger0+");
                AddAxis(OEGCButtonR, 0x7FFF, "RTrigger1+");
                //Wiimote
                AddAxis(OEWiiMoteTiltForward, -180, "TiltY0-", 2);
                AddAxis(OEWiiMoteTiltBackward, 180, "TiltY0+", 2 );
                AddAxis(OEWiiMoteTiltLeft, -180, "TiltX0-", 2);
                AddAxis(OEWiiMoteTiltRight, 180, "TiltX0+", 2);
                AddAxis(OEWiiMoteSwingUp,-0x8000, "SwingY0-", 3);
                AddAxis(OEWiiMoteSwingDown,0x7FFF, "SwingY0+", 3);
                AddAxis(OEWiiMoteSwingLeft,-0x8000, "SwingX0-", 3);
                AddAxis(OEWiiMoteSwingRight,0x7FFF, "SwingX0+", 3);
                AddAxis(OEWiiMoteSwingForward, -0x8000, "SwingZ0-", 3);
                AddAxis(OEWiiMoteSwingBackward,0x7FFF, "SwingZ0+", 3);
                //Nunchuk
                AddAxis(OEWiiNunchukAnalogUp, -0x8000, "ncY0-", 4);
                AddAxis(OEWiiNunchukAnalogDown,0x7FFF, "ncY0+", 4);
                AddAxis(OEWiiNunchukAnalogLeft,-0x8000, "ncX0-", 4);
                AddAxis(OEWiiNunchukAnalogRight,0x7FFF, "ncX0+", 4);
                //Classic
                AddAxis(OEWiiClassicAnalogLUp, -0x8000, "ccY0-", 5);
                AddAxis(OEWiiClassicAnalogLDown,0x7FFF, "ccY0+", 5);
                AddAxis(OEWiiClassicAnalogLLeft,-0x8000, "ccX0-", 5);
                AddAxis(OEWiiClassicAnalogLRight,0x7FFF, "ccX0+", 5);
                AddAxis(OEWiiClassicAnalogRUp,-0x8000, "ccY1-", 6);
                AddAxis(OEWiiClassicAnalogRDown,0x7FFF, "ccY1+", 6);
                AddAxis(OEWiiClassicAnalogRLeft,-0x8000, "ccX1-", 6);
                AddAxis(OEWiiClassicAnalogRRight,0x7FFF, "ccX1+", 6);
                AddAxis(OEWiiClassicButtonL, 0x7FFF, "ccLTrigger0+");
                AddAxis(OEWiiClassicButtonR, 0x7FFF, "ccRTrigger1+");
                return;
        }
    }

    static void AddDevicesForPort(unsigned port)
    {
        g_controller_interface.AddDevice(std::make_shared<OEDevice>(OEDolDevJoy, port));
        g_controller_interface.AddDevice(std::make_shared<OEDevice>(OEDolDevAnalog, port));
        g_controller_interface.AddDevice(std::make_shared<OEDevice>(OEDolDevPointer, port));
    }

    static void RemoveDevicesForPort(unsigned port)
    {
        g_controller_interface.RemoveDevice([&port](const auto& device) {
            return device->GetSource() == source
            && (device->GetName() == GetDeviceName(OEDolDevAnalog)
                || device->GetName() == GetDeviceName(OEDolDevJoy)
                || device->GetName() == GetDeviceName(OEDolDevPointer))
            && dynamic_cast<const OEDevice *>(device)->GetPort() == port;
        });
    }

    void Input::Openemu_Input_Init()
    {
        
        g_controller_interface.Initialize(DolHost::GetInstance()->GetWSI());

        g_controller_interface.AddDevice(std::make_shared<OEDevice>(OEDolDevKeyboard, 0));

        Pad::Initialize();
        Keyboard::Initialize();
        
        if (SConfig::GetInstance().bWii && !SConfig::GetInstance().m_bt_passthrough_enabled)
          {
            init_wiimotes = true;
            Wiimote::Initialize(Wiimote::InitializeMode::DO_NOT_WAIT_FOR_WIIMOTES);
          }
    }

    void Shutdown()
    {
        Wiimote::ResetAllWiimotes();
        Wiimote::Shutdown();
        init_wiimotes = false;
        Keyboard::Shutdown();
        Pad::Shutdown();
        g_controller_interface.Shutdown();
    }

    void OpenEmu_Input_Update()
    {
    }

    void Input::ResetControllers()
    {
        for (int port = 0; port < 4; port++)
            Input::openemu_set_controller_port_device(port, input_types[port]);
    }

void Input::openemu_set_input_state(Input::openemu_input_state_t cb)
    {
        input_cb = cb;
    }

void Input::openemu_set_input_poll(Input::openemu_input_poll_t cb)
    {
        poll_cb = cb;
    }

void Input::openemu_set_controller_port_device(unsigned port, unsigned device)
{
    if (port > 4)
        return;

    input_types[port] = device;

    std::string devJoypad = GetQualifiedName(port, OEDolDevJoy);
    std::string devAnalog = GetQualifiedName(port, OEDolDevAnalog);
    std::string devMouse = GetQualifiedName(port, OEDolDevMouse);
    std::string devPointer = GetQualifiedName(port, OEDolDevPointer);

    RemoveDevicesForPort(port);
    if ((device & 0xff) != OEDolDevNone)
        AddDevicesForPort(port);


        GCPad* gcPad = (GCPad*)Pad::GetConfig()->GetController(port);
        // load an empty inifile section, clears everything
        IniFile::Section sec;
        gcPad->LoadConfig(&sec);
        gcPad->SetDefaultDevice(devJoypad);

        ControllerEmu::ControlGroup* gcButtons = gcPad->GetGroup(PadGroup::Buttons);
        ControllerEmu::ControlGroup* gcMainStick = gcPad->GetGroup(PadGroup::MainStick);
        ControllerEmu::ControlGroup* gcCStick = gcPad->GetGroup(PadGroup::CStick);
        ControllerEmu::ControlGroup* gcDPad = gcPad->GetGroup(PadGroup::DPad);
        ControllerEmu::ControlGroup* gcTriggers = gcPad->GetGroup(PadGroup::Triggers);
        ControllerEmu::ControlGroup* gcRumble = gcPad->GetGroup(PadGroup::Rumble);
#if 0
            ControllerEmu::ControlGroup* gcMic = gcPad->GetGroup(PadGroup::Mic);
            ControllerEmu::ControlGroup* gcOptions = gcPad->GetGroup(PadGroup::Options);
#endif

        gcButtons->SetControlExpression(0, "A");                              // A
        gcButtons->SetControlExpression(1, "B");                              // B
        gcButtons->SetControlExpression(2, "X");                              // X
        gcButtons->SetControlExpression(3, "Y");                              // Y
        gcButtons->SetControlExpression(4, "Z");                              // Z
        gcButtons->SetControlExpression(5, "Start");                          // Start
        gcMainStick->SetControlExpression(0, "`" + devAnalog + ":Y0-`");      // Up
        gcMainStick->SetControlExpression(1, "`" + devAnalog + ":Y0+`");      // Down
        gcMainStick->SetControlExpression(2, "`" + devAnalog + ":X0-`");      // Left
        gcMainStick->SetControlExpression(3, "`" + devAnalog + ":X0+`");      // Right
        gcCStick->SetControlExpression(0, "`" + devAnalog + ":Y1-`");         // Up
        gcCStick->SetControlExpression(1, "`" + devAnalog + ":Y1+`");         // Down
        gcCStick->SetControlExpression(2, "`" + devAnalog + ":X1-`");         // Left
        gcCStick->SetControlExpression(3, "`" + devAnalog + ":X1+`");         // Right
        gcDPad->SetControlExpression(0, "Up");                                // Up
        gcDPad->SetControlExpression(1, "Down");                              // Down
        gcDPad->SetControlExpression(2, "Left");                              // Left
        gcDPad->SetControlExpression(3, "Right");                             // Right
        gcTriggers->SetControlExpression(0, "L");                            // L-trigger
        gcTriggers->SetControlExpression(1, "R");                            // R-trigger
        gcTriggers->SetControlExpression(2, "`" + devAnalog + ":LTrigger0+`"); // L-trigger Analog
        gcTriggers->SetControlExpression(3, "`" + devAnalog + ":RTrigger1+`"); // R-trigger Analog
        gcRumble->SetControlExpression(0, "Rumble");

        gcPad->UpdateReferences(g_controller_interface);
        Pad::GetConfig()->SaveConfig();

    if (SConfig::GetInstance().bWii && !SConfig::GetInstance().m_bt_passthrough_enabled)
      {
        WiimoteEmu::Wiimote* wm = (WiimoteEmu::Wiimote*)Wiimote::GetConfig()->GetController(port);
        // load an empty inifile section, clears everything
        IniFile::Section sec;
        wm->LoadConfig(&sec);
        wm->SetDefaultDevice(devJoypad);
          
    using namespace WiimoteEmu;
        if (device == OEWiimoteCC || device == OEWiimoteCC_Pro)
        {
          ControllerEmu::ControlGroup* ccButtons = wm->GetClassicGroup(ClassicGroup::Buttons);
          ControllerEmu::ControlGroup* ccTriggers = wm->GetClassicGroup(ClassicGroup::Triggers);
          ControllerEmu::ControlGroup* ccDpad = wm->GetClassicGroup(ClassicGroup::DPad);
          ControllerEmu::ControlGroup* ccLeftStick = wm->GetClassicGroup(ClassicGroup::LeftStick);
          ControllerEmu::ControlGroup* ccRightStick = wm->GetClassicGroup(ClassicGroup::RightStick);

          ccButtons->SetControlExpression(0, "A");                                // A
          ccButtons->SetControlExpression(1, "B");                                // B
          ccButtons->SetControlExpression(2, "X");                                // X
          ccButtons->SetControlExpression(3, "Y");                                // Y
          ccButtons->SetControlExpression(4, "Zl");                               // ZL
          ccButtons->SetControlExpression(5, "Zr");                               // ZR
          ccButtons->SetControlExpression(6, "-");                                // -
          ccButtons->SetControlExpression(7, "+");                                // +
          ccButtons->SetControlExpression(8, "Home");                             // Home
          ccTriggers->SetControlExpression(0, "L");                               // L-trigger
          ccTriggers->SetControlExpression(1, "R");                               // R-trigger
          ccTriggers->SetControlExpression(2, "`" + devAnalog + "ccLTrigger0+`"); // L-trigger Analog
          ccTriggers->SetControlExpression(3, "`" + devAnalog + "ccRTrigger1+`"); // R-trigger Analog
          ccDpad->SetControlExpression(0, "Up");                                  // Up
          ccDpad->SetControlExpression(1, "Down");                                // Down
          ccDpad->SetControlExpression(2, "Left");                                // Left
          ccDpad->SetControlExpression(3, "Right");                               // Right
          ccLeftStick->SetControlExpression(0, "`" + devAnalog + ":ccY0-`");      // Up
          ccLeftStick->SetControlExpression(1, "`" + devAnalog + ":ccY0+`");      // Down
          ccLeftStick->SetControlExpression(2, "`" + devAnalog + ":ccX0-`");      // Left
          ccLeftStick->SetControlExpression(3, "`" + devAnalog + ":ccX0+`");      // Right
          ccRightStick->SetControlExpression(0, "`" + devAnalog + ":ccY1-`");     // Up
          ccRightStick->SetControlExpression(1, "`" + devAnalog + ":ccY1+`");     // Down
          ccRightStick->SetControlExpression(2, "`" + devAnalog + ":ccX1-`");     // Left
          ccRightStick->SetControlExpression(3, "`" + devAnalog + ":ccX1+`");     // Right
        }
        else //if (device != OEWiiMoteReal)
        {
          ControllerEmu::ControlGroup* wmButtons = wm->GetWiimoteGroup(WiimoteGroup::Buttons);
          ControllerEmu::ControlGroup* wmDPad = wm->GetWiimoteGroup(WiimoteGroup::DPad);
          ControllerEmu::ControlGroup* wmIR = wm->GetWiimoteGroup(WiimoteGroup::Point);
          ControllerEmu::ControlGroup* wmShake = wm->GetWiimoteGroup(WiimoteGroup::Shake);
          ControllerEmu::ControlGroup* wmTilt = wm->GetWiimoteGroup(WiimoteGroup::Tilt);
          ControllerEmu::ControlGroup* wmHotkeys = wm->GetWiimoteGroup(WiimoteGroup::Hotkeys);
    #if 0
          ControllerEmu::ControlGroup* wmSwing = wm->GetWiimoteGroup(WiimoteGroup::Swing);
         
    #endif

          wmButtons->SetControlExpression(0, "A | `" + devMouse + ":Left`");   // A
          wmButtons->SetControlExpression(1, "B | `" + devMouse + ":Right`");  // B

          if (device == OEWiimoteNC)
          {
            ControllerEmu::ControlGroup* ncButtons = wm->GetNunchukGroup(NunchukGroup::Buttons);
            ControllerEmu::ControlGroup* ncStick = wm->GetNunchukGroup(NunchukGroup::Stick);
            ControllerEmu::ControlGroup* ncShake = wm->GetNunchukGroup(NunchukGroup::Shake);
    #if 0
            ControllerEmu::ControlGroup* ncTilt = wm->GetNunchukGroup(NunchukGroup::Tilt);
            ControllerEmu::ControlGroup* ncSwing = wm->GetNunchukGroup(NunchukGroup::Swing);
    #endif

            ncButtons->SetControlExpression(0, "C");                        // C
            ncButtons->SetControlExpression(1, "Z");                        // Z
            ncStick->SetControlExpression(0, "`" + devAnalog + ":ccY0-`");  // Up
            ncStick->SetControlExpression(1, "`" + devAnalog + ":ccY0+`");  // Down
            ncStick->SetControlExpression(2, "`" + devAnalog + ":ccX0-`");  // Left
            ncStick->SetControlExpression(3, "`" + devAnalog + ":ccX0+`");  // Right
            ncShake->SetControlExpression(0, "ncShake");                    // X
            ncShake->SetControlExpression(1, "ncShake");                    // Y
            ncShake->SetControlExpression(2, "ncShake");                    // Z

            wmButtons->SetControlExpression(2, "1");                        // 1
            wmButtons->SetControlExpression(3, "2");                        // 2
            wmButtons->SetControlExpression(4, "-");                        // -
            wmButtons->SetControlExpression(5, "+");                        // +
          }
          else
          {
            wmButtons->SetControlExpression(2, "1");                        // 1
            wmButtons->SetControlExpression(3, "2");                        // 2
            wmButtons->SetControlExpression(4, "-");                        // -
            wmButtons->SetControlExpression(5, "+");                        // +
          }

          wmButtons->SetControlExpression(6, "Home");                      // Home
          wmDPad->SetControlExpression(0, "Up");                           // Up
          wmDPad->SetControlExpression(1, "Down");                         // Down
          wmDPad->SetControlExpression(2, "Left");                         // Left
          wmDPad->SetControlExpression(3, "Right");                        // Right
          wmIR->SetControlExpression(0, "`" + devPointer + ":Y0-`");       // Up
          wmIR->SetControlExpression(1, "`" + devPointer + ":Y0+`");       // Down
          wmIR->SetControlExpression(2, "`" + devPointer + ":X0-`");       // Left
          wmIR->SetControlExpression(3, "`" + devPointer + ":X0+`");       // Right
          wmShake->SetControlExpression(0, "wmShake");                     // X
          wmShake->SetControlExpression(1, "wmShake");                     // Y
          wmShake->SetControlExpression(2, "wmShake");                     // Z
          wmTilt->SetControlExpression(0, "`" + devAnalog + ":TiltY0-`");  // Forward
          wmTilt->SetControlExpression(1, "`" + devAnalog + ":TiltY0+`");  // Backward
          wmTilt->SetControlExpression(2, "`" + devAnalog + ":TiltX0-`");  // Left
          wmTilt->SetControlExpression(3, "`" + devAnalog + ":TiltX0+`");  // Right
            
    #if 0
          wmHotkeys->SetControlExpression(0, "Sideways");                  // Sideways Toggle
          wmHotkeys->SetControlExpression(1, "Upright");                   // Upright Toggle
          wmHotkeys->SetControlExpression(2, "Sideways");                  // Sideways Hold
          wmHotkeys->SetControlExpression(3, "Upright");                   // Upright Hold
    #endif
        }

        ControllerEmu::ControlGroup* wmRumble = wm->GetWiimoteGroup(WiimoteGroup::Rumble);
        ControllerEmu::ControlGroup* wmOptions = wm->GetWiimoteGroup(WiimoteGroup::Options);
        ControllerEmu::Attachments* wmExtension =
            (ControllerEmu::Attachments*)wm->GetWiimoteGroup(WiimoteGroup::Attachments);

        static_cast<ControllerEmu::NumericSetting<double>*>(wmOptions->numeric_settings[0].get())
            ->SetValue(0);  // Speaker Pan [-100, 100]
        static_cast<ControllerEmu::NumericSetting<double>*>(wmOptions->numeric_settings[1].get())
            ->SetValue(95);  // Battery [0, 100]
        static_cast<ControllerEmu::NumericSetting<bool>*>(wmOptions->numeric_settings[2].get())
            ->SetValue(false);  // Upright Wiimote
        static_cast<ControllerEmu::NumericSetting<bool>*>(wmOptions->numeric_settings[3].get())
            ->SetValue(false);  // Sideways Wiimote
        wmRumble->SetControlExpression(0, "Rumble");
        switch (device)
        {
        case OEWiimote:
          wmExtension->SetSelectedAttachment(ExtensionNumber::NONE);
          WiimoteCommon::SetSource(port, WiimoteSource::Emulated);
          break;

        case OEWiimoteSW:
          wmExtension->SetSelectedAttachment(ExtensionNumber::NONE);
          static_cast<ControllerEmu::NumericSetting<bool>*>(wmOptions->numeric_settings[2].get())
              ->SetValue(true);  // Sideways Wiimote
          WiimoteCommon::SetSource(port, WiimoteSource::Emulated);
          break;

        case OEWiimoteNC:
          wmExtension->SetSelectedAttachment(ExtensionNumber::NUNCHUK);
          WiimoteCommon::SetSource(port, WiimoteSource::Emulated);
          break;

        case OEWiimoteCC:
        case OEWiimoteCC_Pro:
          wmExtension->SetSelectedAttachment(ExtensionNumber::CLASSIC);
          WiimoteCommon::SetSource(port, WiimoteSource::Emulated);
          break;

        case OEWiiMoteReal:
          //desc = Libretro::Input::descEmpty;
          WiimoteCommon::SetSource(port, WiimoteSource::Real);

        default:
          //desc = Libretro::Input::descGC;
          WiimoteCommon::SetSource(port, WiimoteSource::None);
          break;
        }
        wm->UpdateReferences(g_controller_interface);
        ::Wiimote::GetConfig()->SaveConfig();
      }
}
