//
//  PVToastTests.swift
//  PVUIBaseTests
//
//  Tests for PVToast notification system (PVToastType, PVToast, PVToastManager).
//

import Testing
@testable import PVUIBase

// MARK: - PVToastType Tests

@Suite("PVToastType")
struct PVToastTypeTests {

    @Test("All cases are covered by CaseIterable")
    func allCasesCount() {
        #expect(PVToastType.allCases.count == 6)
    }

    @Test("Each type has a non-empty defaultIcon")
    func defaultIconsAreNonEmpty() {
        for type_ in PVToastType.allCases {
            #expect(!type_.defaultIcon.isEmpty, "defaultIcon empty for \(type_)")
        }
    }

    @Test("Each type has a non-empty accessibilityLabel")
    func accessibilityLabelsAreNonEmpty() {
        for type_ in PVToastType.allCases {
            #expect(!type_.accessibilityLabel.isEmpty, "accessibilityLabel empty for \(type_)")
        }
    }

    @Test("Info type has expected SF symbol")
    func infoIcon() {
        #expect(PVToastType.info.defaultIcon == "info.circle.fill")
    }

    @Test("Success type has expected SF symbol")
    func successIcon() {
        #expect(PVToastType.success.defaultIcon == "checkmark.circle.fill")
    }

    @Test("Warning type has expected SF symbol")
    func warningIcon() {
        #expect(PVToastType.warning.defaultIcon == "exclamationmark.triangle.fill")
    }

    @Test("Error type has expected SF symbol")
    func errorIcon() {
        #expect(PVToastType.error.defaultIcon == "xmark.circle.fill")
    }

    @Test("JIT type has expected SF symbol")
    func jitIcon() {
        #expect(PVToastType.jit.defaultIcon == "bolt.fill")
    }

    @Test("Achievement type has expected SF symbol")
    func achievementIcon() {
        #expect(PVToastType.achievement.defaultIcon == "trophy.fill")
    }

    @Test("RawValue round-trips for all cases")
    func rawValueRoundTrip() {
        for type_ in PVToastType.allCases {
            let recovered = PVToastType(rawValue: type_.rawValue)
            #expect(recovered == type_, "rawValue round-trip failed for \(type_)")
        }
    }
}

// MARK: - PVToast Model Tests

@Suite("PVToast model")
struct PVToastModelTests {

    @Test("Default initialiser creates transient toast with generated id")
    func defaultInit() {
        let toast = PVToast(message: "Hello")
        #expect(!toast.id.isEmpty)
        #expect(toast.message == "Hello")
        #expect(toast.type == .info)
        #expect(toast.duration == 3.0)
        #expect(toast.isPersistent == false)
    }

    @Test("Icon defaults to type defaultIcon when not provided")
    func iconDefaultsToType() {
        let toast = PVToast(message: "Test", type: .success)
        #expect(toast.icon == PVToastType.success.defaultIcon)
    }

    @Test("Custom icon overrides type default")
    func customIconOverride() {
        let toast = PVToast(message: "Test", type: .info, icon: "star.fill")
        #expect(toast.icon == "star.fill")
    }

    @Test("Persistent toast stores isPersistent flag and infinite duration")
    func persistentFlag() {
        let toast = PVToast(message: "JIT", type: .jit, duration: .infinity, isPersistent: true)
        #expect(toast.isPersistent == true)
        #expect(toast.duration == .infinity)
    }

    @Test("Stable id is preserved when provided")
    func stableID() {
        let toast = PVToast(id: "my-stable-id", message: "Msg")
        #expect(toast.id == "my-stable-id")
    }

    @Test("Two toasts without explicit ids receive different ids")
    func uniqueGeneratedIDs() {
        let a = PVToast(message: "A")
        let b = PVToast(message: "B")
        #expect(a.id != b.id)
    }
}

// MARK: - PVToastManager Tests

// Run manager tests serially to avoid shared-singleton test interference.
@Suite("PVToastManager", .serialized)
@MainActor
struct PVToastManagerTests {

    // Each test method calls reset() at the start to clear shared state.
    private func reset() {
        PVToastManager.shared.dismissAll()
    }

    @Test("Initial (or reset) toast queue is empty")
    func initialQueueEmpty() {
        reset()
        #expect(PVToastManager.shared.toasts.isEmpty)
    }

    @Test("show() adds a toast to the queue")
    func showAddsToast() {
        reset()
        PVToastManager.shared.show("Hello", type: .info, duration: 60)
        #expect(PVToastManager.shared.toasts.count == 1)
        #expect(PVToastManager.shared.toasts[0].message == "Hello")
        #expect(PVToastManager.shared.toasts[0].type == .info)
    }

    @Test("show() with custom icon stores that icon")
    func showCustomIcon() {
        reset()
        PVToastManager.shared.show("Custom", type: .info, duration: 60, icon: "star.fill")
        #expect(PVToastManager.shared.toasts[0].icon == "star.fill")
    }

    @Test("showPersistent() creates a persistent toast with matching id")
    func showPersistentCreatesPersistentToast() {
        reset()
        _ = PVToastManager.shared.showPersistent("JIT active", id: "jit", type: .jit)
        #expect(PVToastManager.shared.toasts.count == 1)
        #expect(PVToastManager.shared.toasts[0].isPersistent == true)
        #expect(PVToastManager.shared.toasts[0].id == "jit")
    }

    @Test("showPersistent() returns a handle with the correct id")
    func showPersistentHandleID() {
        reset()
        let handle = PVToastManager.shared.showPersistent("Msg", id: "handle-test", type: .info)
        #expect(handle.id == "handle-test")
    }

    @Test("showPersistent() deduplicates: same id replaces the previous toast")
    func showPersistentDeduplicates() {
        reset()
        _ = PVToastManager.shared.showPersistent("First", id: "dup", type: .info)
        _ = PVToastManager.shared.showPersistent("Second", id: "dup", type: .success)
        #expect(PVToastManager.shared.toasts.count == 1)
        #expect(PVToastManager.shared.toasts[0].message == "Second")
    }

    @Test("dismiss(id:) removes only the matching toast")
    func dismissByID() {
        reset()
        _ = PVToastManager.shared.showPersistent("Keep", id: "keep", type: .info)
        _ = PVToastManager.shared.showPersistent("Remove", id: "remove", type: .warning)
        PVToastManager.shared.dismiss(id: "remove")
        #expect(PVToastManager.shared.toasts.count == 1)
        #expect(PVToastManager.shared.toasts[0].id == "keep")
    }

    @Test("dismiss(id:) is a no-op for an unknown id")
    func dismissUnknownIDIsNoOp() {
        reset()
        PVToastManager.shared.show("Existing", type: .info, duration: 60)
        PVToastManager.shared.dismiss(id: "nonexistent")
        #expect(PVToastManager.shared.toasts.count == 1)
    }

    @Test("dismissAll() clears the entire queue")
    func dismissAllClearsQueue() {
        reset()
        PVToastManager.shared.show("A", type: .info, duration: 60)
        PVToastManager.shared.show("B", type: .success, duration: 60)
        _ = PVToastManager.shared.showPersistent("C", id: "c", type: .jit)
        PVToastManager.shared.dismissAll()
        #expect(PVToastManager.shared.toasts.isEmpty)
    }

    @Test("Multiple show() calls stack toasts oldest-first")
    func multipleShowsStack() {
        reset()
        PVToastManager.shared.show("First", type: .info, duration: 60)
        PVToastManager.shared.show("Second", type: .success, duration: 60)
        PVToastManager.shared.show("Third", type: .warning, duration: 60)
        #expect(PVToastManager.shared.toasts.count == 3)
        #expect(PVToastManager.shared.toasts[0].message == "First")
        #expect(PVToastManager.shared.toasts[1].message == "Second")
        #expect(PVToastManager.shared.toasts[2].message == "Third")
    }

    @Test("Auto-dismiss removes toast after its duration elapses", .timeLimit(.minutes(1)))
    func autoDismissAfterDuration() async throws {
        reset()
        PVToastManager.shared.show("Quick", type: .info, duration: 0.1)
        #expect(PVToastManager.shared.toasts.count == 1)
        // Wait for slightly longer than the 0.1 s duration
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 s
        #expect(PVToastManager.shared.toasts.isEmpty)
    }

    @Test("Zero-duration toast is dismissed immediately", .timeLimit(.minutes(1)))
    func zeroDurationToast() async throws {
        reset()
        PVToastManager.shared.show("Instant", type: .info, duration: 0)
        // Yield to let the queued dismiss Task execute
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 s
        #expect(PVToastManager.shared.toasts.isEmpty)
    }

    @Test("Persistent toast is not auto-dismissed", .timeLimit(.minutes(1)))
    func persistentToastSurvives() async throws {
        reset()
        _ = PVToastManager.shared.showPersistent("Persistent", id: "p1", type: .jit)
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 s
        #expect(PVToastManager.shared.toasts.count == 1)
        #expect(PVToastManager.shared.toasts[0].id == "p1")
        reset()
    }

    @Test("PVToastHandle.dismiss() removes the associated toast", .timeLimit(.minutes(1)))
    func handleDismissRemovesToast() async throws {
        reset()
        let handle = PVToastManager.shared.showPersistent("Handle test", id: "h1", type: .info)
        #expect(PVToastManager.shared.toasts.count == 1)
        handle.dismiss()
        // dismiss() dispatches via Task { @MainActor in ... }; yield briefly
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 s
        #expect(PVToastManager.shared.toasts.isEmpty)
    }
}
