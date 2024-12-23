import SwiftUI
import PVCoreBridge
import PVLibrary

/// A simple struct to hold core information for the list
private struct CoreListItem: Identifiable {
    let id: String
    let name: String
    let coreClass: CoreOptional.Type
    let optionCount: Int

    init(core: PVCore) {
        self.id = core.identifier
        self.name = core.projectName
        self.coreClass = NSClassFromString(core.principleClass) as! CoreOptional.Type
        self.optionCount = CoreListItem.countOptions(in: self.coreClass.options)
    }

    /// Recursively count all options, including those in groups
    private static func countOptions(in options: [CoreOption]) -> Int {
        options.reduce(0) { count, option in
            switch option {
            case .group(_, let subOptions):
                return count + countOptions(in: subOptions)
            case .bool, .string, .enumeration, .range, .rangef, .multi:
                return count + 1
            }
        }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text("\(item.optionCount) option\(item.optionCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
#if !os(tvOS)
            .background(Color(.secondarySystemGroupedBackground))
#endif
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
}
