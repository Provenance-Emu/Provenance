//
//  EmulatorFeatureCatalog.swift
//  PVUI
//
//  The static table of session features the host registers, in the order their
//  hooks run. A test can assert which of them apply to a fake host.
//

/// The features `PVEmulatorViewController` offers a session, in hook order.
public enum EmulatorFeatureCatalog {
    public static let all: [any EmulatorSessionFeature.Type] = [
        PerformanceHUDFeature.self
    ]
}
