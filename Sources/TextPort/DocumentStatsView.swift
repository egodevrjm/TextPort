import SwiftUI

struct DocumentStatsView: View {
    let stats: DocumentStats

    var body: some View {
        Form {
            Section(stats.fileName) {
                StatRow(label: "Lines", value: "\(stats.lines)")
                StatRow(label: "Words", value: "\(stats.words)")
                StatRow(label: "Characters", value: "\(stats.characters)")
                StatRow(label: "Bytes", value: ByteCountFormatter.string(fromByteCount: Int64(stats.bytes), countStyle: .file))

                if let fileSize = stats.fileSize {
                    StatRow(label: "File Size", value: ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                }
            }

            Section("Selection") {
                StatRow(label: "Lines", value: "\(stats.selectedLines)")
                StatRow(label: "Words", value: "\(stats.selectedWords)")
                StatRow(label: "Characters", value: "\(stats.selectedCharacters)")
                StatRow(label: "Bytes", value: ByteCountFormatter.string(fromByteCount: Int64(stats.selectedBytes), countStyle: .file))
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 360)
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
