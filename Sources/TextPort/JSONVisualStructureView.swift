import SwiftUI

struct JSONVisualStructureView: View {
    let documentName: String
    private let parseResult: Result<JSONPreviewValue, Error>

    @Environment(\.dismiss) private var dismiss

    init(documentName: String, json: String) {
        self.documentName = documentName
        self.parseResult = JSONPreviewParser.parse(json)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            switch parseResult {
            case .success(let value):
                JSONVisualContentView(root: value)
            case .failure(let error):
                PreviewUnavailableView(
                    title: "Invalid JSON",
                    message: "TextPort could not visualize this JSON. \(error.localizedDescription)"
                )
            }
        }
        .frame(minWidth: 820, idealWidth: 940, minHeight: 560, idealHeight: 680)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("JSON Visual Structure")
                    .font(.headline)

                Text(documentName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }
}

private struct JSONVisualContentView: View {
    let root: JSONPreviewValue

    private var stats: JSONVisualStats {
        JSONVisualStats.make(from: root)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summary

                JSONVisualSection(
                    title: "Root",
                    path: "$",
                    value: root,
                    depth: 0
                )
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(root.typeLabel)
                .font(.title2.weight(.semibold))

            HStack(spacing: 8) {
                JSONStatChip(label: "Objects", value: stats.objects)
                JSONStatChip(label: "Arrays", value: stats.arrays)
                JSONStatChip(label: "Fields", value: stats.fields)
                JSONStatChip(label: "Values", value: stats.values)
                JSONStatChip(label: "Depth", value: stats.maxDepth)
            }
        }
        .padding(.bottom, 2)
    }
}

private struct JSONVisualSection: View {
    let title: String
    let path: String
    let value: JSONPreviewValue
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(sectionFont)
                    .lineLimit(1)

                Text(value.compactSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())

                Spacer()
            }

            Text(path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            content
        }
        .padding(.leading, CGFloat(depth) * 16)
    }

    private var sectionFont: Font {
        depth == 0 ? .title3.weight(.semibold) : .headline
    }

    @ViewBuilder
    private var content: some View {
        switch value {
        case .object(let entries):
            JSONVisualObjectView(entries: entries, path: path, depth: depth)
        case .array(let values):
            JSONVisualArrayView(values: values, path: path, depth: depth)
        case .string(let string):
            JSONScalarRow(label: title, value: string, type: "String")
        case .number(let number):
            JSONScalarRow(label: title, value: number, type: "Number")
        case .bool(let bool):
            JSONScalarRow(label: title, value: bool ? "true" : "false", type: "Boolean")
        case .null:
            JSONScalarRow(label: title, value: "null", type: "Null")
        }
    }
}

private struct JSONVisualObjectView: View {
    let entries: [JSONPreviewObjectEntry]
    let path: String
    let depth: Int

    private var scalarEntries: [JSONPreviewObjectEntry] {
        entries.filter { $0.value.isScalar }
    }

    private var nestedEntries: [JSONPreviewObjectEntry] {
        entries.filter { !$0.value.isScalar }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !scalarEntries.isEmpty {
                JSONScalarGroup(entries: scalarEntries)
            }

            ForEach(nestedEntries) { entry in
                JSONVisualSection(
                    title: entry.key.humanizedJSONKey,
                    path: "\(path).\(entry.key)",
                    value: entry.value,
                    depth: depth + 1
                )
            }
        }
    }
}

private struct JSONVisualArrayView: View {
    let values: [JSONPreviewValue]
    let path: String
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if values.isEmpty {
                Text("Empty array")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let table = JSONVisualTable.make(from: values) {
                JSONVisualTableView(table: table)
            } else if values.allSatisfy(\.isScalar) {
                JSONScalarValueGrid(values: values)
            } else {
                ForEach(Array(values.prefix(12).enumerated()), id: \.offset) { index, value in
                    JSONVisualSection(
                        title: "Item \(index + 1)",
                        path: "\(path)[\(index)]",
                        value: value,
                        depth: depth + 1
                    )
                }

                if values.count > 12 {
                    Text("\(values.count - 12) more items not shown in this summary.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct JSONScalarGroup: View {
    let entries: [JSONPreviewObjectEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries) { entry in
                JSONScalarRow(
                    label: entry.key.humanizedJSONKey,
                    value: entry.value.scalarDisplayValue,
                    type: entry.value.typeLabel
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 0.5)
        )
    }
}

private struct JSONScalarRow: View {
    let label: String
    let value: String
    let type: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.callout.weight(.medium))

                Text(type)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 170, alignment: .leading)

            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.6))
                .frame(height: 0.5)
        }
    }
}

private struct JSONScalarValueGrid: View {
    let values: [JSONPreviewValue]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(Array(values.prefix(40).enumerated()), id: \.offset) { _, value in
                Text(value.scalarDisplayValue)
                    .font(.callout)
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            }
        }

        if values.count > 40 {
            Text("\(values.count - 40) more values not shown in this summary.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct JSONVisualTableView: View {
    let table: JSONVisualTable

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Records")
                .font(.callout.weight(.semibold))

            ScrollView(.horizontal) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(table.columns, id: \.self) { column in
                            tableCell(column.humanizedJSONKey, isHeader: true)
                        }
                    }

                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(table.columns, id: \.self) { column in
                                tableCell(row[column] ?? "", isHeader: false)
                            }
                        }
                    }
                }
            }

            if table.wasTruncated {
                Text("Showing the first \(table.rows.count) records and \(table.columns.count) fields.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tableCell(_ value: String, isHeader: Bool) -> some View {
        Text(value.isEmpty ? " " : value)
            .font(.system(size: 12, weight: isHeader ? .semibold : .regular))
            .foregroundStyle(isHeader ? .primary : .secondary)
            .lineLimit(2)
            .textSelection(.enabled)
            .frame(width: 150, alignment: .leading)
            .frame(minHeight: 30, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHeader ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .textBackgroundColor))
            .overlay(
                Rectangle()
                    .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 0.5)
            )
    }
}

private struct JSONStatChip: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
    }
}

private struct JSONVisualTable {
    let columns: [String]
    let rows: [[String: String]]
    let wasTruncated: Bool

    static func make(from values: [JSONPreviewValue], rowLimit: Int = 25, columnLimit: Int = 8) -> JSONVisualTable? {
        let objects = values.compactMap { value -> [JSONPreviewObjectEntry]? in
            guard case .object(let entries) = value else { return nil }
            return entries
        }

        guard objects.count == values.count, !objects.isEmpty else { return nil }

        var columns: [String] = []
        for object in objects {
            for entry in object where entry.value.isScalar && !columns.contains(entry.key) {
                columns.append(entry.key)
            }
        }

        guard !columns.isEmpty else { return nil }

        let limitedColumns = Array(columns.prefix(columnLimit))
        let rows = objects.prefix(rowLimit).map { entries in
            Dictionary(uniqueKeysWithValues: limitedColumns.map { column in
                let value = entries.first(where: { $0.key == column })?.value.scalarDisplayValue ?? ""
                return (column, value)
            })
        }

        return JSONVisualTable(
            columns: limitedColumns,
            rows: rows,
            wasTruncated: values.count > rowLimit || columns.count > columnLimit
        )
    }
}

private struct JSONVisualStats {
    let objects: Int
    let arrays: Int
    let fields: Int
    let values: Int
    let maxDepth: Int

    static func make(from value: JSONPreviewValue) -> JSONVisualStats {
        value.stats(depth: 1)
    }

    static func + (lhs: JSONVisualStats, rhs: JSONVisualStats) -> JSONVisualStats {
        JSONVisualStats(
            objects: lhs.objects + rhs.objects,
            arrays: lhs.arrays + rhs.arrays,
            fields: lhs.fields + rhs.fields,
            values: lhs.values + rhs.values,
            maxDepth: max(lhs.maxDepth, rhs.maxDepth)
        )
    }
}

private extension JSONPreviewValue {
    var isScalar: Bool {
        switch self {
        case .object, .array:
            return false
        case .string, .number, .bool, .null:
            return true
        }
    }

    var typeLabel: String {
        switch self {
        case .object:
            return "Object"
        case .array:
            return "Array"
        case .string:
            return "String"
        case .number:
            return "Number"
        case .bool:
            return "Boolean"
        case .null:
            return "Null"
        }
    }

    var compactSummary: String {
        switch self {
        case .object(let entries):
            return entries.count == 1 ? "1 field" : "\(entries.count) fields"
        case .array(let values):
            return values.count == 1 ? "1 item" : "\(values.count) items"
        case .string(let string):
            return string.isEmpty ? "Empty string" : "String"
        case .number:
            return "Number"
        case .bool:
            return "Boolean"
        case .null:
            return "Null"
        }
    }

    var scalarDisplayValue: String {
        switch self {
        case .object(let entries):
            return entries.count == 1 ? "1 field" : "\(entries.count) fields"
        case .array(let values):
            return values.count == 1 ? "1 item" : "\(values.count) items"
        case .string(let string):
            return string.isEmpty ? "(empty)" : string
        case .number(let number):
            return number
        case .bool(let bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        }
    }

    func stats(depth: Int) -> JSONVisualStats {
        switch self {
        case .object(let entries):
            let childStats = entries.reduce(JSONVisualStats(objects: 0, arrays: 0, fields: 0, values: 0, maxDepth: depth)) { partial, entry in
                partial + entry.value.stats(depth: depth + 1)
            }
            return JSONVisualStats(objects: 1, arrays: 0, fields: entries.count, values: 0, maxDepth: depth) + childStats
        case .array(let values):
            let childStats = values.reduce(JSONVisualStats(objects: 0, arrays: 0, fields: 0, values: 0, maxDepth: depth)) { partial, value in
                partial + value.stats(depth: depth + 1)
            }
            return JSONVisualStats(objects: 0, arrays: 1, fields: 0, values: 0, maxDepth: depth) + childStats
        case .string, .number, .bool, .null:
            return JSONVisualStats(objects: 0, arrays: 0, fields: 0, values: 1, maxDepth: depth)
        }
    }
}

private extension String {
    var humanizedJSONKey: String {
        guard !isEmpty else { return self }

        let spaced = replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .unicodeScalars.reduce(into: "") { result, scalar in
                let character = Character(scalar)
                if CharacterSet.uppercaseLetters.contains(scalar), !result.isEmpty, result.last != " " {
                    result.append(" ")
                }
                result.append(character)
            }

        return spaced
            .split(separator: " ")
            .map { word in
                let lowercased = word.lowercased()
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }
}
