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
            case .success(let root):
                JSONVisualDashboard(root: root)
            case .failure(let error):
                PreviewUnavailableView(
                    title: "Invalid JSON",
                    message: "TextPort could not visualize this JSON. \(error.localizedDescription)"
                )
            }
        }
        .frame(minWidth: 880, idealWidth: 980, minHeight: 580, idealHeight: 700)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "curlybraces")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Visualize JSON")
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
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct JSONVisualDashboard: View {
    let root: JSONPreviewValue

    private var stats: JSONVisualStats {
        root.stats(depth: 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            JSONStructureSidebar(root: root, stats: stats)
                .frame(width: 230)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    JSONSectionView(title: "Root", path: "$", value: root, depth: 0)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}

private struct JSONStructureSidebar: View {
    let root: JSONPreviewValue
    let stats: JSONVisualStats

    private var outlineItems: [JSONOutlineItem] {
        root.outline(path: "$", name: "Root", depth: 0, maxDepth: 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(root.typeLabel)
                    .font(.title3.weight(.semibold))

                Text(root.compactSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                JSONMetricRow(label: "Objects", value: stats.objects)
                JSONMetricRow(label: "Arrays", value: stats.arrays)
                JSONMetricRow(label: "Fields", value: stats.fields)
                JSONMetricRow(label: "Values", value: stats.values)
                JSONMetricRow(label: "Depth", value: stats.maxDepth)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Structure")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(outlineItems.prefix(12)) { item in
                    HStack(spacing: 7) {
                        Image(systemName: item.iconName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 14)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Text(item.summary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, CGFloat(item.depth) * 10)
                }
            }

            Spacer()
        }
        .padding(18)
        .background(.bar)
    }
}

private struct JSONSectionView: View {
    let title: String
    let path: String
    let value: JSONPreviewValue
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(depth == 0 ? .title2.weight(.semibold) : .headline)

                Text(value.compactSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            switch value {
            case .object(let entries):
                JSONObjectSummary(entries: entries, path: path, depth: depth)
            case .array(let values):
                JSONArraySummary(values: values, path: path, depth: depth)
            case .string, .number, .bool, .null:
                JSONFieldRow(name: title, value: value)
            }
        }
    }
}

private struct JSONObjectSummary: View {
    let entries: [JSONPreviewObjectEntry]
    let path: String
    let depth: Int

    private var scalarEntries: [JSONPreviewObjectEntry] {
        entries.filter(\.value.isScalar)
    }

    private var nestedEntries: [JSONPreviewObjectEntry] {
        entries.filter { !$0.value.isScalar }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if scalarEntries.isEmpty && nestedEntries.isEmpty {
                Text("Empty object")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !scalarEntries.isEmpty {
                JSONFieldList(entries: scalarEntries)
            }

            if !nestedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(nestedEntries) { entry in
                        JSONSectionView(
                            title: entry.key.humanizedJSONKey,
                            path: "\(path).\(entry.key)",
                            value: entry.value,
                            depth: depth + 1
                        )
                    }
                }
                .padding(.leading, depth == 0 ? 0 : 12)
            }
        }
    }
}

private struct JSONArraySummary: View {
    let values: [JSONPreviewValue]
    let path: String
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if values.isEmpty {
                Text("Empty array")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let table = JSONRecordTable.make(from: values) {
                JSONRecordTableView(table: table)
            } else if values.allSatisfy(\.isScalar) {
                JSONScalarFlow(values: values)
            } else {
                ForEach(Array(values.prefix(10).enumerated()), id: \.offset) { index, value in
                    JSONSectionView(
                        title: "Item \(index + 1)",
                        path: "\(path)[\(index)]",
                        value: value,
                        depth: depth + 1
                    )
                }

                if values.count > 10 {
                    Text("\(values.count - 10) more items hidden from this summary.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct JSONFieldList: View {
    let entries: [JSONPreviewObjectEntry]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                JSONFieldRow(name: entry.key.humanizedJSONKey, value: entry.value)

                if entry.id != entries.last?.id {
                    Divider()
                }
            }
        }
    }
}

private struct JSONFieldRow: View {
    let name: String
    let value: JSONPreviewValue

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Text(value.typeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 170, alignment: .leading)

            Text(value.displayValue)
                .font(.callout)
                .lineLimit(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

private struct JSONRecordTableView: View {
    let table: JSONRecordTable

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Records")
                .font(.callout.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(table.columns, id: \.self) { column in
                            JSONTableCell(column.humanizedJSONKey, isHeader: true)
                        }
                    }

                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(table.columns, id: \.self) { column in
                                JSONTableCell(row[column] ?? "", isHeader: false)
                            }
                        }
                    }
                }
            }

            if table.wasTruncated {
                Text("Showing \(table.rows.count) records and \(table.columns.count) fields.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct JSONTableCell: View {
    let value: String
    let isHeader: Bool

    init(_ value: String, isHeader: Bool) {
        self.value = value
        self.isHeader = isHeader
    }

    var body: some View {
        Text(value.isEmpty ? " " : value)
            .font(.system(size: 12, weight: isHeader ? .semibold : .regular))
            .foregroundStyle(isHeader ? .primary : .secondary)
            .lineLimit(2)
            .textSelection(.enabled)
            .frame(width: 155, alignment: .leading)
            .frame(minHeight: 30, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHeader ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.7))
                    .frame(height: 0.5)
            }
    }
}

private struct JSONScalarFlow: View {
    let values: [JSONPreviewValue]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(Array(values.prefix(48).enumerated()), id: \.offset) { _, value in
                Text(value.displayValue)
                    .font(.callout)
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .padding(.vertical, 5)
            }
        }

        if values.count > 48 {
            Text("\(values.count - 48) more values hidden from this summary.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct JSONMetricRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
        }
        .font(.caption)
    }
}

private struct JSONRecordTable {
    let columns: [String]
    let rows: [[String: String]]
    let wasTruncated: Bool

    static func make(from values: [JSONPreviewValue], rowLimit: Int = 30, columnLimit: Int = 9) -> JSONRecordTable? {
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
        let rows = objects.prefix(rowLimit).map { object in
            Dictionary(uniqueKeysWithValues: limitedColumns.map { column in
                let value = object.first(where: { $0.key == column })?.value.displayValue ?? ""
                return (column, value)
            })
        }

        return JSONRecordTable(
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

private struct JSONOutlineItem: Identifiable {
    let id: String
    let name: String
    let summary: String
    let iconName: String
    let depth: Int
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

    var displayValue: String {
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

    var iconName: String {
        switch self {
        case .object:
            return "curlybraces"
        case .array:
            return "list.bullet.rectangle"
        case .string:
            return "textformat"
        case .number:
            return "number"
        case .bool:
            return "switch.2"
        case .null:
            return "circle.dotted"
        }
    }

    func stats(depth: Int) -> JSONVisualStats {
        switch self {
        case .object(let entries):
            let base = JSONVisualStats(objects: 1, arrays: 0, fields: entries.count, values: 0, maxDepth: depth)
            return entries.reduce(base) { partial, entry in
                partial + entry.value.stats(depth: depth + 1)
            }
        case .array(let values):
            let base = JSONVisualStats(objects: 0, arrays: 1, fields: 0, values: 0, maxDepth: depth)
            return values.reduce(base) { partial, value in
                partial + value.stats(depth: depth + 1)
            }
        case .string, .number, .bool, .null:
            return JSONVisualStats(objects: 0, arrays: 0, fields: 0, values: 1, maxDepth: depth)
        }
    }

    func outline(path: String, name: String, depth: Int, maxDepth: Int) -> [JSONOutlineItem] {
        guard depth <= maxDepth else { return [] }

        var items = [
            JSONOutlineItem(
                id: path,
                name: name,
                summary: compactSummary,
                iconName: iconName,
                depth: depth
            )
        ]

        switch self {
        case .object(let entries):
            for entry in entries where !entry.value.isScalar {
                items += entry.value.outline(
                    path: "\(path).\(entry.key)",
                    name: entry.key.humanizedJSONKey,
                    depth: depth + 1,
                    maxDepth: maxDepth
                )
            }
        case .array(let values):
            if let first = values.first, !first.isScalar {
                items += first.outline(
                    path: "\(path)[0]",
                    name: "Items",
                    depth: depth + 1,
                    maxDepth: maxDepth
                )
            }
        case .string, .number, .bool, .null:
            break
        }

        return items
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
