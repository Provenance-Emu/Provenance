//
//  InputBridge.mm
//  emuThreeDS
//
//  Created by Antique on 27/5/2023.
//

#import "../emuThree/InputBridge.h"

@implementation ButtonInputBridge {
    ButtonBridge<bool>* _cppBridge;
}

-(id) init {
    if(self = [super init]) {
        _cppBridge = new ButtonBridge<bool>(false);
    } return self;
}

-(void) valueChangedHandler:(GCControllerButtonInput *)input value:(float)value pressed:(BOOL)pressed {
    _cppBridge->current_value = pressed;
}

-(ButtonBridge<bool> *) getCppBridge {
    return _cppBridge;
}
@end


@implementation AnalogInputBridge {
    AnalogBridge* _cppBridge;
}

-(id) init {
    if (self = [super init]) {
        _cppBridge = new AnalogBridge(Float2D{0, 0});
    } return self;
}

-(void) valueChangedHandler:(GCControllerDirectionPad *)input x:(float)xValue y:(float)yValue {
    _cppBridge->current_value.exchange(Float2D{xValue, yValue});
}

-(AnalogBridge *) getCppBridge {
    return _cppBridge;
}
@end


@implementation MotionInputBridge {
    MotionBridge* _cppBridge;
}

-(id) init {
    if (self = [super init]) {
        _cppBridge = new MotionBridge(Common::Vec3<float>(0, 0, 0), Common::Vec3<float>(0, 0, 0));
    } return self;
}

-(void) valueChangedHandler:(GCControllerDirectionPad *)input x:(float)xValue y:(float)yValue z:(float)zValue {
    _cppBridge->accel_value.exchange(Common::Vec3<float>(xValue, yValue, zValue));
    _cppBridge->gyro_value.exchange(Common::Vec3<float>(xValue, yValue, zValue));
}

-(MotionBridge *) getCppBridge {
    return _cppBridge;
}
@end

