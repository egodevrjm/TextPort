import SwiftUI

struct FileTemplateChooserView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New From Template")
                .font(.headline)

            List(FileTemplate.all) { template in
                Button {
                    document.newDocument(text: template.text, displayName: template.fileName, syntaxMode: template.syntaxMode)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: iconName(for: template.syntaxMode))
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                            Text(template.fileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(width: 380, height: 420)
    }

    private func iconName(for mode: SyntaxHighlightMode) -> String {
        switch mode {
        case .markdown, .plainText:
            return "doc.text"
        case .json, .html, .swift, .python, .shell:
            return "curlybraces"
        default:
            return "doc"
        }
    }
}

struct DocumentOutlineView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @Environment(\.dismiss) private var dismiss

    private var symbols: [DocumentSymbol] {
        DocumentSymbolExtractor.symbols(
            in: document.activeTab,
            mode: document.effectiveSyntaxMode(for: document.selectedTabID)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Document Outline")
                    .font(.headline)
                Spacer()
                Text(document.fileDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if symbols.isEmpty {
                ContentUnavailableView("No Symbols", systemImage: "list.bullet.rectangle", description: Text("TextPort did not find headings, keys, tags, or code symbols in this document."))
            } else {
                List(symbols) { symbol in
                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(symbol.title)
                                    .lineLimit(1)
                                Text("\(symbol.detail) · line \(symbol.lineNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, CGFloat(max(0, symbol.level - 1)) * 12)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(width: 460, height: 520)
    }
}

struct GoToLineView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var lineNumberText = ""

    private var lineNumber: Int? {
        let value = lineNumberText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Int(value), number > 0 else { return nil }
        return number
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Go to Line")
                .font(.headline)

            TextField("Line number", text: $lineNumberText)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .onSubmit(go)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Go", action: go)
                    .keyboardShortcut(.defaultAction)
                    .disabled(lineNumber == nil)
            }
        }
        .padding(18)
        .frame(width: 300)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private func go() {
        guard let lineNumber else { return }
        document.goToLine(lineNumber)
        dismiss()
    }
}

struct TabCompareView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @State private var leftID: UUID?
    @State private var rightID: UUID?

    private var leftTab: TextDocumentTab? {
        document.tabs.first { $0.id == (leftID ?? document.tabs.first?.id) }
    }

    private var rightTab: TextDocumentTab? {
        let fallback = document.tabs.dropFirst().first?.id ?? document.tabs.first?.id
        return document.tabs.first { $0.id == (rightID ?? fallback) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Left", selection: Binding(get: { leftID ?? document.tabs.first?.id }, set: { leftID = $0 })) {
                    ForEach(document.tabs) { tab in
                        Text(tab.fileDisplayName).tag(Optional(tab.id))
                    }
                }

                Picker("Right", selection: Binding(get: { rightID ?? document.tabs.dropFirst().first?.id ?? document.tabs.first?.id }, set: { rightID = $0 })) {
                    ForEach(document.tabs) { tab in
                        Text(tab.fileDisplayName).tag(Optional(tab.id))
                    }
                }
            }

            if let leftTab, let rightTab {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(TabDiff.make(left: leftTab.text, right: rightTab.text)) { row in
                            HStack(alignment: .top, spacing: 10) {
                                Text(row.lineLabel)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 58, alignment: .trailing)
                                Text(row.text)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(row.color.opacity(0.12))
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(18)
        .frame(width: 760, height: 560)
    }
}

struct CommandPaletteView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @EnvironmentObject private var project: ProjectStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var commands: [CommandPaletteItem] {
        var items = [
            CommandPaletteItem("Open File", "File") { document.openDocument() },
            CommandPaletteItem("Open Project or Zip", "Project") { project.openProjectPanel(); document.openFiles(at: project.consumeRestoredOpenTabURLs()) },
            CommandPaletteItem("Open Quickly", "File") { document.showQuickOpen() },
            CommandPaletteItem("New From Template", "File") { document.showTemplateChooser() },
            CommandPaletteItem("Open Scratchpad", "File") { document.openScratchpad() },
            CommandPaletteItem("Reveal in Finder", "File", isEnabled: document.activeTabHasSavedFile) { document.revealActiveFileInFinder() },
            CommandPaletteItem("TextPort Guide", "Help") { document.showHelpGuide(section: .about) },
            CommandPaletteItem("Compare Tabs", "Tools") { document.showTabCompare() },
            CommandPaletteItem("Document Outline", "Tools") { document.showDocumentOutline() },
            CommandPaletteItem("File Info", "Tools") { document.showFileInfo() },
            CommandPaletteItem("Format Document", "Text") { document.formatDocument() },
            CommandPaletteItem("Minify Document", "Text") { document.minifyDocument() },
            CommandPaletteItem("Go to Line", "Text") { document.showGoToLine() },
            CommandPaletteItem("Select Line", "Text") { document.selectLine() },
            CommandPaletteItem("Duplicate Line", "Text") { document.duplicateLine() },
            CommandPaletteItem("Move Line Up", "Text") { document.moveLineUp() },
            CommandPaletteItem("Move Line Down", "Text") { document.moveLineDown() },
            CommandPaletteItem("Delete Line", "Text") { document.deleteLine() },
            CommandPaletteItem("Join Lines", "Text") { document.joinLines() },
            CommandPaletteItem("Toggle Line Comment", "Text", isEnabled: document.activeDocumentCanToggleLineComment) { document.toggleLineComment() },
            CommandPaletteItem("Document Stats", "Tools") { document.showDocumentStats() },
            CommandPaletteItem("Reopen Closed Tab", "Tabs", isEnabled: document.canReopenClosedTab) { document.reopenClosedTab() },
            CommandPaletteItem("Close Other Tabs", "Tabs", isEnabled: document.tabs.count > 1) { document.closeOtherTabs() },
            CommandPaletteItem("Close Tabs to the Right", "Tabs", isEnabled: document.canCloseTabsToRight) { document.closeTabsToRight() },
            CommandPaletteItem("Visualize JSON", "Tools", isEnabled: document.activeDocumentCanVisualizeJSON) { document.showJSONVisualizer() },
            CommandPaletteItem("Custom Syntaxes", "Text") { document.showCustomSyntaxManager() },
            CommandPaletteItem("Save Copy As", "File") { document.showingSaveCopySheet = true },
            CommandPaletteItem("Export", "File") { document.showingExportSheet = true },
            CommandPaletteItem(project.isSidebarVisible ? "Hide Project Sidebar" : "Show Project Sidebar", "View") { project.toggleSidebar() },
            CommandPaletteItem(preferences.renderPreview ? "Show Source" : "Render Preview", "View") { preferences.renderPreview.toggle() },
            CommandPaletteItem("Run Current File", "Run", isEnabled: document.activeFileRunCommand != nil && !project.taskRunState.isRunning) {
                document.runActiveFile(using: project)
            },
            CommandPaletteItem("Show Output Panel", "Project", isEnabled: project.hasProject) { project.showTaskOutput() },
            CommandPaletteItem("Run Selected Task", "Project", isEnabled: project.hasProject && !project.taskRunState.isRunning) { project.runSelectedTask() },
            CommandPaletteItem("Stop Task", "Project", isEnabled: project.taskRunState.isRunning) { project.stopTask() }
        ]

        if preferences.enableSharingTools {
            items.append(contentsOf: [
                CommandPaletteItem("Share Current Tab", "Share") { document.shareCurrentTab() },
                CommandPaletteItem("Share Selected Text", "Share") { document.shareSelectedText() },
                CommandPaletteItem("Share Rendered Output", "Share") { document.shareRenderedOutput() },
                CommandPaletteItem("Share Open Tabs Bundle", "Share") { document.shareOpenTabsBundle() },
                CommandPaletteItem("Share Project Bundle", "Share", isEnabled: project.hasProject) { project.shareProjectBundle() }
            ])
        }

        if preferences.enableSharingTools && preferences.enableGitHubTools {
            items.append(contentsOf: [
                CommandPaletteItem("Open Repository on GitHub", "GitHub", isEnabled: project.hasProject) { project.openGitHubRepository() },
                CommandPaletteItem("Copy GitHub Repository Link", "GitHub", isEnabled: project.hasProject) { project.copyGitHubRepositoryURL() },
                CommandPaletteItem("Copy GitHub File Link", "GitHub", isEnabled: project.hasProject && document.activeTab.fileURL != nil) {
                    project.copyGitHubLink(for: document.activeTab.fileURL)
                },
                CommandPaletteItem("Copy Markdown GitHub File Link", "GitHub", isEnabled: project.hasProject && document.activeTab.fileURL != nil) {
                    project.copyGitHubLink(for: document.activeTab.fileURL, markdown: true)
                }
            ])
        }

        if preferences.enableSharingTools && preferences.enableGitHubTools && preferences.enablePublishingActions {
            items.append(CommandPaletteItem("Publish Current Tab as Secret Gist", "GitHub") {
                document.publishCurrentTabAsSecretGist()
            })
        }

        return items
    }

    private var filteredCommands: [CommandPaletteItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return commands }
        return commands.filter {
            $0.title.lowercased().contains(trimmed) || $0.category.lowercased().contains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search commands", text: $query)
                .textFieldStyle(.roundedBorder)

            List(filteredCommands) { command in
                Button {
                    guard command.isEnabled else { return }
                    perform(command)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.title)
                            Text(command.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!command.isEnabled)
            }
        }
        .padding(16)
        .frame(width: 520, height: 480)
    }

    private func perform(_ command: CommandPaletteItem) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            command.action()
        }
    }
}

private struct CommandPaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let isEnabled: Bool
    let action: () -> Void

    init(_ title: String, _ category: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.category = category
        self.isEnabled = isEnabled
        self.action = action
    }
}

private struct TabDiffRow: Identifiable {
    let id = UUID()
    let lineLabel: String
    let text: String
    let color: Color
}

private enum TabDiff {
    static func make(left: String, right: String) -> [TabDiffRow] {
        let leftLines = left.components(separatedBy: "\n")
        let rightLines = right.components(separatedBy: "\n")
        let count = max(leftLines.count, rightLines.count)

        return (0..<count).flatMap { index -> [TabDiffRow] in
            let leftLine = index < leftLines.count ? leftLines[index] : nil
            let rightLine = index < rightLines.count ? rightLines[index] : nil

            if leftLine == rightLine {
                return [TabDiffRow(lineLabel: "\(index + 1)", text: leftLine ?? "", color: .clear)]
            }

            var rows: [TabDiffRow] = []
            if let leftLine {
                rows.append(TabDiffRow(lineLabel: "-\(index + 1)", text: leftLine, color: .red))
            }
            if let rightLine {
                rows.append(TabDiffRow(lineLabel: "+\(index + 1)", text: rightLine, color: .green))
            }
            return rows
        }
    }
}
