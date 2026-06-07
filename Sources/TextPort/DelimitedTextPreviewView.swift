import SwiftUI

enum DelimitedTextDelimiter {
    case comma
    case tab

    var character: Character {
        switch self {
        case .comma: ","
        case .tab: "\t"
        }
    }

    var label: String {
        switch self {
        case .comma: "CSV"
        case .tab: "TSV"
        }
    }
}

struct DelimitedTextPreviewView: View {
    let text: String
    let delimiter: DelimitedTextDelimiter

    private var previewData: DelimitedTextPreviewData {
        DelimitedTextParser.parse(text, delimiter: delimiter.character)
    }

    var body: some View {
        let data = previewData

        VStack(spacing: 0) {
            if data.rows.isEmpty {
                PreviewUnavailableView(
                    title: "No Table Data",
                    message: "This \(delimiter.label) file is empty."
                )
            } else {
                table(for: data)

                if data.wasTruncated {
                    Divider()
                    Text("Preview limited to \(data.rows.count) rows and \(data.columnCount) columns.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.bar)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func table(for data: DelimitedTextPreviewData) -> some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(data.rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        rowNumberCell(rowIndex + 1, isHeader: rowIndex == 0)

                        ForEach(0..<data.columnCount, id: \.self) { columnIndex in
                            tableCell(
                                value: columnIndex < row.count ? row[columnIndex] : "",
                                isHeader: rowIndex == 0
                            )
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    private func rowNumberCell(_ number: Int, isHeader: Bool) -> some View {
        Text("\(number)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(width: 48, height: 32, alignment: .trailing)
            .padding(.horizontal, 8)
            .background(isHeader ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .textBackgroundColor))
            .overlay(cellBorder)
    }

    private func tableCell(value: String, isHeader: Bool) -> some View {
        Text(value.isEmpty ? " " : value)
            .font(.system(size: 12, weight: isHeader ? .semibold : .regular, design: .default))
            .foregroundStyle(isHeader ? .primary : .secondary)
            .lineLimit(2)
            .textSelection(.enabled)
            .frame(width: 160, height: 32, alignment: .leading)
            .padding(.horizontal, 8)
            .background(isHeader ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .textBackgroundColor))
            .overlay(cellBorder)
    }

    private var cellBorder: some View {
        Rectangle()
            .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 0.5)
    }
}

private struct DelimitedTextPreviewData {
    let rows: [[String]]
    let columnCount: Int
    let wasTruncated: Bool
}

private enum DelimitedTextParser {
    static func parse(
        _ text: String,
        delimiter: Character,
        rowLimit: Int = 500,
        columnLimit: Int = 60
    ) -> DelimitedTextPreviewData {
        guard !text.isEmpty else {
            return DelimitedTextPreviewData(rows: [], columnCount: 0, wasTruncated: false)
        }

        var rows: [[String]] = []
        var currentRow: [String] = []
        var field = ""
        var isQuoted = false
        var columnCount = 0
        var wasTruncated = false
        var index = text.startIndex

        func finishRow() {
            currentRow.append(field)
            columnCount = min(max(columnCount, currentRow.count), columnLimit)

            if currentRow.count > columnLimit {
                wasTruncated = true
            }

            if rows.count < rowLimit {
                rows.append(Array(currentRow.prefix(columnLimit)))
            } else {
                wasTruncated = true
            }

            currentRow.removeAll(keepingCapacity: true)
            field.removeAll(keepingCapacity: true)
        }

        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)

            if isQuoted {
                if character == "\"" {
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        field.append("\"")
                        index = text.index(after: nextIndex)
                    } else {
                        isQuoted = false
                        index = nextIndex
                    }
                } else {
                    field.append(character)
                    index = nextIndex
                }
                continue
            }

            if character == "\"", field.isEmpty {
                isQuoted = true
                index = nextIndex
            } else if character == delimiter {
                currentRow.append(field)
                field.removeAll(keepingCapacity: true)
                index = nextIndex
            } else if character == "\n" {
                finishRow()
                index = nextIndex
            } else if character == "\r" {
                finishRow()
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    index = text.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
            } else {
                field.append(character)
                index = nextIndex
            }

            if rows.count >= rowLimit, index < text.endIndex {
                wasTruncated = true
                break
            }
        }

        if !field.isEmpty || !currentRow.isEmpty || text.last == delimiter {
            finishRow()
        }

        return DelimitedTextPreviewData(rows: rows, columnCount: columnCount, wasTruncated: wasTruncated)
    }
}
