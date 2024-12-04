import SwiftUI
import PVCoreBridge
import PVLibrary

/// A simple struct to hold core information for the list
private struct CoreListItem: Identifiable {
    let id: String
    let name: String
    let coreClass: CoreOptional.Type

    init(core: PVCore) {
        self.id = core.identifier
        self.name = core.projectName
        self.coreClass = NSClassFromString(core.principleClass) as! CoreOptional.Type
    }
}

/// View that lists all cores that implement CoreOptional
struct CoreOptionsListView: View {
    @StateObject private var viewModel = CoreOptionsViewModel()

    private var coreItems: [CoreListItem] {
        viewModel.availableCores.compactMap { core in
            guard let _ = NSClassFromString(core.principleClass) as? CoreOptional.Type else {
                return nil
            }
            return CoreListItem(core: core)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(coreItems) { item in
                    CoreListItemView(item: item)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Core Options")
    }
}

/// View for a single core item in the list
private struct CoreListItemView: View {
    let item: CoreListItem

    var body: some View {
        NavigationLink {
            CoreOptionsDetailView(coreClass: item.coreClass, title: item.name)
        } label: {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
}
