//
//  SideMenuView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import RealmSwift
import PVLibrary

@available(iOS 14, tvOS 14, *)
struct SideMenuView: SwiftUI.View {
    
    static func instantiate(delegate: PVMenuDelegate) -> UIViewController {
        let view = SideMenuView(delegate: delegate)
        let hostingView = UIHostingController(rootView: view)
        return hostingView
    }
    
    @State var consoles: Results<PVSystem>?
    
//    @State var consoles: Results<PVSystem> = Realm().objects(PVSystem.self).filter("games.@count > 0").sorted(byKeyPath: "name")
    
//    @ObservedResults(PVSystem.self, filter: NSPredicate(format: "games.@count > 0")) var consoles
    
    var delegate: PVMenuDelegate?
    
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
                    if let consoles = consoles, consoles.count > 0 { // TODO: handle sorting
                        MenuSectionHeaderView(sectionTitle: "CONSOLES", sortable: consoles.count > 1)
                        ForEach(consoles, id: \.self) { console in
                            Divider()
                            MenuItemView(imageName: "prov_snes_icon", rowTitle: console.name) {
                                delegate?.didTapConsole(with: console.identifier)
                            }
                        }
                    }
                }
                // TODO: flesh out collections later
                Group {
                    MenuSectionHeaderView(sectionTitle: "Provenance 2.something", sortable: false)
                }
                Spacer()
            }
        }
        .background(Color.black)
        .onAppear {
            consoles = try? Realm().objects(PVSystem.self).filter("games.@count > 0").sorted(byKeyPath: "name")
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct MenuSectionHeaderView: SwiftUI.View {
    
    var sectionTitle: String
    var sortable: Bool
    
    var body: some SwiftUI.View {
        VStack(spacing: 0) {
            Divider().frame(height: 4).background(Color.gray)
            Spacer()
            HStack(alignment: .bottom) {
                Text(sectionTitle).foregroundColor(Color.gray).font(.system(.subheadline))
                Spacer()
                if sortable {
                    HStack(alignment: .bottom, spacing: 0) {
                        Text("Sort").foregroundColor(Color.gray).font(.system(.caption))
                        Image("chevron_down").resizable().foregroundColor(.gray).frame(width: 16, height: 16)
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

@available(iOS 14, tvOS 14, *)
struct SideMenuView_Previews: PreviewProvider {
    static var previews: some SwiftUI.View {
        SideMenuView()
    }
}

#endif
