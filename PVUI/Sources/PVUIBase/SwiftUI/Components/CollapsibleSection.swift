//
//  CollapsibleSection.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/9/24.
//

import SwiftUI
import PVSettings
import Defaults
import Combine

/// Lets a parent (e.g. settings search) force a `CollapsibleSection` open by its title.
public enum CollapsibleSectionExpansion {
    private static let requests = PassthroughSubject<String, Never>()

    /// Emits the title of every section that was asked to expand.
    static let publisher: AnyPublisher<String, Never> = requests.eraseToAnyPublisher()

    /// Expands the section titled `title`. The persisted collapse state is cleared first, so a section that
    /// is built later (tab content is recreated on tab switch) starts expanded, and one that is already
    /// on screen is told to open.
    public static func expand(title: String) {
        Defaults[.collapsedSections].remove(title)
        requests.send(title)
    }
}

public struct CollapsibleSection<Content: View>: View {
    public let title: String
    public let content: Content
    /// Source of truth while on screen; persisted to `Defaults[.collapsedSections]` on toggle. Deliberately
    /// not `@Default`, which would invalidate every sibling section whenever any one of them toggles.
    @State private var isExpanded: Bool

    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self._isExpanded = State(initialValue: !Defaults[.collapsedSections].contains(title))
    }

    public var body: some View {
        SwiftUI.Section {
            if isExpanded {
                content
                    .padding(.vertical, 8)
            }
        } header: {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                    if isExpanded {
                        Defaults[.collapsedSections].remove(title)
                    } else {
                        Defaults[.collapsedSections].insert(title)
                    }
                }
            }) {
                HStack {
                    // Retrowave styled section header
                    Text(title.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .retroPink.opacity(0.5), radius: 2, x: 0, y: 0)
                        .padding(.leading, 8)
                    
                    Spacer()
                    
                    // Animated chevron with glow effect
                    ZStack {
                        Image(systemName: "hexagon.fill")
                            .foregroundColor(.black.opacity(0.7))
                            .font(.system(size: 24))
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPink]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .font(.system(size: 12, weight: .bold))
                            .shadow(color: .retroBlue.opacity(0.8), radius: 3, x: 0, y: 0)
                    }
                    .rotationEffect(Angle(degrees: isExpanded ? 0 : 180))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroPink.opacity(0.7), .retroBlue.opacity(0.7)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
            }
            // The header is always present (the body may be collapsed), so it is the stable scroll target
            // for `ScrollViewReader.scrollTo(title)`.
            .id(title)
            .onReceive(CollapsibleSectionExpansion.publisher) { requestedTitle in
                guard requestedTitle == title, !isExpanded else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = true
                }
            }
        }
    }
}
