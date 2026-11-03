//
//  PatchTileBadge.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-10-15.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVRealm

/// Patch counts per base game, from one Realm observation shared by every library cell (a query
/// per cell would run on every grid redraw).
@MainActor
public final class PatchCountStore: ObservableObject {
    public static let shared = PatchCountStore()

    @Published public private(set) var counts: [String: Int] = [:]
    private var token: NotificationToken?

    private init() {
        let patches = RomDatabase.sharedInstance.realm.objects(PVPatch.self).filter("baseGameMD5 != nil")
        token = patches.observe { [weak self] change in
            switch change {
            case .initial(let results), .update(let results, _, _, _):
                self?.rebuild(from: results)
            case .error:
                break
            }
        }
    }

    private func rebuild(from patches: Results<PVPatch>) {
        var next: [String: Int] = [:]
        for patch in patches {
            guard let md5 = patch.baseGameMD5, !md5.isEmpty else { continue }
            next[md5, default: 0] += 1
        }
        if next != counts { counts = next }
    }

    public func count(forGameMD5 md5: String) -> Int {
        counts[md5] ?? 0
    }
}

/// The patch mark on a library cell, the same rule as iCube and iFly: a patched copy says so, and a
/// base game shows how many patched versions it has. Nothing for a plain game. Takes no hits, so it
/// cannot disturb tvOS focus.
public struct PatchTileBadge: View {
    private let isPatchVariant: Bool
    private let md5: String
    private let compact: Bool
    @ObservedObject private var store = PatchCountStore.shared

    public init(isPatchVariant: Bool, md5: String, compact: Bool = false) {
        self.isPatchVariant = isPatchVariant
        self.md5 = md5
        self.compact = compact
    }

    public var body: some View {
        Group {
            let count = store.count(forGameMD5: md5)
            if isPatchVariant {
                PatchIndicatorView(compact: compact)
            } else if count > 0 {
                PatchCountIndicatorView(count: count, compact: compact)
            }
        }
        .allowsHitTesting(false)
    }
}

struct PatchCountIndicatorView: View {
    let count: Int
    var compact = false

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "bandage")
            Text("\(count)")
        }
        .font(.system(size: compact ? 8 : 10, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(compact ? 2 : 3)
        .background(Material.ultraThin)
        .clipShape(Capsule())
        .accessibilityLabel(count == 1 ? "1 patched version" : "\(count) patched versions")
    }
}
