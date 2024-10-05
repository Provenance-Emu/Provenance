//
//  PVEmulatorCore+PerformanceMetrics.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//


// MARK: Performance Metrics

extension PVEmulatorViewController {
    
    internal func initFPSLabel() {
        gpuViewController.view.addSubview(fpsLabel)
        view.addConstraint(NSLayoutConstraint(item: fpsLabel, attribute: .topMargin, relatedBy: .equal, toItem: gpuViewController.view, attribute: .top, multiplier: 1.0, constant: -10))
        view.addConstraint(NSLayoutConstraint(item: fpsLabel, attribute: .right, relatedBy: .equal, toItem: gpuViewController.view, attribute: .right, multiplier: 1.0, constant: -10))

        fpsTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true, block: { [weak self] (_: Timer) -> Void in
            guard let `self` = self else { return }

            let coreSpeed = self.core.renderFPS / self.core.frameInterval * 100
            let drawTime =  self.gpuViewController.timeSinceLastDraw * 1000
            let fps = 1000 / drawTime
            let mem = self.memoryUsage()

            let cpu = self.cpuUsage()
            let cpuFormatted = String.init(format: "%03.01f", cpu)
            //            let cpuAttributed = NSAttributedString(string: cpuFormatted,
            //                                                   attributes: red)
            //
            let memFormatted: String = NSString.localizedStringWithFormat("%i", (mem.used/1024/1024)) as String
            let memTotalFormatted: String = NSString.localizedStringWithFormat("%i", (mem.total/1024/1024)) as
            String

            //            let memUsedAttributed = NSAttributedString(string: memFormatted,
            //                                                       attributes: green)
            //            let memTotalAttributed = NSAttributedString(string: memTotalFormatted,
            //                                                        attributes: green)
            //
            //            let label = NSMutableAttributedString()
            //
            //            let top = NSAttributedString(format: "Core speed %03.02f%% - Draw time %02.02f%ms - FPS %03.02f\n", coreSpeed, drawTime, fps);
            //
            //            label.append(top)

            self.fpsLabel.text = String(format: "Core speed %03.02f%%\nDraw time %02.02f%ms\nFPS %03.02f\nCPU %@%%\nMem %@/%@(MB)", coreSpeed, drawTime, fps, cpuFormatted, memFormatted, memTotalFormatted)
        })
    }

    @objc func updateFPSLabel() {
        VLOG("FPS: \(gpuViewController.framesPerSecond)")
        fpsLabel.text = String(format: "%2.02f", core.emulationFPS)
    }
    
    typealias MemoryUsage = (used: UInt64, total: UInt64)
    func memoryUsage() -> MemoryUsage {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            used = UInt64(taskInfo.phys_footprint)
        }

        let total = ProcessInfo.processInfo.physicalMemory
        return (used, total)
    }

    func cpuUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else {
                    break
                }

                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
                }
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        return totalUsageOfCPU
    }
}
