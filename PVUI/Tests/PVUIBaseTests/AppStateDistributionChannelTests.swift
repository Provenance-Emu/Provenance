//
//  AppStateDistributionChannelTests.swift
//  PVUIBaseTests
//
//  AppState's channel is a mapping of PVJIT's AppDistribution, the decision the JIT gate uses.
//

#if canImport(JITManager)
import Testing
import JITManager
@testable import PVUIBase

@Suite("AppState.DistributionChannel")
struct AppStateDistributionChannelTests {

    @Test("Release builds map each install to its channel")
    func releaseMapping() {
        let expected: [AppDistribution: AppState.DistributionChannel] = [
            .simulator: .simulator,
            .development: .sideload,
            .sideloaded: .sideload,
            .jailbroken: .sideload,
            .testFlight: .testFlight,
            .appStore: .appStore
        ]
        for distribution in AppDistribution.allCases {
            #expect(AppState.DistributionChannel.resolve(distribution: distribution, isDebugBuild: false)
                    == expected[distribution], "\(distribution)")
        }
    }

    @Test("A debug build is .debug wherever it runs")
    func debugBuild() {
        for distribution in AppDistribution.allCases {
            #expect(AppState.DistributionChannel.resolve(distribution: distribution, isDebugBuild: true) == .debug)
        }
    }
}
#endif
