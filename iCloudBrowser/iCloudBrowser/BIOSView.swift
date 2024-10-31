//
//  ContentView.swift
//  Message in a Bottle
//
//  Created by Drew McCormack on 09/02/2023.
//

import SwiftUI

struct BottleView: View {
    @EnvironmentObject var store: Store
    @State var displayedText: String = ""
    var body: some View {
        ZStack {
            Image(systemName: "wineglass") // close enough
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200)
                .foregroundColor(.accentColor)
            TextField("Enter a Message", text: $displayedText)
                .multilineTextAlignment(.center)
                .offset(y: -50)
                .frame(maxWidth: 150)
                .onSubmit {
                    store.text = displayedText
                }
        }
        .padding()
        .onChange(of: store.text) { newValue in
            displayedText = store.text
        }
    }
}

struct BottleViewPreviews: PreviewProvider {
    static var previews: some View {
        BottleView(displayedText: "Message")
            .environmentObject(Store())
    }
}
