import SwiftUI

struct ArtworkFullscreenView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                        Text("Failed to load image")
                    }
                    .foregroundColor(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
        }
#if !os(tvOS)
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    if gesture.translation.height > 100 {
                        dismiss()
                    }
                }
        )
#endif
        .onTapGesture {
            dismiss()
        }
    }
}
