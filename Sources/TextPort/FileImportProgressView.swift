import SwiftUI

struct FileImportProgressView: View {
    let progress: FileImportProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)

                VStack(alignment: .leading, spacing: 4) {
                    Text(progress.title)
                        .font(.headline)

                    Text(progress.fileName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Text(progress.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 420, alignment: .leading)
    }
}
