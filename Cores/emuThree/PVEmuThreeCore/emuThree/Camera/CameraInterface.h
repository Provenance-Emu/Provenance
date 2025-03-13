//
//  CameraInterface.h
//  Cytrus
//
//  Created by Jarrod Norwell on 27/8/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#include "core/frontend/camera/interface.h"

namespace Camera {
class iOSRearCameraInterface : public CameraInterface {
public:
    ~iOSRearCameraInterface() override;
    
    void StartCapture() override;
    void StopCapture() override;
    
    void SetResolution(const Service::CAM::Resolution& resolution) override;
    void SetFlip(Service::CAM::Flip flip) override;
    void SetEffect(Service::CAM::Effect effect) override;
    void SetFormat(Service::CAM::OutputFormat format) override;
    void SetFrameRate(Service::CAM::FrameRate frame_rate) override;
    std::vector<u16> ReceiveFrame() override;
    bool IsPreviewAvailable() override;
};

class iOSFrontCameraInterface : public CameraInterface {
public:
    ~iOSFrontCameraInterface() override;
    
    void StartCapture() override;
    void StopCapture() override;
    
    void SetResolution(const Service::CAM::Resolution& resolution) override;
    void SetFlip(Service::CAM::Flip flip) override;
    void SetEffect(Service::CAM::Effect effect) override;
    void SetFormat(Service::CAM::OutputFormat format) override;
    void SetFrameRate(Service::CAM::FrameRate frame_rate) override;
    std::vector<u16> ReceiveFrame() override;
    bool IsPreviewAvailable() override;
};
} // namespace Camera
