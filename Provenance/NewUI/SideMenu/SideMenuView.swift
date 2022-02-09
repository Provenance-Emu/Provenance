//
//  SideMenuView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import Introspect

@available(iOS 14, tvOS 14, *)
struct SideMenuView: SwiftUI.View {
    
    var delegate: PVMenuDelegate?
    
    @ObservedResults(
        PVSystem.self,
        configuration: RealmConfiguration.realmConfig,
        filter: NSPredicate(format: "games.@count > 0")
    ) var consoles
    
    init(gameLibrary: PVGameLibrary, delegate: PVMenuDelegate) {
        self.delegate = delegate
    }
    
    @State var sortAscending = true
    
    static func instantiate(gameLibrary: PVGameLibrary, delegate: PVMenuDelegate) -> UIViewController {
        let view = SideMenuView(gameLibrary: gameLibrary, delegate: delegate)
        let hostingView = UIHostingController(rootView: view)
        let nav = UINavigationController(rootViewController: hostingView)
        return nav
    }
    
    func versionText() -> String {
        let masterBranch: Bool = kGITBranch.lowercased() == "master"
        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        if !masterBranch {
            versionText = "\(versionText ?? "") Beta"
//            versionLabel.textColor = UIColor.init(hex: "#F5F5A0")
        }
        return versionText ?? ""
    }
    
    func sortedConsoles() -> Results<PVSystem> {
        return self.consoles.sorted(by: [SortDescriptor(keyPath: #keyPath(PVSystem.name), ascending: sortAscending)])
    }
    
    var body: some SwiftUI.View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Group {
                    MenuItemView(imageName: "prov_settings_gear", rowTitle: "Settings") {
                        delegate?.didTapSettings()
                    }
                    Divider()
                    MenuItemView(imageName: "prov_home_icon", rowTitle: "Home") {
                        delegate?.didTapHome()
                    }
                    Divider()
                    MenuItemView(imageName: "prov_add_games_icon", rowTitle: "Add Games") {
                        delegate?.didTapAddGames()
                    }
                }
                Group {
                    if consoles.count > 0 {
                        MenuSectionHeaderView(sectionTitle: "CONSOLES", sortable: consoles.count > 1, sortAscending: sortAscending) {
                            self.sortAscending.toggle()
                        }
                        ForEach(sortedConsoles(), id: \.self) { console in
                            Divider()
                            MenuItemView(imageName: "prov_snes_icon", rowTitle: console.name) {
                                delegate?.didTapConsole(with: console.identifier)
                            }
                        }
                    }
                }
                // TODO: flesh out collections later
                Group {
                    MenuSectionHeaderView(sectionTitle: "Provenance \(versionText())", sortable: false) {}
                }
                Spacer()
            }
        }
        .introspectViewController(customize: { vc in
            let logo = UIBarButtonItem(image: UIImage(named: "provnavicon"))
            logo.customView?.isUserInteractionEnabled = false
            vc.navigationItem.leftBarButtonItem = logo
        })
        .background(Color.black)
    }
}

@available(iOS 14, tvOS 14, *)
struct MenuSectionHeaderView: SwiftUI.View {
    
    var sectionTitle: String
    var sortable: Bool
    var sortAscending: Bool = false
    var action: () -> Void
    
    var body: some SwiftUI.View {
        VStack(spacing: 0) {
            Divider().frame(height: 2).background(Color.gray)
            Spacer()
            HStack(alignment: .bottom) {
                Text(sectionTitle).foregroundColor(Color.gray).font(.system(size: 13))
                Spacer()
                if sortable {
                    OptionsIndicator(pointDown: sortAscending, action: action) {
                        Text("Sort").foregroundColor(Color.gray).font(.system(.caption))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .frame(height: 40.0)
        .background(Color.black)
    }
}

@available(iOS 14, tvOS 14, *)
struct MenuItemView: SwiftUI.View {
    
    var imageName: String
    var rowTitle: String
    var action: () -> Void
    
    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                Image(imageName).resizable().scaledToFit().cornerRadius(4).padding(8)
                Text(rowTitle).foregroundColor(Color.white)
                Spacer()
            }
            .frame(height: 40.0)
            .background(Color.black)
        }
    }
}

//@available(iOS 14, tvOS 14, *)
//struct SideMenuView_Previews: PreviewProvider {
//    static var previews: some SwiftUI.View {
//        SideMenuView(delegate: self)
//    }
//}

#endif
