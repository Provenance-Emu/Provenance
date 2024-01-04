//
//  InputFactory.mm
//  emuThreeDS
//
//  Created by Antique on 27/5/2023.
//

// Local Changes: Create local buttoninputbridge

#import "../emuThree/InputBridge.h"
#import "../emuThree/InputFactory.h"

#import "../emuThree/CitraWrapper.h"

@class EmulationInput;

std::unique_ptr<Input::AnalogDevice> AnalogFactory::Create(const Common::ParamPackage& params) {
    int button_id = params.Get("code", 0);
    AnalogInputBridge* emuInput = nullptr;
    switch ((Settings::NativeAnalog::Values)button_id) {
        case Settings::NativeAnalog::CirclePad:
            emuInput = CitraWrapper.sharedInstance.m_analogCirclePad;
            break;
        case Settings::NativeAnalog::CStick:
            emuInput = CitraWrapper.sharedInstance.m_analogCirclePad2;
            break;
        case Settings::NativeAnalog::NumAnalogs:
            UNREACHABLE();
            break;
    }
    
    if (emuInput == nullptr)
        return {};
    return std::unique_ptr<AnalogBridge>([emuInput getCppBridge]);
}

std::unique_ptr<Input::ButtonDevice> ButtonFactory::Create(const Common::ParamPackage& params) {
    int button_id = params.Get("code", 0);
    ButtonInputBridge* emuInput = nullptr;
    switch ((Settings::NativeButton::Values)button_id) {
        case Settings::NativeButton::A:
            emuInput = CitraWrapper.sharedInstance.m_buttonA;
            break;
        case Settings::NativeButton::B:
            emuInput = CitraWrapper.sharedInstance.m_buttonB;
            break;
        case Settings::NativeButton::X:
            emuInput = CitraWrapper.sharedInstance.m_buttonX;
            break;
        case Settings::NativeButton::Y:
            emuInput = CitraWrapper.sharedInstance.m_buttonY;
            break;
        case Settings::NativeButton::Up:
            emuInput = CitraWrapper.sharedInstance.m_buttonDpadUp;
            break;
        case Settings::NativeButton::Down:
            emuInput = CitraWrapper.sharedInstance.m_buttonDpadDown;
            break;
        case Settings::NativeButton::Left:
            emuInput = CitraWrapper.sharedInstance.m_buttonDpadLeft;
            break;
        case Settings::NativeButton::Right:
            emuInput = CitraWrapper.sharedInstance.m_buttonDpadRight;
            break;
        case Settings::NativeButton::L:
            emuInput = CitraWrapper.sharedInstance.m_buttonL;
            break;
        case Settings::NativeButton::R:
            emuInput = CitraWrapper.sharedInstance.m_buttonR;
            break;
        case Settings::NativeButton::Start:
            emuInput = CitraWrapper.sharedInstance.m_buttonStart;
            break;
        case Settings::NativeButton::Select:
            emuInput = CitraWrapper.sharedInstance.m_buttonSelect;
            break;
        case Settings::NativeButton::ZL:
            emuInput = CitraWrapper.sharedInstance.m_buttonZL;
            break;
        case Settings::NativeButton::ZR:
            emuInput = CitraWrapper.sharedInstance.m_buttonZR;
            break;
        case Settings::NativeButton::Home:
            emuInput = CitraWrapper.sharedInstance.m_buttonHome;
            break;
        case Settings::NativeButton::Debug:
        case Settings::NativeButton::Gpio14:
        case Settings::NativeButton::NumButtons:
            emuInput = CitraWrapper.sharedInstance.m_buttonDummy;
    }
    
    if (emuInput == nullptr)
        return {};
    return std::unique_ptr<ButtonBridge<bool>>([emuInput getCppBridge]);
}


std::unique_ptr<Input::MotionDevice> MotionFactory::Create(const Common::ParamPackage& params) {
    MotionInputBridge* emuInput = nullptr;
    emuInput = CitraWrapper.sharedInstance.m_motion;
    
    if (emuInput == nullptr)
        return {};
    return std::unique_ptr<MotionBridge>([emuInput getCppBridge]);
}
