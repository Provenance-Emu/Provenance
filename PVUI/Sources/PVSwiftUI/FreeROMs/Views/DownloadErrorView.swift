import SwiftUI

struct DownloadErrorView: View {
    let error: ROMDownloadManager.DownloadStatus.DownloadError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button(action: onRetry) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 22))
            }

            Text(error.localizedDescription)
                .font(.caption2)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 150)
        }
    }
}
