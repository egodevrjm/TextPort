import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat = TextExportFormat.plainText
    @State private var customExtension = "txt"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Export Text")
                    .font(.title2.weight(.semibold))
                Text("Choose a common text format or enter any extension.")
                    .foregroundStyle(.secondary)
            }

            Picker("Format", selection: $selectedFormat) {
                ForEach(TextExportFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.menu)

            if selectedFormat == .custom {
                TextField("Extension", text: $customExtension)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(export)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Export") {
                    export()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func export() {
        let fileExtension = selectedFormat == .custom
            ? customExtension.normalizedFileExtension
            : selectedFormat.fileExtension

        document.exportDocument(fileExtension: fileExtension)
        if !document.showingError {
            dismiss()
        }
    }
}

enum TextExportFormat: String, CaseIterable, Identifiable {
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
        case .html: "HTML (.html)"
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
