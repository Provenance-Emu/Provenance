import SwiftUI
import PVCoreBridge
import PVLibrary

/// View that displays and allows editing of core options for a specific core
struct CoreOptionsDetailView: View {
    let coreClass: CoreOptional.Type
    let title: String

    private var groupedOptions: [(title: String, options: [CoreOption])] {
        var rootOptions = [CoreOption]()
        var groups = [(title: String, options: [CoreOption])]()

        // Process options into groups
        coreClass.options.forEach { option in
            switch option {
            case let .group(display, subOptions):
                groups.append((title: display.title, options: subOptions))
            default:
                rootOptions.append(option)
            }
        }

        // Add root options as first group if any exist
        if !rootOptions.isEmpty {
            groups.insert((title: "General", options: rootOptions), at: 0)
        }

        return groups
    }

    var body: some View {
        List {
            ForEach(groupedOptions.indices, id: \.self) { sectionIndex in
                let group = groupedOptions[sectionIndex]
                Section(header: Text(group.title)) {
                    ForEach(group.options.indices, id: \.self) { optionIndex in
                        let option = group.options[optionIndex]
                        optionView(for: option)
                    }
                }
            }
        }
        .navigationTitle(title)
    }

    @ViewBuilder
    private func optionView(for option: CoreOption) -> some View {
        switch option {
        case let .bool(display, defaultValue):
            Toggle(isOn: Binding(
                get: { coreClass.storedValueForOption(Bool.self, option.key) ?? defaultValue },
                set: { coreClass.setValue($0, forOption: option) }
            )) {
                VStack(alignment: .leading) {
                    Text(display.title)
                    if let description = display.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

        case let .enumeration(display, values, defaultValue):
            let selection = Binding(
                get: { coreClass.storedValueForOption(Int.self, option.key) ?? defaultValue },
                set: { coreClass.setValue($0, forOption: option) }
            )

            NavigationLink {
                List {
                    ForEach(values, id: \.value) { value in
                        Button {
                            selection.wrappedValue = value.value
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(value.title)
                                    if let description = value.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if value.value == selection.wrappedValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .navigationTitle(display.title)
            } label: {
                VStack(alignment: .leading) {
                    Text(display.title)
                    if let description = display.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(values.first { $0.value == selection.wrappedValue }?.title ?? "")
                        .foregroundColor(.secondary)
                }
            }

        case let .range(display, range, defaultValue):
            VStack(alignment: .leading) {
                Text(display.title)
                if let description = display.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(coreClass.storedValueForOption(Int.self, option.key) ?? defaultValue) },
                        set: { coreClass.setValue(Int($0), forOption: option) }
                    ),
                    in: Double(range.min)...Double(range.max),
                    step: 1
                ) {
                    Text(display.title)
                } minimumValueLabel: {
                    Text("\(range.min)")
                } maximumValueLabel: {
                    Text("\(range.max)")
                }
            }

        case let .rangef(display, range, defaultValue):
            VStack(alignment: .leading) {
                Text(display.title)
                if let description = display.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(coreClass.storedValueForOption(Float.self, option.key) ?? defaultValue) },
                        set: { coreClass.setValue(Float($0), forOption: option) }
                    ),
                    in: Double(range.min)...Double(range.max),
                    step: 0.1
                ) {
                    Text(display.title)
                } minimumValueLabel: {
                    Text(String(format: "%.1f", range.min))
                } maximumValueLabel: {
                    Text(String(format: "%.1f", range.max))
                }
            }

        case let .multi(display, values):
            let selection = Binding(
                get: { coreClass.storedValueForOption(String.self, option.key) ?? values.first?.title ?? "" },
                set: { coreClass.setValue($0, forOption: option) }
            )

            NavigationLink {
                List {
                    ForEach(values, id: \.title) { value in
                        Button {
                            selection.wrappedValue = value.title
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(value.title)
                                    if let description = value.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if value.title == selection.wrappedValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .navigationTitle(display.title)
            } label: {
                VStack(alignment: .leading) {
                    Text(display.title)
                    if let description = display.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(selection.wrappedValue)
                        .foregroundColor(.secondary)
                }
            }

        case let .string(display, defaultValue):
            let text = Binding(
                get: { coreClass.storedValueForOption(String.self, option.key) ?? defaultValue },
                set: { coreClass.setValue($0, forOption: option) }
            )

            VStack(alignment: .leading) {
                Text(display.title)
                if let description = display.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                TextField("Value", text: text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

        case .group(_, _):
            EmptyView() // Groups are handled at the section level
        }
    }
}
