import SwiftUI

struct ArtworkThumbnail: View {
    let url: URL
    let onTap: () -> Void

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 44, height: 44)
            case .success(let image):
                image.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(radius: 2)
            case .failure:
                Image(systemName: "photo")
                    .frame(width: 44, height: 44)
                    .foregroundColor(.secondary)
            @unknown default:
                EmptyView()
            }
        }
        .onTapGesture(perform: onTap)
    }
}
