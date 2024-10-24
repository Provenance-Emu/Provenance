//
//  NoConsolesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/22/24.
//

import SwiftUI

struct NoConsolesView: SwiftUI.View {
    weak var delegate: PVMenuDelegate!

    var body: some SwiftUI.View {
        VStack {
            Text("No Consoles")
                .tag("no consoles")

            Button(action: {
                delegate?.didTapAddGames()
            }) {
                HStack {
                    Image(systemName: "prov_add_games_icon") // Use the appropriate image name
                    Text("Add Games")
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
        .edgesIgnoringSafeArea(.all)
    }
}
