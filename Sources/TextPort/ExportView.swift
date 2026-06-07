import SwiftUI

struct ExportView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Export")
                    .font(.title2.weight(.semibold))
                Text("Create a generated file for reading, sharing, or packaging. The current tab stays connected to its source file.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ExportActionRow(
                    title: "PDF",
                    subtitle: "A readable PDF from the current text.",
                    systemImage: "doc.richtext",
                    action: { run(document.exportPDF) }
                )

                if document.activeDocumentCanExportRenderedMarkdownHTML {
                    Divider()
                    ExportActionRow(
                        title: "Rendered Markdown HTML",
                        subtitle: "A styled HTML page from the Markdown preview.",
                        systemImage: "doc.text.magnifyingglass",
                        action: { run(document.exportRenderedMarkdownHTML) }
                    )
                }

                if document.activeDocumentCanVisualizeJSON {
                    Divider()
                    ExportActionRow(
                        title: "JSON Visual HTML",
                        subtitle: "A sortable, human-readable visual report.",
                        systemImage: "chart.bar.doc.horizontal",
                        action: { run(document.exportJSONVisualHTML) }
                    )
                }

                Divider()
                ExportActionRow(
                    title: "Open Tabs Zip Bundle",
                    subtitle: "A zip archive containing all open tabs.",
                    systemImage: "archivebox",
                    action: { run(document.exportOpenTabsBundle) }
                )
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func run(_ action: () -> Void) {
        action()
        if !document.showingError {
            dismiss()
        }
    }
}

private struct ExportActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

struct SaveCopyView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat = TextSaveCopyFormat.plainText
    @State private var customExtension = "txt"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Save Copy As")
                    .font(.title2.weight(.semibold))
                Text("Save an editable text or code copy without changing where this tab saves.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Format", selection: $selectedFormat) {
                ForEach(TextSaveCopyFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.menu)

            if selectedFormat == .custom {
                TextField("Extension", text: $customExtension)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveCopy)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save Copy") {
                    saveCopy()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func saveCopy() {
        let fileExtension = selectedFormat == .custom
            ? customExtension.normalizedFileExtension
            : selectedFormat.fileExtension

        document.saveCopyAs(fileExtension: fileExtension)
        if !document.showingError {
            dismiss()
        }
    }
}

enum TextSaveCopyFormat: String, CaseIterable, Identifiable {
    case plainText
    case markdown
    case html
    case css
    case javascript
    case json
    case xml
    case csv
    case yaml
    case toml
    case ini
    case env
    case shell
    case swift
    case python
    case sql
    case tex
    case reStructuredText
    case log
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plainText: "Plain Text (.txt)"
        case .markdown: "Markdown (.md)"
        case .html: "HTML Source (.html)"
        case .css: "CSS (.css)"
        case .javascript: "JavaScript (.js)"
        case .json: "JSON (.json)"
        case .xml: "XML (.xml)"
        case .csv: "CSV (.csv)"
        case .yaml: "YAML (.yaml)"
        case .toml: "TOML (.toml)"
        case .ini: "INI (.ini)"
        case .env: "Environment (.env)"
        case .shell: "Shell Script (.sh)"
        case .swift: "Swift (.swift)"
        case .python: "Python (.py)"
        case .sql: "SQL (.sql)"
        case .tex: "TeX (.tex)"
        case .reStructuredText: "reStructuredText (.rst)"
        case .log: "Log (.log)"
        case .custom: "Custom Extension"
        }
    }

    var fileExtension: String {
        switch self {
        case .plainText: "txt"
        case .markdown: "md"
        case .html: "html"
        case .css: "css"
        case .javascript: "js"
        case .json: "json"
        case .xml: "xml"
        case .csv: "csv"
        case .yaml: "yaml"
        case .toml: "toml"
        case .ini: "ini"
        case .env: "env"
        case .shell: "sh"
        case .swift: "swift"
        case .python: "py"
        case .sql: "sql"
        case .tex: "tex"
        case .reStructuredText: "rst"
        case .log: "log"
        case .custom: "txt"
        }
    }
}
