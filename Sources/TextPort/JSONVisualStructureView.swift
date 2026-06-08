import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct JSONVisualStructureView: View {
    let documentName: String
    private let parseResult: Result<JSONPreviewValue, Error>

    @Environment(\.dismiss) private var dismiss
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""

    init(documentName: String, json: String) {
        self.documentName = documentName
        self.parseResult = JSONPreviewParser.parse(json)
    }

    var body: some View {
        VStack(spacing: 0) {
            header(root: parsedRoot)
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
        .frame(minWidth: 920, idealWidth: 1_040, minHeight: 600, idealHeight: 720)
        .alert("Could Not Export", isPresented: $showingExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
    }

    private var parsedRoot: JSONPreviewValue? {
        guard case .success(let root) = parseResult else { return nil }
        return root
    }

    private func header(root: JSONPreviewValue?) -> some View {
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

            Button {
                guard let root else { return }
                export(root)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(root == nil)
            .help("Export Visual HTML")

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func export(_ root: JSONPreviewValue) {
        do {
            _ = try JSONVisualHTMLExporter.export(root: root, documentName: documentName)
        } catch {
            exportErrorMessage = error.localizedDescription
            showingExportError = true
        }
    }
}

private struct JSONVisualDashboard: View {
    let root: JSONPreviewValue

    @State private var selectedPath = "$"
    @State private var sortMode: JSONVisualSortMode = .name

    private var stats: JSONVisualStats {
        root.stats(depth: 1)
    }

    private var selectedItem: JSONLocatedValue {
        root.locatedValue(matching: selectedPath) ?? JSONLocatedValue(name: "Root", path: "$", value: root)
    }

    var body: some View {
        HStack(spacing: 0) {
            JSONStructureSidebar(
                root: root,
                stats: stats,
                selectedPath: $selectedPath
            )
            .frame(width: 250)

            Divider()

            VStack(spacing: 0) {
                inspectorBar
                Divider()

                ScrollView {
                    JSONSectionView(
                        title: selectedItem.name,
                        path: selectedItem.path,
                        value: selectedItem.value,
                        depth: 0,
                        sortMode: sortMode,
                        selectPath: { selectedPath = $0 }
                    )
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    private var inspectorBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedItem.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(selectedItem.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Picker("Sort", selection: $sortMode) {
                ForEach(JSONVisualSortMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(.bar)
    }
}

private struct JSONStructureSidebar: View {
    let root: JSONPreviewValue
    let stats: JSONVisualStats
    @Binding var selectedPath: String

    private var outlineItems: [JSONOutlineItem] {
        root.outline(path: "$", name: "Root", depth: 0, maxDepth: 3)
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

                ForEach(outlineItems.prefix(24)) { item in
                    Button {
                        selectedPath = item.path
                    } label: {
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

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .padding(.leading, CGFloat(item.depth) * 10)
                    }
                    .buttonStyle(.plain)
                    .background(
                        selectedPath == item.path ? Color.accentColor.opacity(0.16) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .help(item.path)
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
    let sortMode: JSONVisualSortMode
    let selectPath: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    selectPath(path)
                } label: {
                    Text(title)
                        .font(depth == 0 ? .title2.weight(.semibold) : .headline)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Focus \(path)")

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
                JSONObjectSummary(
                    entries: entries,
                    path: path,
                    depth: depth,
                    sortMode: sortMode,
                    selectPath: selectPath
                )
            case .array(let values):
                JSONArraySummary(
                    values: values,
                    path: path,
                    depth: depth,
                    sortMode: sortMode,
                    selectPath: selectPath
                )
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
    let sortMode: JSONVisualSortMode
    let selectPath: (String) -> Void

    private var scalarEntries: [JSONPreviewObjectEntry] {
        entries.filter(\.value.isScalar).sorted(using: sortMode)
    }

    private var nestedEntries: [JSONPreviewObjectEntry] {
        entries.filter { !$0.value.isScalar }.sorted(using: sortMode)
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
                        let childPath = "\(path).\(entry.key)"
                        JSONSectionView(
                            title: entry.key.humanizedJSONKey,
                            path: childPath,
                            value: entry.value,
                            depth: depth + 1,
                            sortMode: sortMode,
                            selectPath: selectPath
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
    let sortMode: JSONVisualSortMode
    let selectPath: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if values.isEmpty {
                Text("Empty array")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let table = JSONRecordTable.make(from: values) {
                JSONRecordTableView(table: table)
            } else if values.allSatisfy(\.isScalar) {
                JSONScalarFlow(values: values, sortMode: sortMode)
            } else {
                ForEach(Array(values.prefix(10).enumerated()), id: \.offset) { index, value in
                    JSONSectionView(
                        title: "Item \(index + 1)",
                        path: "\(path)[\(index)]",
                        value: value,
                        depth: depth + 1,
                        sortMode: sortMode,
                        selectPath: selectPath
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

    @State private var sortedColumn: String?
    @State private var sortAscending = true

    private var visibleRows: [[String: String]] {
        guard let sortedColumn else { return table.rows }

        return table.rows.sorted { lhs, rhs in
            let comparison = JSONSortComparator.compare(lhs[sortedColumn] ?? "", rhs[sortedColumn] ?? "")
            return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Records")
                .font(.callout.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(table.columns, id: \.self) { column in
                            JSONTableHeaderCell(
                                column.humanizedJSONKey,
                                isSorted: sortedColumn == column,
                                ascending: sortAscending
                            ) {
                                toggleSort(column)
                            }
                        }
                    }

                    ForEach(Array(visibleRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(table.columns, id: \.self) { column in
                                JSONTableCell(row[column] ?? "")
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

    private func toggleSort(_ column: String) {
        if sortedColumn == column {
            sortAscending.toggle()
        } else {
            sortedColumn = column
            sortAscending = true
        }
    }
}

private struct JSONTableHeaderCell: View {
    let value: String
    let isSorted: Bool
    let ascending: Bool
    let action: () -> Void

    init(_ value: String, isSorted: Bool, ascending: Bool, action: @escaping () -> Void) {
        self.value = value
        self.isSorted = isSorted
        self.ascending = ascending
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(value.isEmpty ? " " : value)
                    .lineLimit(2)

                if isSorted {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 155, alignment: .leading)
            .frame(minHeight: 30, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.7))
                .frame(height: 0.5)
        }
        .help("Sort by \(value)")
    }
}

private struct JSONTableCell: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value.isEmpty ? " " : value)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .textSelection(.enabled)
            .frame(width: 155, alignment: .leading)
            .frame(minHeight: 30, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.7))
                    .frame(height: 0.5)
            }
    }
}

private struct JSONScalarFlow: View {
    let values: [JSONPreviewValue]
    let sortMode: JSONVisualSortMode

    private var visibleValues: [JSONPreviewValue] {
        switch sortMode {
        case .name:
            return values
        case .type:
            return values.sorted {
                JSONSortComparator.compare($0.typeLabel, $1.typeLabel) == .orderedAscending
            }
        case .value:
            return values.sorted {
                JSONSortComparator.compare($0.displayValue, $1.displayValue) == .orderedAscending
            }
        }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(Array(visibleValues.prefix(48).enumerated()), id: \.offset) { _, value in
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

private enum JSONVisualSortMode: String, CaseIterable, Identifiable {
    case name
    case type
    case value

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .name:
            return "Name"
        case .type:
            return "Type"
        case .value:
            return "Value"
        }
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
    let path: String
    let name: String
    let summary: String
    let iconName: String
    let depth: Int
}

private struct JSONLocatedValue {
    let name: String
    let path: String
    let value: JSONPreviewValue
}

private extension Array where Element == JSONPreviewObjectEntry {
    func sorted(using mode: JSONVisualSortMode) -> [JSONPreviewObjectEntry] {
        sorted { lhs, rhs in
            switch mode {
            case .name:
                return JSONSortComparator.compare(lhs.key.humanizedJSONKey, rhs.key.humanizedJSONKey) == .orderedAscending
            case .type:
                return JSONSortComparator.compare(lhs.value.typeLabel, rhs.value.typeLabel) == .orderedAscending
            case .value:
                return JSONSortComparator.compare(lhs.value.displayValue, rhs.value.displayValue) == .orderedAscending
            }
        }
    }
}

private enum JSONSortComparator {
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if let lhsNumber = Double(lhs), let rhsNumber = Double(rhs) {
            if lhsNumber == rhsNumber { return .orderedSame }
            return lhsNumber < rhsNumber ? .orderedAscending : .orderedDescending
        }

        return lhs.localizedStandardCompare(rhs)
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
                path: path,
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

    func locatedValue(matching targetPath: String, path: String = "$", name: String = "Root") -> JSONLocatedValue? {
        if path == targetPath {
            return JSONLocatedValue(name: name, path: path, value: self)
        }

        switch self {
        case .object(let entries):
            for entry in entries {
                if let match = entry.value.locatedValue(
                    matching: targetPath,
                    path: "\(path).\(entry.key)",
                    name: entry.key.humanizedJSONKey
                ) {
                    return match
                }
            }
        case .array(let values):
            for (index, value) in values.enumerated() {
                if let match = value.locatedValue(
                    matching: targetPath,
                    path: "\(path)[\(index)]",
                    name: "Item \(index + 1)"
                ) {
                    return match
                }
            }
        case .string, .number, .bool, .null:
            break
        }

        return nil
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

enum JSONVisualHTMLExporter {
    @MainActor
    static func export(root: JSONPreviewValue, documentName: String) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export JSON Visual"
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\((documentName as NSString).deletingPathExtension)-visual.html"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try html(root: root, documentName: documentName).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func html(root: JSONPreviewValue, documentName: String) -> String {
        let stats = root.stats(depth: 1)

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>\(JSONVisualHTML.escape(documentName)) visual</title>
        <style>
        :root {
            color-scheme: light dark;
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
            background: Canvas;
            color: CanvasText;
        }
        body {
            margin: 0;
            padding: 34px;
            line-height: 1.45;
        }
        main {
            max-width: 1080px;
            margin: 0 auto;
        }
        header {
            margin-bottom: 26px;
        }
        h1 {
            margin: 0 0 4px;
            font-size: 28px;
        }
        h2 {
            margin: 28px 0 4px;
            font-size: 21px;
        }
        h3 {
            margin: 20px 0 4px;
            font-size: 16px;
        }
        .path, .type {
            color: color-mix(in srgb, CanvasText 55%, transparent);
            font-size: 12px;
            font-family: "SF Mono", Menlo, Consolas, monospace;
        }
        .metrics {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            margin-top: 18px;
        }
        .metric {
            padding: 8px 10px;
            border: 1px solid color-mix(in srgb, CanvasText 14%, transparent);
            border-radius: 8px;
        }
        .metric strong {
            margin-left: 8px;
        }
        .fields {
            width: 100%;
            border-collapse: collapse;
            margin: 12px 0;
        }
        th, td {
            padding: 8px 10px;
            border-bottom: 1px solid color-mix(in srgb, CanvasText 13%, transparent);
            text-align: left;
            vertical-align: top;
        }
        th {
            background: color-mix(in srgb, CanvasText 7%, transparent);
            font-weight: 600;
        }
        .field-name {
            width: 190px;
            font-weight: 600;
        }
        .note {
            color: color-mix(in srgb, CanvasText 58%, transparent);
            font-size: 12px;
        }
        </style>
        </head>
        <body>
        <main>
        <header>
        <h1>\(JSONVisualHTML.escape(documentName))</h1>
        <div class="type">\(root.typeLabel) · \(root.compactSummary)</div>
        <div class="metrics">
        <div class="metric">Objects <strong>\(stats.objects)</strong></div>
        <div class="metric">Arrays <strong>\(stats.arrays)</strong></div>
        <div class="metric">Fields <strong>\(stats.fields)</strong></div>
        <div class="metric">Values <strong>\(stats.values)</strong></div>
        <div class="metric">Depth <strong>\(stats.maxDepth)</strong></div>
        </div>
        </header>
        \(renderSection(title: "Root", path: "$", value: root, depth: 0))
        </main>
        </body>
        </html>
        """
    }

    private static func renderSection(title: String, path: String, value: JSONPreviewValue, depth: Int) -> String {
        let heading = depth == 0 ? "h2" : "h3"
        let content: String

        switch value {
        case .object(let entries):
            content = renderObject(entries: entries.sorted(using: .name), path: path, depth: depth)
        case .array(let values):
            content = renderArray(values: values, path: path, depth: depth)
        case .string, .number, .bool, .null:
            content = """
            <table class="fields"><tbody>
            <tr><td class="field-name">Value</td><td class="type">\(value.typeLabel)</td><td>\(JSONVisualHTML.escape(value.displayValue))</td></tr>
            </tbody></table>
            """
        }

        return """
        <section>
        <\(heading)>\(JSONVisualHTML.escape(title)) <span class="note">\(JSONVisualHTML.escape(value.compactSummary))</span></\(heading)>
        <div class="path">\(JSONVisualHTML.escape(path))</div>
        \(content)
        </section>
        """
    }

    private static func renderObject(entries: [JSONPreviewObjectEntry], path: String, depth: Int) -> String {
        let scalarEntries = entries.filter(\.value.isScalar)
        let nestedEntries = entries.filter { !$0.value.isScalar }
        var html = ""

        if !scalarEntries.isEmpty {
            let rows = scalarEntries.map { entry in
                """
                <tr><td class="field-name">\(JSONVisualHTML.escape(entry.key.humanizedJSONKey))</td><td class="type">\(entry.value.typeLabel)</td><td>\(JSONVisualHTML.escape(entry.value.displayValue))</td></tr>
                """
            }.joined(separator: "\n")
            html += "<table class=\"fields\"><tbody>\(rows)</tbody></table>"
        }

        if !nestedEntries.isEmpty {
            html += nestedEntries.map { entry in
                renderSection(
                    title: entry.key.humanizedJSONKey,
                    path: "\(path).\(entry.key)",
                    value: entry.value,
                    depth: depth + 1
                )
            }.joined(separator: "\n")
        }

        return html.isEmpty ? "<p class=\"note\">Empty object</p>" : html
    }

    private static func renderArray(values: [JSONPreviewValue], path: String, depth: Int) -> String {
        if values.isEmpty {
            return "<p class=\"note\">Empty array</p>"
        }

        if let table = JSONRecordTable.make(from: values) {
            let head = table.columns
                .map { "<th>\(JSONVisualHTML.escape($0.humanizedJSONKey))</th>" }
                .joined()
            let rows = table.rows.map { row in
                let cells = table.columns
                    .map { "<td>\(JSONVisualHTML.escape(row[$0] ?? ""))</td>" }
                    .joined()
                return "<tr>\(cells)</tr>"
            }.joined(separator: "\n")
            return "<table class=\"fields\"><thead><tr>\(head)</tr></thead><tbody>\(rows)</tbody></table>"
        }

        if values.allSatisfy(\.isScalar) {
            let rows = values.prefix(80).enumerated().map { index, value in
                "<tr><td class=\"field-name\">Item \(index + 1)</td><td class=\"type\">\(value.typeLabel)</td><td>\(JSONVisualHTML.escape(value.displayValue))</td></tr>"
            }.joined(separator: "\n")
            return "<table class=\"fields\"><tbody>\(rows)</tbody></table>"
        }

        return values.prefix(12).enumerated().map { index, value in
            renderSection(title: "Item \(index + 1)", path: "\(path)[\(index)]", value: value, depth: depth + 1)
        }.joined(separator: "\n")
    }
}

private enum JSONVisualHTML {
    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
