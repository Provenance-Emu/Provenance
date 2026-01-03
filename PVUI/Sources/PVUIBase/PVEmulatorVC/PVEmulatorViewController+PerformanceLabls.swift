//
//  PVEmulatorCore+PerformanceMetrics.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//


// MARK: Performance Metrics

extension PVEmulatorViewController {

    internal func initFPSLabel() {
        /// Avoid duplicate view/constraint installation if called more than once.
        guard fpsHUDView.superview == nil else {
            applyFPSHUDTheme()
            return
        }
        gpuViewController.view.addSubview(fpsHUDView)
        fpsHUDView.addSubview(fpsLabel)

        NSLayoutConstraint.activate([
            fpsHUDView.topAnchor.constraint(equalTo: gpuViewController.view.topAnchor, constant: 10),
            fpsHUDView.trailingAnchor.constraint(equalTo: gpuViewController.view.trailingAnchor, constant: -10),
            fpsHUDView.widthAnchor.constraint(equalToConstant: {
                #if os(tvOS)
                return 340
                #else
                return 210
                #endif
            }()),

            fpsLabel.topAnchor.constraint(equalTo: fpsHUDView.topAnchor, constant: 6),
            fpsLabel.bottomAnchor.constraint(equalTo: fpsHUDView.bottomAnchor, constant: -6),
            fpsLabel.leadingAnchor.constraint(equalTo: fpsHUDView.leadingAnchor, constant: 8),
            fpsLabel.trailingAnchor.constraint(equalTo: fpsHUDView.trailingAnchor, constant: -8)
        ])

        applyFPSHUDTheme()
        themeDidChangeObserver = NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyFPSHUDTheme()
        }

        fpsTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true, block: { [weak self] (_: Timer) -> Void in
            guard let `self` = self else { return }

            /// Use core.emulationFPS as primary FPS metric (most accurate for emulation)
            /// This is especially important for 3D accelerated cores like RetroArch
            let emulationFPS = self.core.emulationFPS

            /// Calculate core speed based on emulation FPS vs target FPS
            /// Note: `core.frameInterval` is treated as FPS across the codebase (e.g. 60), not seconds-per-frame.
            let targetFPS = self.core.frameInterval > 0 ? self.core.frameInterval : 60.0
            let coreSpeed = (targetFPS > 0 && emulationFPS >= 0) ? (emulationFPS / targetFPS) * 100 : 0

            /// Calculate rendering FPS from GPU view controller frame timing
            var drawTime = self.gpuViewController.timeSinceLastDraw * 1000
            if drawTime <= 0 {
                let gpuFPS: Double = {
                    if let glVC = self.gpuViewController as? PVGLViewController {
                        return glVC.calculatedFramesPerSecond
                    } else if let metalVC = self.gpuViewController as? PVMetalViewController {
                        return Double(metalVC.framesPerSecond)
                    } else {
                        return 0.0
                    }
                }()
                if gpuFPS > 0 {
                    drawTime = 1000.0 / gpuFPS
                }
            }
            let renderFPS: Double
            if drawTime > 0 {
                renderFPS = 1000.0 / drawTime
            } else {
                /// Fallback to core.renderFPS if available, otherwise use emulationFPS
                renderFPS = self.core.renderFPS > 0 ? self.core.renderFPS : emulationFPS
            }

            /// Use emulationFPS for display (what users care about - actual game speed)
            let displayFPS = emulationFPS > 0 ? emulationFPS : renderFPS

            let mem = self.memoryUsage()
            let cpu = self.cpuUsage()
            let cpuFormatted = String(format: "%5.1f", cpu)
            let memUsedMB = Int(mem.used / 1024 / 1024)
            let memTotalMB = Int(mem.total / 1024 / 1024)

            self.fpsLabel.text = String(
                format: "Core speed %6.2f%%\nDraw time %6.2fms\nFPS %6.2f\nCPU %@%%\nMem %5d/%5d(MB)",
                coreSpeed, drawTime, displayFPS, cpuFormatted, memUsedMB, memTotalMB
            )
        })
    }

    @objc func updateFPSLabel() {
        #if os(iOS) && !USE_METAL
        if let glVC = gpuViewController as? PVGLViewController {
            let fps = glVC.calculatedFramesPerSecond
            VLOG("FPS: \(fps)")
        } else if let metalVC = gpuViewController as? PVMetalViewController {
            VLOG("FPS: \(metalVC.framesPerSecond)")
        }
        #else
        if let metalVC = gpuViewController as? PVMetalViewController {
            VLOG("FPS: \(metalVC.framesPerSecond)")
        }
        #endif
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
