//
//  CameraFactory.h
//  Cytrus
//
//  Created by Jarrod Norwell on 27/8/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#include "core/frontend/camera/factory.h"

#include "CameraInterface.h"

namespace Camera {
class iOSRearCameraFactory : public CameraFactory {
public:
    ~iOSRearCameraFactory() override;
    
    std::unique_ptr<CameraInterface> Create(const std::string& config,
                                            const Service::CAM::Flip& flip) override;
};
}

namespace Camera {
class iOSFrontCameraFactory : public CameraFactory {
public:
    ~iOSFrontCameraFactory() override;
    
    std::unique_ptr<CameraInterface> Create(const std::string& config,
                                            const Service::CAM::Flip& flip) override;
};
}
