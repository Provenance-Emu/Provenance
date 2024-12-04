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
            guard let coreClass = NSClassFromString(core.principleClass) as? CoreOptional.Type else {
                return nil
            }

            // Check if the core has any meaningful options
            let hasOptions = hasValidOptions(in: coreClass.options)
            guard hasOptions else {
                return nil
            }

            return CoreListItem(core: core)
        }
    }

    /// Recursively check if there are any meaningful options in the array
    private func hasValidOptions(in options: [CoreOption]) -> Bool {
        for option in options {
            switch option {
            case .group(_, let subOptions):
                // Recursively check group's options
                if hasValidOptions(in: subOptions) {
                    return true
                }
            case .bool, .string, .enumeration, .range, .rangef, .multi:
                // Any non-group option is considered valid
                return true
            }
        }
        return false
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
