//
//  InputFactory.mm
//  emuThreeDS
//
//  Created by Antique on 27/5/2023.
//

// Local Changes: Create local buttoninputbridge

#import <PVAzahar/InputBridge.h>
#import "../emuThree/InputFactory.h"

#import <PVAzahar/CitraWrapper.h>
#include <thread>
#import <CoreMotion/CoreMotion.h>

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

static std::shared_ptr<MotionFactory> motion;

namespace {
using Common::Vec3;
}

class Motion : public Input::MotionDevice {
    std::chrono::microseconds update_period;
    
    mutable std::atomic<Vec3<float>> acceleration{};
    mutable std::atomic<Vec3<float>> rotation{};
    static_assert(decltype(acceleration)::is_always_lock_free, "vectors are not lock free");
    std::thread poll_thread;
    std::atomic<bool> stop_polling = false;
    
    CMMotionManager *motionManager;
    
    static Vec3<float> TransformAxes(Vec3<float> in) {
        // 3DS   Y+            Phone     Z+
        // on    |             laying    |
        // table |             in        |
        //       |_______ X-   portrait  |_______ X+
        //      /              mode     /
        //     /                       /
        //    Z-                      Y-
        Vec3<float> out;
        out.y = in.z;
        // rotations are 90 degrees counter-clockwise from portrait
        switch (screen_rotation) {
            case 0:
                out.x = -in.x;
                out.z = in.y;
                break;
            case 1:
                out.x = in.y;
                out.z = in.x;
                break;
            case 2:
                out.x = in.x;
                out.z = -in.y;
                break;
            case 3:
                out.x = -in.y;
                out.z = -in.x;
                break;
            default:
                UNREACHABLE();
        }
        return out;
    }
    
public:
    Motion(std::chrono::microseconds update_period_, bool asynchronous = false)
    : update_period(update_period_) {
        if (asynchronous) {
            poll_thread = std::thread([this] {
                Construct();
                auto start = std::chrono::high_resolution_clock::now();
                while (!stop_polling) {
                    Update();
                    std::this_thread::sleep_until(start += update_period);
                }
                Destruct();
            });
        } else {
            Construct();
        }
    }
    
    std::tuple<Vec3<float>, Vec3<float>> GetStatus() const override {
        if (std::thread::id{} == poll_thread.get_id()) {
            Update();
        }
        return {acceleration, rotation};
    }
    
    void Construct() {
        motionManager = [[CMMotionManager alloc] init];
        EnableSensors();
    }
    
    void Destruct() {
        
    }
    
    void Update() const {
        CMDeviceMotion *motion = [motionManager deviceMotion];
        
        acceleration = {
            (motion.gravity.x + motion.userAcceleration.x),
            (motion.gravity.y + motion.userAcceleration.y),
            (motion.gravity.z + motion.userAcceleration.z)
        };
        
        rotation = {
            motion.rotationRate.x,
            motion.rotationRate.y,
            motion.rotationRate.z
        };
    }
    
    void DisableSensors() {
        [motionManager stopDeviceMotionUpdates];
    }
    
    void EnableSensors() {
        [motionManager startDeviceMotionUpdates];
    }
};

std::unique_ptr<Input::MotionDevice> MotionFactory::Create(const Common::ParamPackage &params) {
    std::chrono::milliseconds update_period{params.Get("update_period", 4)};
    std::unique_ptr<Motion> motion = std::make_unique<Motion>(update_period);
    _motion = motion.get();
    return std::move(motion);
}

void MotionFactory::EnableSensors() {
    _motion->EnableSensors();
};

void MotionFactory::DisableSensors() {
    _motion->DisableSensors();
};


MotionFactory* MotionHandler() {
    return motion.get();
}

