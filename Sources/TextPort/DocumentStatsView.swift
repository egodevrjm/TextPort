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

struct FileInfoView: View {
    let info: DocumentFileInfo

    var body: some View {
        Form {
            Section(info.fileName) {
                InfoRow(label: "State", value: info.stateLabel)
                InfoRow(label: "Save Behavior", value: info.saveBehavior)

                if let path = info.path {
                    InfoRow(label: "Path", value: path)
                }

                if let folder = info.folder {
                    InfoRow(label: "Folder", value: folder)
                }
            }

            Section("File") {
                if let fileSize = info.fileSize {
                    InfoRow(label: "Size on Disk", value: ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                } else {
                    InfoRow(label: "Size on Disk", value: "Not saved")
                }

                if let modifiedDate = info.modifiedDate {
                    InfoRow(label: "Modified", value: Self.dateFormatter.string(from: modifiedDate))
                }
            }

            Section("Text") {
                InfoRow(label: "Encoding", value: info.encoding)
                InfoRow(label: "Line Endings", value: info.lineEnding)
                InfoRow(label: "Syntax", value: info.syntax)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
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

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 20)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
