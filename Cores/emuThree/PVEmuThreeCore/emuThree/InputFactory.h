//
//  InputFactory.h
//  emuThreeDS
//
//  Created by Antique on 27/5/2023.
//

#import <Foundation/Foundation.h>


#ifdef __cplusplus
#include "common/assert.h"
#include "common/settings.h"
#include "core/frontend/input.h"
#include "input_common/main.h"

class AnalogFactory : public Input::Factory<Input::AnalogDevice> {
    std::unique_ptr<Input::InputDevice<std::tuple<float, float>>> Create(const Common::ParamPackage &) override;
};

class ButtonFactory : public Input::Factory<Input::ButtonDevice> {
    std::unique_ptr<Input::InputDevice<bool>> Create(const Common::ParamPackage &) override;
};

class MotionFactory : public Input::Factory<Input::MotionDevice> {
    std::unique_ptr<Input::InputDevice<std::tuple<Common::Vec3<float>, Common::Vec3<float>>>> Create(const Common::ParamPackage &) override;
};
#endif
