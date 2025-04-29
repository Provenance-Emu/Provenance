//
//  PaginatedSyncDifferencesView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/27/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVUIBase
import PVLogging

/// A view that displays sync differences with pagination
public struct PaginatedSyncDifferencesView: View {
    /// The view model
    @ObservedObject var viewModel: UnifiedCloudSyncViewModel
    
    /// Whether to show the copied toast
    @State private var showCopiedToast = false
    
    /// The copied item
    @State private var copiedItem: String = ""
    
    /// Whether reduced motion is enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sync Differences")
                    .retroSectionHeader()
                
                Spacer()
                
                // Page indicator
                if viewModel.syncDifferences.count > viewModel.itemsPerPage {
                    Text("Page \(viewModel.currentPage + 1) of \(viewModel.totalPages)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if viewModel.syncDifferences.isEmpty {
                Text("No sync differences found")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 4) {
                    ForEach(viewModel.paginatedDifferences, id: \.self) { difference in
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.yellow)
                            
                            Text(difference)
                                .foregroundColor(.white)
                                .font(.footnote)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: {
                                // Copy to clipboard
                                UIPasteboard.general.string = difference
                                copiedItem = difference
                                showCopiedToast = true
                                HapticFeedbackService.shared.playSuccess()
                                
                                // Hide toast after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showCopiedToast = false
                                    }
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.retroBlack.opacity(0.3))
                        .cornerRadius(6)
                        #if !os(tvOS)
                        .withHapticFeedback(style: .light)
                        #endif
                    }
                }
                .padding()
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(10)
                
                // Pagination controls
                if viewModel.syncDifferences.count > viewModel.itemsPerPage {
                    HStack {
                        Button(action: {
                            withAnimation {
                                viewModel.previousPage()
                            }
                            HapticFeedbackService.shared.playSelection()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(viewModel.currentPage > 0 ? .white : .gray)
                        }
                        .disabled(viewModel.currentPage <= 0)
                        
                        Spacer()
                        
                        // Items per page selector
                        Menu {
                            Button("10 per page") { 
                                viewModel.itemsPerPage = 10
                                HapticFeedbackService.shared.playSelection()
                            }
                            Button("20 per page") { 
                                viewModel.itemsPerPage = 20
                                HapticFeedbackService.shared.playSelection()
                            }
                            Button("50 per page") { 
                                viewModel.itemsPerPage = 50
                                HapticFeedbackService.shared.playSelection()
                            }
                        } label: {
                            HStack {
                                Text("\(viewModel.itemsPerPage) per page")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                viewModel.nextPage()
                            }
                            HapticFeedbackService.shared.playSelection()
                        }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(viewModel.currentPage < viewModel.totalPages - 1 ? .white : .gray)
                        }
                        .disabled(viewModel.currentPage >= viewModel.totalPages - 1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.retroBlack.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            
            // Copied to clipboard toast
            if showCopiedToast {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Copied to clipboard")
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.retroBlack.opacity(0.8))
                .cornerRadius(8)
                .transitionWithReducedMotion(
                    .move(edge: .bottom).combined(with: .opacity),
                    fallbackTransition: .opacity
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .zIndex(1)
            }
        }
    }
}

#Preview {
    PaginatedSyncDifferencesView(viewModel: UnifiedCloudSyncViewModel())
        .preferredColorScheme(.dark)
        .padding()
        .background(Color.black)
}
