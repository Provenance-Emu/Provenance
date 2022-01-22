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

@available(iOS 13.0.0, *)
struct SideMenuView: View {
    
    @State var consoles: Results<PVSystem>?
    var delegate: PVMenuDelegate?
    
    var body: some View {
        // should pull consoles list into a lazyvstack at some point
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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
                    if let consoles = consoles, consoles.count > 0 {
                        MenuSectionHeaderView(sectionTitle: "CONSOLES", sortable: consoles.count > 1)
                        ForEach(consoles, id: \.self) { console in
                            Divider()
                            MenuItemView(imageName: "prov_snes_icon", rowTitle: console.name) {
                                delegate?.didTapConsole(with: console.identifier)
                            }
                        }
                    }
                }
                Group {
                    MenuSectionHeaderView(sectionTitle: "COLLECTIONS", sortable: false)
                    Divider()
                    MenuItemView(imageName: "empty_icon", rowTitle: "Favorites") {
                        delegate?.didTapCollection(with: 0)
                    }
                    Divider()
                    MenuItemView(imageName: "prov_add_games_icon", rowTitle: "Add Collection") {
                        delegate?.didTapCollection(with: 0)
                    }
                    Divider()
                }
                Group {
                    MenuSectionHeaderView(sectionTitle: "Quick Settings", sortable: false) // TODO: move into settings screen when that's set up
                    Divider()
                    MenuItemView(imageName: "empty_icon", rowTitle: "Toggle New UI") {
                        delegate?.didTapToggleNewUI()
                    }
                    Divider()
                }
                Group {
                    MenuSectionHeaderView(sectionTitle: "Provenance 2.whatever", sortable: false)
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

@available(iOS 13.0.0, *)
struct MenuSectionHeaderView: View {
    
    var sectionTitle: String
    var sortable: Bool
    
    var body: some View {
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

@available(iOS 13.0.0, *)
struct MenuItemView: View {
    
    var imageName: String
    var rowTitle: String
    var action: () -> Void
    
    var body: some View {
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

@available(iOS 13.0.0, *)
struct SideMenuView_Previews: PreviewProvider {
    static var previews: some View {
        SideMenuView()
    }
}

#endif
