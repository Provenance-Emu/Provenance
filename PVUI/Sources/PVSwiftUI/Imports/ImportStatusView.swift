
//
//  ImportStatusView.swift
//  PVUI
//
//  Created by David Proskin on 10/31/24.
//

import SwiftUI
import PVLibrary

public protocol ImportStatusDelegate : AnyObject {
    func dismissAction()
    func addImportsAction()
}

// View Model to manage import tasks
class ImportViewModel: ObservableObject {
    public let gameImporter = GameImporter.shared
}

// Individual Import Task Row View
struct ImportTaskRowView: View {
    let item: ImportItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.url.lastPathComponent)
                    .font(.headline)
                Text(item.status.description)
                    .font(.subheadline)
                    .foregroundColor(item.status.color)
            }
            
            Spacer()
            
            if item.status == .processing {
                ProgressView().progressViewStyle(.circular).frame(width: 40, height: 40, alignment: .center)
            } else {
                Image(systemName: item.status == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(item.status.color)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct ImportStatusView: View {
    @ObservedObject var updatesController: PVGameLibraryUpdatesController
    var viewModel:ImportViewModel
    weak var delegate:ImportStatusDelegate!
    
    var body: some View {
            NavigationView {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.gameImporter.importQueue) { item in
                            ImportTaskRowView(item: item).id(item.id)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Import Status")
                .navigationBarItems(
                    leading: Button("Done") { delegate.dismissAction() },
                    trailing:
                    Button("Import Files") {
                        delegate?.addImportsAction()
                    }
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
}

#Preview {

}
