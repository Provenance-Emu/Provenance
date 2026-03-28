import SwiftUI

struct LibraryTabView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Library Coming Soon",
                systemImage: "books.vertical",
                description: Text("Browse your ROM library and metadata from the Provenance app.")
            )
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryTabView()
}
