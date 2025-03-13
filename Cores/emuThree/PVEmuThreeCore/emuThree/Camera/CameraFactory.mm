//
//  CameraFactory.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 27/8/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import "CameraFactory.h"

#import <Foundation/Foundation.h>

namespace Camera {
iOSRearCameraFactory::~iOSRearCameraFactory() {}

std::unique_ptr<CameraInterface> iOSRearCameraFactory::Create(const std::string &config, const Service::CAM::Flip &flip) {
    NSLog(@"%s", __FUNCTION__);
    return std::make_unique<iOSRearCameraInterface>();
}

iOSFrontCameraFactory::~iOSFrontCameraFactory() {}

std::unique_ptr<CameraInterface> iOSFrontCameraFactory::Create(const std::string &config, const Service::CAM::Flip &flip) {
    NSLog(@"%s", __FUNCTION__);
    return std::make_unique<iOSFrontCameraInterface>();
}
};
