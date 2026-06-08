import SwiftUI

enum HelpGuideSection: String, CaseIterable, Identifiable, Hashable {
    case about
    case basics
    case saveExport
    case imports
    case projects
    case commandPalette
    case run

    var id: String { rawValue }

    var title: String {
        switch self {
        case .about: "About"
        case .basics: "Basics"
        case .saveExport: "Save & Export"
        case .imports: "Imports"
        case .projects: "Projects"
        case .commandPalette: "Command Palette"
        case .run: "Run"
        }
    }

    var systemImage: String {
        switch self {
        case .about: "app.badge"
        case .basics: "doc.text"
        case .saveExport: "square.and.arrow.down"
        case .imports: "tray.and.arrow.down"
        case .projects: "folder"
        case .commandPalette: "command"
        case .run: "play.fill"
        }
    }
}

struct HelpGuideView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @Environment(\.dismiss) private var dismiss

    private var selection: Binding<HelpGuideSection?> {
        Binding {
            document.helpGuideSection
        } set: { newValue in
            if let newValue {
                document.helpGuideSection = newValue
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            NavigationSplitView {
                List(selection: selection) {
                    ForEach(HelpGuideSection.allCases) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            } detail: {
                ScrollView {
                    HelpGuideDetail(section: document.helpGuideSection)
                        .frame(maxWidth: 760, alignment: .leading)
                        .padding(28)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .frame(minWidth: 820, idealWidth: 920, minHeight: 560, idealHeight: 640)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.document")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("TextPort Guide")
                    .font(.headline)

                Text("Plain text first, project tools when you need them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

private struct HelpGuideDetail: View {
    let section: HelpGuideSection

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label(section.title, systemImage: section.systemImage)
                .font(.title2.weight(.semibold))

            switch section {
            case .about:
                helpSection(
                    "TextPort",
                    items: [
                        "A native macOS editor for plain text, code, notes, data files, and imported document text.",
                        "The default setup stays simple: one editable tab, no project sidebar unless a project is opened.",
                        "IDE features sit nearby for folders, searches, tasks, previews, and runnable code files."
                    ]
                )

                helpSection(
                    "Current Build",
                    items: [
                        appVersionText,
                        "Source files save as editable text. Exports create generated files.",
                        "Release builds should be packaged, signed, checked with --verify, and published with matching release notes."
                    ]
                )

                helpSection(
                    "Trust Model",
                    items: [
                        "TextPort works locally and does not require an account.",
                        "Sharing, GitHub, publishing, project tasks, and runnable code stay optional.",
                        "Project tasks and runnable files execute local shell commands, so use them with projects you trust."
                    ]
                )

            case .basics:
                helpSection(
                    "Editing",
                    items: [
                        "Open or drag in files to edit them as text.",
                        "Tabs keep multiple files available without changing the main editor layout.",
                        "Use the Tabs menu to reopen the last closed tab, close other tabs, or close tabs to the right.",
                        "Click the title-bar name to rename a saved file or set the suggested name for an unsaved tab.",
                        "Use automatic syntax highlighting by default, or choose a syntax mode from the Text menu.",
                        "The status bar shows cursor line and column, plus selected text counts when text is selected."
                    ]
                )

                helpSection(
                    "Preview",
                    items: [
                        "HTML, Markdown, JSON, CSV, TSV, and SVG files can switch between source and rendered preview.",
                        "Markdown preview supports headings, tables, task lists, code blocks, links, images, quotes, and inline formatting.",
                        "The smart toolbar shows preview, JSON visualization, and run actions only when they apply."
                    ]
                )

                helpSection(
                    "File Info",
                    items: [
                        "Open File Info from the Tools menu or Command Palette.",
                        "File Info shows save state, path, disk size, modified date, encoding, line endings, and syntax mode."
                    ]
                )

            case .saveExport:
                helpSection(
                    "Save",
                    items: [
                        "Save and Save As keep the editable source connected to the tab.",
                        "Save Copy As creates a text or code copy without changing the tab's saved file.",
                        "Encoding and line endings stay part of the source-saving flow."
                    ]
                )

                helpSection(
                    "Export",
                    items: [
                        "Export creates generated outputs for reading, sharing, or packaging.",
                        "Supported generated exports include PDF, rendered Markdown HTML, visual JSON HTML, and open-tab zip bundles."
                    ]
                )

                helpSection(
                    "Sharing",
                    items: [
                        "Sharing tools are off by default and can be enabled in Settings.",
                        "When enabled, TextPort can share the current tab, selected text, rendered output, open tabs, or a project source bundle.",
                        "GitHub tools can open or copy repository and file links for projects with GitHub remotes."
                    ]
                )

            case .imports:
                helpSection(
                    "Documents",
                    items: [
                        "PDF and Word files open as cleaned body text in unsaved text tabs.",
                        "PowerPoint opens as extracted slide text.",
                        "Excel workbooks open as one or more unsaved CSV tabs.",
                        "Original imported files are not modified."
                    ]
                )

                helpSection(
                    "Projects",
                    items: [
                        "Zip archives can be opened as projects after TextPort extracts them into its app-support folder.",
                        "Imported document text is editable and can be saved into any normal text or code format."
                    ]
                )

            case .projects:
                helpSection(
                    "Project Mode",
                    items: [
                        "Open a folder or zip archive to work with a project.",
                        "The sidebar can stay hidden by default, then be shown when you want the file tree.",
                        "Project search scans text-like files while skipping common build folders and caches."
                    ]
                )

                helpSection(
                    "Tasks",
                    items: [
                        "Project tasks are named shell commands saved outside the project folder.",
                        "Task output appears in the bottom panel and can be stopped while running."
                    ]
                )

            case .commandPalette:
                helpSection(
                    "Command Palette",
                    items: [
                        "Search common file, project, view, text, export, and run actions from one place.",
                        "Palette actions now wait for the palette sheet to close before opening another sheet or panel.",
                        "Disabled actions stay visible when context matters, such as JSON tools without a JSON tab."
                    ]
                )

            case .run:
                helpSection(
                    "Running Files",
                    items: [
                        "Saved Swift, Python, JavaScript, shell, Ruby, and Go files can run from the smart toolbar or Command Palette.",
                        "Edited files save first, then run from their file location.",
                        "Output streams into the bottom panel, with a Stop action while the command is running.",
                        "File runs execute local commands. Only run files you trust."
                    ]
                )

                helpSection(
                    "Running Tasks",
                    items: [
                        "Open a project to manage named tasks such as build, test, lint, or a custom script.",
                        "Only one file run or project task runs at a time in this version."
                    ]
                )
            }
        }
        .textSelection(.enabled)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case (.some(let version), .some(let build)):
            return "Version \(version) (\(build))"
        case (.some(let version), .none):
            return "Version \(version)"
        default:
            return "Local development build"
        }
    }

    private func helpSection(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)

                        Text(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.body)
                }
            }
        }
    }
}
