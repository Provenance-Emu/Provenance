//
//  InputFactory.h
//  emuThreeDS
//
//  Created by Antique on 27/5/2023.
//

#import <Foundation/Foundation.h>

#pragma once

#ifdef __cplusplus
#include "common/assert.h"
#include "common/settings.h"
#include "core/frontend/input.h"
#include "input_common/main.h"

class Motion;

class AnalogFactory : public Input::Factory<Input::AnalogDevice> {
    std::unique_ptr<Input::InputDevice<std::tuple<float, float>>> Create(const Common::ParamPackage &) override;
};

class ButtonFactory : public Input::Factory<Input::ButtonDevice> {
    std::unique_ptr<Input::InputDevice<bool>> Create(const Common::ParamPackage &) override;
};

inline std::atomic<int> screen_rotation;
class MotionFactory final : public Input::Factory<Input::MotionDevice> {
public:
    std::unique_ptr<Input::MotionDevice> Create(const Common::ParamPackage& params) override;

    void EnableSensors();
    void DisableSensors();
    
private:
    Motion* _motion;
};

#endif
