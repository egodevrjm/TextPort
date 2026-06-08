import AppKit
import Combine
import Foundation
import PDFKit
import UniformTypeIdentifiers

@MainActor
final class TextDocumentStore: ObservableObject {
    @Published var tabs: [TextDocumentTab]
    @Published var selectedTabID: UUID
    @Published var statusText = "Ready"
    @Published var showingExportSheet = false
    @Published var showingSaveCopySheet = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var titleEditRequestID = UUID()
    @Published var showingQuickOpenSheet = false
    @Published var quickOpenQuery = ""
    @Published var recentFiles: [URL]
    @Published var externalChangePrompt: ExternalFileChange?
    @Published var splitViewEnabled = false
    @Published var secondaryTabID: UUID?
    @Published var showingDocumentStats = false
    @Published var showingFileInfo = false
    @Published var showingJSONVisualizer = false
    @Published var showingCommandPalette = false
    @Published var showingTabCompare = false
    @Published var showingDocumentOutline = false
    @Published var showingTemplateChooser = false
    @Published var showingHelpGuide = false
    @Published var showingCustomSyntaxManager = false
    @Published var fileImportProgress: FileImportProgress?
    @Published var sessionRecoveryNotice: SessionRecoveryNotice?
    @Published var helpGuideSection: HelpGuideSection = .about

    private let preferences = AppPreferences.shared
    private var sessionSaveTask: Task<Void, Never>?
    private var fileChangeTimer: Timer?
    private var selectedTextByTabID: [UUID: String] = [:]
    private var selectionRangeByTabID: [UUID: NSRange] = [:]
    private var queuedProcessedFileURLs: [URL] = []
    private var recentlyClosedTabs: [TextDocumentTab] = []

    init() {
        recentFiles = RecentFileStore.load()

        if preferences.restoreSession, let restoredSession = TextSessionStore.load(), !restoredSession.tabs.isEmpty {
            tabs = restoredSession.tabs
            selectedTabID = restoredSession.tabs.contains(where: { $0.id == restoredSession.selectedTabID })
                ? restoredSession.selectedTabID
                : restoredSession.tabs[0].id
            statusText = "Restored previous session"
            sessionRecoveryNotice = SessionRecoveryNotice(tabCount: restoredSession.tabs.count)
        } else {
            let firstTab = TextDocumentTab(
                textEncoding: preferences.defaultEncoding,
                preferredLineEnding: preferences.defaultLineEnding
            )
            tabs = [firstTab]
            selectedTabID = firstTab.id
            sessionRecoveryNotice = nil
        }

        startFileChangeMonitoring()
    }

    var activeTab: TextDocumentTab {
        tabs[activeTabIndex]
    }

    var activeText: String {
        activeTab.text
    }

    var secondaryTab: TextDocumentTab? {
        guard let secondaryTabID else { return nil }
        return tabs.first { $0.id == secondaryTabID }
    }

    var windowTitle: String {
        "\(activeTab.isEdited ? "*" : "")\(activeTab.fileDisplayName)"
    }

    var fileDisplayName: String {
        activeTab.fileDisplayName
    }

    var editableFileName: String {
        activeTab.displayName
    }

    var detailText: String {
        "\(activeTab.textEncoding.label) - \(activeTab.preferredLineEnding.label) - \(activeSyntaxLabel)"
    }

    var activeSyntaxLabel: String {
        if let definition = effectiveCustomSyntaxDefinition(for: selectedTabID) {
            return definition.displayName
        }

        return effectiveSyntaxMode(for: selectedTabID).label
    }

    var lineCountText: String {
        let count = TextMetrics.lineCount(in: activeTab.text)
        return count == 1 ? "1 line" : "\(count) lines"
    }

    var characterCountText: String {
        "\(activeTab.text.count) characters"
    }

    var cursorPositionText: String {
        let position = cursorPosition(for: selectedTabID)
        return "Ln \(position.line), Col \(position.column)"
    }

    var selectionSummaryText: String? {
        let selectedText = selectedTextByTabID[selectedTabID] ?? ""
        guard !selectedText.isEmpty else { return nil }

        let lines = TextMetrics.lineCount(in: selectedText)
        let words = TextMetrics.wordCount(in: selectedText)
        let characters = selectedText.count
        let lineLabel = lines == 1 ? "1 line" : "\(lines) lines"
        let wordLabel = words == 1 ? "1 word" : "\(words) words"
        let characterLabel = characters == 1 ? "1 character" : "\(characters) characters"
        return "Selected \(lineLabel), \(wordLabel), \(characterLabel)"
    }

    var activeDocumentStats: DocumentStats {
        stats(for: selectedTabID)
    }

    var activeFileInfo: DocumentFileInfo {
        DocumentFileInfo(tab: activeTab, syntaxLabel: activeSyntaxLabel)
    }

    var activeDocumentCanVisualizeJSON: Bool {
        effectiveSyntaxMode(for: selectedTabID) == .json
    }

    var activeDocumentCanExportRenderedMarkdownHTML: Bool {
        effectiveSyntaxMode(for: selectedTabID) == .markdown
    }

    var activeFileRunCommand: RunFileCommand? {
        guard let fileURL = activeTab.fileURL else { return nil }
        return RunFileCommand.make(for: fileURL)
    }

    var canReopenClosedTab: Bool {
        !recentlyClosedTabs.isEmpty
    }

    var canCloseTabsToRight: Bool {
        activeTabIndex < tabs.count - 1
    }

    var filteredQuickOpenItems: [QuickOpenItem] {
        let query = quickOpenQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let openItems = tabs.map { tab in
            QuickOpenItem(
                title: tab.fileDisplayName,
                subtitle: tab.fileURL?.deletingLastPathComponent().path ?? "Open tab",
                kind: .openTab(tab.id)
            )
        }

        let openURLs = Set(tabs.compactMap(\.fileURL))
        let recentItems = recentFiles
            .filter { !openURLs.contains($0) }
            .map { url in
                QuickOpenItem(
                    title: url.lastPathComponent,
                    subtitle: url.deletingLastPathComponent().path,
                    kind: .recentFile(url)
                )
            }

        let items = openItems + recentItems

        guard !query.isEmpty else {
            return Array(items.prefix(30))
        }

        return items.filter { item in
            item.title.lowercased().contains(query) || item.subtitle.lowercased().contains(query)
        }
    }

    func updateActiveText(_ newText: String) {
        updateText(for: selectedTabID, newText)
    }

    func text(for id: UUID) -> String {
        tabs.first(where: { $0.id == id })?.text ?? ""
    }

    func updateText(for id: UUID, _ newText: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }), tabs[index].text != newText else { return }

        mutateTab(id) { tab in
            tab.text = newText
            tab.isEdited = true
            tab.preferredLineEnding = TextLineEnding.detect(in: newText, fallback: tab.preferredLineEnding)
        }
        statusText = "Edited"
    }

    func updateSelection(for id: UUID, selectedText: String, range: NSRange) {
        objectWillChange.send()
        selectedTextByTabID[id] = selectedText
        selectionRangeByTabID[id] = range
    }

    func effectiveSyntaxMode(for id: UUID) -> SyntaxHighlightMode {
        guard let tab = tabs.first(where: { $0.id == id }) else { return .plainText }

        if tab.syntaxMode != .automatic {
            return tab.syntaxMode
        }

        return SyntaxHighlightMode.detect(fileName: tab.fileDisplayName, text: tab.text)
    }

    func effectiveCustomSyntaxDefinition(for id: UUID) -> CustomSyntaxDefinition? {
        guard let tab = tabs.first(where: { $0.id == id }) else { return nil }

        if let pinnedDefinition = preferences.customSyntaxDefinition(id: tab.customSyntaxID) {
            return pinnedDefinition
        }

        guard tab.syntaxMode == .automatic,
              SyntaxHighlightMode.detect(fileName: tab.fileDisplayName, text: tab.text) == .plainText
        else {
            return nil
        }

        return preferences.matchingCustomSyntax(fileName: tab.fileDisplayName, text: tab.text)
    }

    func updateActiveDisplayName(_ displayName: String) {
        mutateActiveTab { tab in
            tab.displayName = displayName
        }
    }

    @discardableResult
    func commitActiveFileNameChange() -> Bool {
        commitFileNameChange(for: selectedTabID)
    }

    func selectTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
        scheduleSessionSave()
    }

    func selectNextTab() {
        guard tabs.count > 1 else { return }
        let nextIndex = (activeTabIndex + 1) % tabs.count
        selectedTabID = tabs[nextIndex].id
        scheduleSessionSave()
    }

    func selectPreviousTab() {
        guard tabs.count > 1 else { return }
        let previousIndex = (activeTabIndex - 1 + tabs.count) % tabs.count
        selectedTabID = tabs[previousIndex].id
        scheduleSessionSave()
    }

    func beginRenamingActiveTab() {
        titleEditRequestID = UUID()
    }

    func setActiveSyntaxMode(_ mode: SyntaxHighlightMode) {
        mutateActiveTab { tab in
            tab.syntaxMode = mode
            tab.customSyntaxID = nil
        }
        statusText = "Syntax mode set to \(mode.label)"
    }

    func setActiveCustomSyntaxDefinition(_ definitionID: UUID) {
        guard let definition = preferences.customSyntaxDefinition(id: definitionID) else { return }
        mutateActiveTab { tab in
            tab.syntaxMode = .automatic
            tab.customSyntaxID = definition.id
        }
        statusText = "Syntax mode set to \(definition.displayName)"
    }

    func showCustomSyntaxManager() {
        showingCustomSyntaxManager = true
    }

    func showJSONVisualizer() {
        showingJSONVisualizer = true
        statusText = "Visualizing JSON"
    }

    func toggleSplitView() {
        if splitViewEnabled {
            splitViewEnabled = false
            secondaryTabID = nil
            statusText = "Closed split view"
            return
        }

        if tabs.count == 1 {
            let tab = makeBlankTab()
            tabs.append(tab)
            secondaryTabID = tab.id
        } else {
            secondaryTabID = tabs.first(where: { $0.id != selectedTabID })?.id
        }

        splitViewEnabled = secondaryTabID != nil
        statusText = splitViewEnabled ? "Opened split view" : "Split view unavailable"
        scheduleSessionSave()
    }

    func setSecondaryTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        secondaryTabID = id
        splitViewEnabled = true
        scheduleSessionSave()
    }

    func newDocument() {
        let tab = makeBlankTab()
        tabs.append(tab)
        selectedTabID = tab.id
        statusText = "New document"
        scheduleSessionSave()
    }

    func newDocument(text: String, displayName: String, syntaxMode: SyntaxHighlightMode = .automatic) {
        let tab = TextDocumentTab(
            text: text,
            displayName: displayName,
            isEdited: !text.isEmpty,
            textEncoding: preferences.defaultEncoding,
            preferredLineEnding: preferences.defaultLineEnding,
            syntaxMode: syntaxMode
        )
        tabs.append(tab)
        selectedTabID = tab.id
        statusText = "New \(displayName)"
        scheduleSessionSave()
    }

    func closeActiveTab() {
        closeTab(selectedTabID)
    }

    func closeOtherTabs() {
        let keepingTabID = selectedTabID
        let idsToClose = tabs
            .filter { $0.id != keepingTabID }
            .map(\.id)
        closeTabs(idsToClose)

        if tabs.contains(where: { $0.id == keepingTabID }) {
            selectedTabID = keepingTabID
        }
    }

    func closeTabsToRight() {
        let selectedIndex = activeTabIndex
        guard selectedIndex + 1 < tabs.count else { return }
        let idsToClose = tabs[(selectedIndex + 1)...].map(\.id)
        closeTabs(idsToClose)
    }

    func reopenClosedTab() {
        guard let tab = recentlyClosedTabs.popLast() else { return }
        tabs.append(tab)
        selectedTabID = tab.id
        statusText = "Reopened \(tab.fileDisplayName)"
        scheduleSessionSave()
    }

    func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        guard confirmCloseTab(at: index) else { return }

        let closedTab = tabs[index]
        let closingSelectedTab = selectedTabID == id
        let closingSecondaryTab = secondaryTabID == id
        tabs.remove(at: index)
        rememberClosedTab(closedTab)

        if tabs.isEmpty {
            let replacementTab = makeBlankTab()
            tabs = [replacementTab]
            selectedTabID = replacementTab.id
            statusText = "New document"
            scheduleSessionSave()
            return
        }

        if closingSelectedTab {
            let nextIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[nextIndex].id
        }

        if closingSecondaryTab {
            secondaryTabID = tabs.first(where: { $0.id != selectedTabID })?.id
            splitViewEnabled = secondaryTabID != nil
        }

        statusText = "Closed tab"
        scheduleSessionSave()
    }

    private func closeTabs(_ ids: [UUID]) {
        for id in ids {
            guard tabs.contains(where: { $0.id == id }) else { continue }
            closeTab(id)
        }
    }

    private func rememberClosedTab(_ tab: TextDocumentTab) {
        recentlyClosedTabs.append(tab)
        recentlyClosedTabs = Array(recentlyClosedTabs.suffix(10))
        selectedTextByTabID.removeValue(forKey: tab.id)
        selectionRangeByTabID.removeValue(forKey: tab.id)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.item]
        panel.allowsOtherFileTypes = true

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            openFile(at: url)
        }
    }

    func openFile(at url: URL) {
        loadFile(at: url)
    }

    func openFiles(at urls: [URL]) {
        for url in urls {
            loadFile(at: url)
        }
    }

    func showQuickOpen() {
        quickOpenQuery = ""
        showingQuickOpenSheet = true
    }

    func showCommandPalette() {
        showingCommandPalette = true
        statusText = "Command palette"
    }

    func showHelpGuide(section: HelpGuideSection = .about) {
        helpGuideSection = section
        showingHelpGuide = true
        statusText = "TextPort help"
    }

    func dismissSessionRecoveryNotice() {
        sessionRecoveryNotice = nil
    }

    func openQuickOpenItem(_ item: QuickOpenItem) {
        switch item.kind {
        case .openTab(let id):
            selectTab(id)
            statusText = "Selected \(activeTab.fileDisplayName)"
        case .recentFile(let url):
            openFile(at: url)
        case .projectFile(let url):
            openFile(at: url)
        }

        showingQuickOpenSheet = false
    }

    func clearRecentFiles() {
        recentFiles = []
        RecentFileStore.save([])
    }

    func openDroppedFile(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { provider in
            provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            let url = Self.fileURL(from: item)
            let errorDescription = error?.localizedDescription

            Task { @MainActor in
                if let url {
                    self.openFile(at: url)
                } else if let errorDescription {
                    self.present(message: "TextPort could not open this file. \(errorDescription)")
                } else {
                    self.present(message: "TextPort could not read the dropped file.")
                }
            }
        }

        return true
    }

    func saveDocument() {
        guard commitActiveFileNameChange() else { return }

        if let fileURL = activeTab.fileURL {
            write(to: fileURL, for: selectedTabID, action: "save", updatesDocumentURL: false)
        } else {
            saveDocumentAs()
        }
    }

    func setActiveEncoding(_ encoding: TextEncoding) {
        mutateActiveTab { tab in
            tab.textEncoding = encoding
            tab.isEdited = true
        }
        statusText = "Encoding set to \(encoding.label)"
    }

    func setActiveLineEnding(_ lineEnding: TextLineEnding) {
        mutateActiveTab { tab in
            tab.text = lineEnding.normalized(tab.text)
            tab.preferredLineEnding = lineEnding
            tab.isEdited = true
        }
        statusText = "Line endings set to \(lineEnding.label)"
    }

    func persistSessionImmediately() {
        sessionSaveTask?.cancel()
        TextSessionStore.save(tabs: tabs, selectedTabID: selectedTabID)
    }

    func reloadExternalChange(_ change: ExternalFileChange) {
        guard let index = tabs.firstIndex(where: { $0.id == change.tabID }), let url = tabs[index].fileURL else { return }

        do {
            let loadedFile = try TextFileLoader.load(url: url)
            let modificationDate = fileModificationDate(for: url)
            mutateTab(change.tabID) { tab in
                tab.text = loadedFile.text
                tab.textEncoding = loadedFile.textEncoding
                tab.preferredLineEnding = loadedFile.lineEnding
                tab.isEdited = false
                tab.lastKnownModificationDate = modificationDate
                tab.lastExternalChangePromptDate = nil
            }
            statusText = "Reloaded \(url.lastPathComponent)"
        } catch {
            present(error, action: "reload")
        }
    }

    func keepCurrentVersion(_ change: ExternalFileChange) {
        mutateTab(change.tabID) { tab in
            tab.isEdited = true
            tab.lastKnownModificationDate = change.modificationDate
            tab.lastExternalChangePromptDate = nil
        }
        statusText = "Kept current version"
    }

    func trimTrailingWhitespace() {
        applyTextTransform("Trimmed trailing whitespace") { tab in
            TextTransforms.trimTrailingWhitespace(tab.text, lineEnding: tab.preferredLineEnding)
        }
    }

    func sortLines() {
        applyTextTransform("Sorted lines") { tab in
            TextTransforms.sortLines(tab.text, lineEnding: tab.preferredLineEnding)
        }
    }

    func removeDuplicateLines() {
        applyTextTransform("Removed duplicate lines") { tab in
            TextTransforms.removeDuplicateLines(tab.text, lineEnding: tab.preferredLineEnding)
        }
    }

    func uppercaseText() {
        applyTextTransform("Converted to uppercase") { tab in
            tab.text.uppercased()
        }
    }

    func lowercaseText() {
        applyTextTransform("Converted to lowercase") { tab in
            tab.text.lowercased()
        }
    }

    func insertCurrentDateTime() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let value = formatter.string(from: Date())

        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
            textView.insertText(value, replacementRange: textView.selectedRange())
            statusText = "Inserted date and time"
        } else {
            applyTextTransform("Inserted date and time") { tab in
                tab.text + value
            }
        }
    }

    func showDocumentStats() {
        showingDocumentStats = true
    }

    func showFileInfo() {
        showingFileInfo = true
    }

    func showDocumentOutline() {
        showingDocumentOutline = true
    }

    func showTabCompare() {
        showingTabCompare = true
    }

    func showTemplateChooser() {
        showingTemplateChooser = true
    }

    func openScratchpad() {
        do {
            let url = try ScratchpadStore.url()
            if !FileManager.default.fileExists(atPath: url.path) {
                try Data().write(to: url, options: .atomic)
            }
            openFile(at: url)
            statusText = "Opened Scratchpad"
        } catch {
            present(error, action: "open Scratchpad")
        }
    }

    func formatDocument() {
        guard let formatted = DocumentFormatter.format(
            text: activeTab.text,
            fileName: activeTab.fileDisplayName,
            syntaxMode: effectiveSyntaxMode(for: selectedTabID)
        ) else {
            present(message: "TextPort does not have a formatter for this document type yet.")
            return
        }

        applyTextTransform("Formatted \(activeTab.fileDisplayName)") { _ in formatted }
    }

    func minifyDocument() {
        guard let minified = DocumentFormatter.minify(
            text: activeTab.text,
            fileName: activeTab.fileDisplayName,
            syntaxMode: effectiveSyntaxMode(for: selectedTabID)
        ) else {
            present(message: "TextPort does not have a minifier for this document type yet.")
            return
        }

        applyTextTransform("Minified \(activeTab.fileDisplayName)") { _ in minified }
    }

    func exportOpenTabsBundle() {
        do {
            try TextBundleExporter.export(tabs: tabs)
            statusText = "Exported bundle"
        } catch {
            present(error, action: "export bundle")
        }
    }

    func exportPDF() {
        let tab = activeTab
        guard let url = chooseSaveURL(
            defaultExtension: "pdf",
            title: "Export PDF",
            tab: tab,
            suggestedName: suggestedOutputFileName(fileExtension: "pdf", tab: tab)
        ) else { return }

        do {
            try PDFTextExporter.export(tab: tab, fontSize: preferences.fontSize, to: url)
            statusText = "Exported \(url.lastPathComponent)"
        } catch {
            present(error, action: "export PDF")
        }
    }

    func exportRenderedMarkdownHTML() {
        guard activeDocumentCanExportRenderedMarkdownHTML else {
            present(message: "TextPort can export rendered HTML from Markdown files.")
            return
        }

        let tab = activeTab
        guard let url = chooseSaveURL(
            defaultExtension: "html",
            title: "Export Rendered Markdown HTML",
            tab: tab,
            suggestedName: suggestedOutputFileName(fileExtension: "html", tab: tab, suffix: "-rendered")
        ) else { return }

        do {
            try MarkdownHTMLRenderer.html(for: tab.text).write(to: url, atomically: true, encoding: .utf8)
            statusText = "Exported \(url.lastPathComponent)"
        } catch {
            present(error, action: "export rendered HTML")
        }
    }

    func exportJSONVisualHTML() {
        guard activeDocumentCanVisualizeJSON else {
            present(message: "TextPort can export visual HTML from JSON files.")
            return
        }

        switch JSONPreviewParser.parse(activeTab.text) {
        case .success(let root):
            do {
                if let url = try JSONVisualHTMLExporter.export(root: root, documentName: fileDisplayName) {
                    statusText = "Exported \(url.lastPathComponent)"
                }
            } catch {
                present(error, action: "export JSON visual")
            }
        case .failure(let error):
            present(message: "TextPort could not export this JSON. \(error.localizedDescription)")
        }
    }

    func shareCurrentTab() {
        do {
            try SharingService.share(items: [try ShareItemBuilder.sourceFile(for: activeTab)])
            statusText = "Sharing \(activeTab.fileDisplayName)"
        } catch {
            present(error, action: "share")
        }
    }

    func shareSelectedText() {
        let selectedText = selectedTextByTabID[selectedTabID] ?? ""
        guard !selectedText.isEmpty else {
            present(message: "Select text before sharing selected text.")
            return
        }

        do {
            try SharingService.share(items: [selectedText])
            statusText = "Sharing selected text"
        } catch {
            present(error, action: "share selected text")
        }
    }

    func shareRenderedOutput() {
        do {
            let url = try ShareItemBuilder.renderedOutput(
                for: activeTab,
                mode: effectiveSyntaxMode(for: selectedTabID),
                fontSize: preferences.fontSize
            )
            try SharingService.share(items: [url])
            statusText = "Sharing \(url.lastPathComponent)"
        } catch {
            present(error, action: "share rendered output")
        }
    }

    func shareOpenTabsBundle() {
        do {
            let url = try TextBundleExporter.temporaryBundle(tabs: tabs)
            try SharingService.share(items: [url])
            statusText = "Sharing open tabs bundle"
        } catch {
            present(error, action: "share tabs bundle")
        }
    }

    func publishCurrentTabAsSecretGist() {
        let tab = activeTab

        do {
            let sourceURL = try ShareItemBuilder.sourceFile(for: tab)
            let fileName = tab.fileDisplayName
            statusText = "Publishing Gist..."

            Task {
                let result = await Task.detached(priority: .userInitiated) {
                    Result {
                        try GitHubService.createSecretGist(fileURL: sourceURL, fileName: fileName)
                    }
                }.value

                switch result {
                case .success(let gistURL):
                    GitHubService.copyToPasteboard(gistURL.absoluteString)
                    NSWorkspace.shared.open(gistURL)
                    statusText = "Published Gist and copied link"
                case .failure(let error):
                    present(error, action: "publish Gist")
                }
            }
        } catch {
            present(error, action: "prepare Gist")
        }
    }

    func printDocument() {
        PrintService.print(tab: activeTab, fontSize: preferences.fontSize)
    }

    func runActiveFile(using project: ProjectStore) {
        if activeTab.isEdited {
            saveDocument()
        }

        guard !activeTab.isEdited else {
            present(message: "TextPort could not run this file because it still has unsaved changes. Save it first, then run it again.")
            return
        }

        guard let fileURL = activeTab.fileURL else {
            present(message: "Save this file before running it. TextPort runs code from a real file location so relative paths work predictably.")
            return
        }

        project.runFile(at: fileURL)
    }

    func replaceFileReference(from oldURL: URL, to newURL: URL) {
        var changedSelection = false
        for index in tabs.indices {
            guard let fileURL = tabs[index].fileURL, Self.url(fileURL, isSameOrInside: oldURL) else { continue }

            let replacementURL = Self.replacementURL(for: fileURL, oldRoot: oldURL, newRoot: newURL)
            tabs[index].fileURL = replacementURL
            tabs[index].displayName = replacementURL.lastPathComponent
            tabs[index].lastKnownModificationDate = fileModificationDate(for: replacementURL)
            tabs[index].lastExternalChangePromptDate = nil
            changedSelection = true
        }

        if changedSelection {
            statusText = "Updated open file references"
            scheduleSessionSave()
        }
    }

    func detachFileReferences(inside removedURL: URL) {
        var changedSelection = false
        for index in tabs.indices {
            guard let fileURL = tabs[index].fileURL, Self.url(fileURL, isSameOrInside: removedURL) else { continue }

            tabs[index].fileURL = nil
            tabs[index].isEdited = true
            tabs[index].lastKnownModificationDate = nil
            tabs[index].lastExternalChangePromptDate = nil
            changedSelection = true
        }

        if changedSelection {
            statusText = "Detached moved file references"
            scheduleSessionSave()
        }
    }

    func saveDocumentAs() {
        let tab = activeTab
        guard let destination = chooseSaveURL(defaultExtension: defaultFileExtension(for: tab), title: "Save Source As", tab: tab) else { return }
        write(to: destination, for: tab.id, action: "save", updatesDocumentURL: true)
    }

    func saveCopyAs(fileExtension: String) {
        let cleanExtension = fileExtension.isEmpty ? "txt" : fileExtension
        let tab = activeTab
        guard let destination = chooseSaveURL(
            defaultExtension: cleanExtension,
            title: "Save Copy As",
            tab: tab,
            suggestedName: suggestedOutputFileName(fileExtension: cleanExtension, tab: tab)
        ) else { return }
        write(to: destination, for: tab.id, action: "save copy", updatesDocumentURL: false)
    }

    private var activeTabIndex: Int {
        tabs.firstIndex(where: { $0.id == selectedTabID }) ?? 0
    }

    private func makeBlankTab() -> TextDocumentTab {
        TextDocumentTab(
            textEncoding: preferences.defaultEncoding,
            preferredLineEnding: preferences.defaultLineEnding,
            syntaxMode: .automatic
        )
    }

    private func defaultFileExtension(for tab: TextDocumentTab) -> String {
        if let fileURL = tab.fileURL, !fileURL.pathExtension.isEmpty {
            return fileURL.pathExtension
        }

        if !tab.displayName.fileExtension.isEmpty {
            return tab.displayName.fileExtension
        }

        return "txt"
    }

    private func loadFile(at url: URL) {
        if let existingTab = tabs.first(where: { $0.fileURL == url }) {
            selectedTabID = existingTab.id
            statusText = "Selected \(existingTab.fileDisplayName)"
            return
        }

        if OfficeImportService.isLegacyExcel(url) {
            present(OfficeImportError.legacyExcelUnsupported, action: "open")
            return
        }

        if OfficeImportService.isLegacyPowerPoint(url) {
            present(OfficeImportError.legacyPowerPointUnsupported, action: "open")
            return
        }

        if OfficeImportService.isSpreadsheet(url) {
            processFileWithProgress(at: url)
            return
        }

        if OfficeImportService.requiresTextExtraction(url) {
            processFileWithProgress(at: url)
            return
        }

        do {
            let loadedFile = try TextFileLoader.load(url: url)
            openLoadedTextFile(loadedFile, from: url)
        } catch {
            present(error, action: "open")
        }
    }

    private func processFileWithProgress(at url: URL) {
        guard fileImportProgress == nil else {
            queuedProcessedFileURLs.append(url)
            return
        }

        let progress = FileImportProgress(url: url)
        fileImportProgress = progress
        statusText = progress.title

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try ProcessedFileImport.load(url: url)
                }
            }.value

            self.finishProcessingFile(at: url, result: result)
        }
    }

    private func finishProcessingFile(at url: URL, result: Result<ProcessedFileImport, Error>) {
        fileImportProgress = nil

        switch result {
        case .success(.text(let loadedFile)):
            openLoadedTextFile(loadedFile, from: url)
        case .success(.spreadsheet(let sheets)):
            do {
                try openLoadedSpreadsheet(sheets, from: url)
            } catch {
                present(error, action: "open")
            }
        case .failure(let error):
            present(error, action: "open")
        }

        if let nextURL = queuedProcessedFileURLs.first {
            queuedProcessedFileURLs.removeFirst()
            processFileWithProgress(at: nextURL)
        }
    }

    private func openLoadedTextFile(_ loadedFile: LoadedTextFile, from url: URL) {
        let isExtractedText = OfficeImportService.isExtractedTextDocument(url)
        let loadedTab = TextDocumentTab(
            text: loadedFile.text,
            fileURL: isExtractedText ? nil : url,
            displayName: isExtractedText ? OfficeImportService.extractedDisplayName(for: url) : url.lastPathComponent,
            isEdited: isExtractedText,
            textEncoding: loadedFile.textEncoding,
            preferredLineEnding: loadedFile.lineEnding,
            lastKnownModificationDate: isExtractedText ? nil : fileModificationDate(for: url)
        )

        if preferences.reuseBlankTabWhenOpening && shouldReuseActiveBlankTab {
            tabs[activeTabIndex] = loadedTab
        } else {
            tabs.append(loadedTab)
        }

        selectedTabID = loadedTab.id
        addRecentFile(url)
        statusText = isExtractedText ? OfficeImportService.extractedStatus(for: url) : "Opened \(url.lastPathComponent)"
        scheduleSessionSave()
    }

    private func openLoadedSpreadsheet(_ sheets: [ImportedSpreadsheetSheet], from url: URL) throws {
        let baseName = url.deletingPathExtension().lastPathComponent
        let loadedTabs = sheets.map { sheet in
            TextDocumentTab(
                text: sheet.csvText,
                fileURL: nil,
                displayName: "\(baseName) - \(sheet.name).csv",
                isEdited: true,
                textEncoding: .utf8,
                preferredLineEnding: .lf,
                syntaxMode: .automatic
            )
        }

        guard let firstTab = loadedTabs.first else {
            throw OfficeImportError.emptyWorkbook
        }

        if preferences.reuseBlankTabWhenOpening && shouldReuseActiveBlankTab {
            tabs[activeTabIndex] = firstTab
            tabs.append(contentsOf: loadedTabs.dropFirst())
        } else {
            tabs.append(contentsOf: loadedTabs)
        }

        selectedTabID = firstTab.id
        addRecentFile(url)
        statusText = loadedTabs.count == 1
            ? "Converted \(url.lastPathComponent) to CSV"
            : "Converted \(url.lastPathComponent) to \(loadedTabs.count) CSV tabs"
        scheduleSessionSave()
    }

    private func loadSpreadsheet(at url: URL) {
        do {
            let sheets = try OfficeImportService.loadSpreadsheet(url: url)
            try openLoadedSpreadsheet(sheets, from: url)
        } catch {
            present(error, action: "open")
        }
    }

    private var shouldReuseActiveBlankTab: Bool {
        let tab = activeTab
        return tabs.count == 1 && tab.fileURL == nil && tab.text.isEmpty && !tab.isEdited && tab.displayName == "Untitled"
    }

    private func chooseSaveURL(
        defaultExtension: String,
        title: String,
        tab: TextDocumentTab,
        suggestedName: String? = nil
    ) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = suggestedName ?? suggestedFileName(fileExtension: defaultExtension, tab: tab)
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: defaultExtension) ?? .plainText]
        panel.allowsOtherFileTypes = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func suggestedFileName(fileExtension: String, tab: TextDocumentTab) -> String {
        let trimmedName = tab.displayName.trimmedFileName
        let name = trimmedName.isEmpty ? "Untitled" : trimmedName

        if !name.fileExtension.isEmpty {
            return name
        }

        return "\(name).\(fileExtension)"
    }

    private func suggestedOutputFileName(fileExtension: String, tab: TextDocumentTab, suffix: String = "") -> String {
        let trimmedName = tab.displayName.trimmedFileName
        let name = trimmedName.isEmpty ? "Untitled" : trimmedName
        let baseName = name.fileExtension.isEmpty ? name : (name as NSString).deletingPathExtension
        return "\(baseName)\(suffix).\(fileExtension)"
    }

    private func write(to url: URL, for id: UUID, action: String, updatesDocumentURL: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        do {
            let encodedFile = try TextFileWriter.encodedFile(for: tabs[index])
            try encodedFile.data.write(to: url, options: .atomic)

            if updatesDocumentURL || action == "save" {
                mutateTab(id) { tab in
                    tab.fileURL = url
                    tab.displayName = url.lastPathComponent
                    tab.isEdited = false
                    tab.textEncoding = encodedFile.encoding
                    tab.preferredLineEnding = encodedFile.lineEnding
                    tab.lastKnownModificationDate = fileModificationDate(for: url)
                    tab.lastExternalChangePromptDate = nil
                }
            }

            addRecentFile(url)
            statusText = action == "save copy" ? "Saved copy \(url.lastPathComponent)" : "Saved \(url.lastPathComponent)"
            scheduleSessionSave()
        } catch {
            present(error, action: action)
        }
    }

    private func confirmCloseTab(at index: Int) -> Bool {
        let tab = tabs[index]
        guard tab.isEdited else { return true }

        let alert = NSAlert()
        alert.messageText = "Save changes to \(tab.fileDisplayName)?"
        alert.informativeText = "Your unsaved changes will be lost if you do not save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            selectedTabID = tab.id
            saveDocument()
            return !activeTab.isEdited
        case .alertSecondButtonReturn:
            return false
        default:
            return true
        }
    }

    private func commitFileNameChange(for id: UUID) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        let trimmedName = tabs[index].displayName.trimmedFileName

        guard !trimmedName.isEmpty else {
            resetDisplayName(for: index)
            present(message: "File names cannot be empty.")
            return false
        }

        guard trimmedName.isValidFileName else {
            resetDisplayName(for: index)
            present(message: "File names cannot contain / or : characters.")
            return false
        }

        guard let currentURL = tabs[index].fileURL else {
            mutateTab(id) { tab in
                tab.displayName = trimmedName
            }
            return true
        }

        guard trimmedName != currentURL.lastPathComponent else {
            mutateTab(id) { tab in
                tab.displayName = trimmedName
            }
            return true
        }

        let newURL = currentURL.deletingLastPathComponent().appendingPathComponent(trimmedName)

        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            resetDisplayName(for: index)
            present(message: "A file named \(trimmedName) already exists in this folder.")
            return false
        }

        do {
            try FileManager.default.moveItem(at: currentURL, to: newURL)
            mutateTab(id) { tab in
                tab.fileURL = newURL
                tab.displayName = newURL.lastPathComponent
                tab.lastKnownModificationDate = fileModificationDate(for: newURL)
                tab.lastExternalChangePromptDate = nil
            }
            addRecentFile(newURL)
            statusText = "Renamed to \(newURL.lastPathComponent)"
            scheduleSessionSave()
            return true
        } catch {
            resetDisplayName(for: index)
            present(error, action: "rename")
            return false
        }
    }

    private func resetDisplayName(for index: Int) {
        let fallback = tabs[index].fileURL?.lastPathComponent ?? "Untitled"
        let id = tabs[index].id
        mutateTab(id) { tab in
            tab.displayName = fallback
        }
    }

    private func present(_ error: Error, action: String) {
        errorMessage = fileErrorMessage(for: error, action: action)
        showingError = true
        statusText = "Action failed"
    }

    private func present(message: String) {
        errorMessage = message
        showingError = true
        statusText = "Action failed"
    }

    nonisolated private static func fileURL(from item: (any NSSecureCoding)?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        return nil
    }

    private func mutateActiveTab(_ update: (inout TextDocumentTab) -> Void) {
        mutateTab(selectedTabID, update)
    }

    private func mutateTab(_ id: UUID, _ update: (inout TextDocumentTab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        objectWillChange.send()
        update(&tabs[index])
        scheduleSessionSave()
    }

    private func stats(for id: UUID) -> DocumentStats {
        let tab = tabs.first(where: { $0.id == id }) ?? activeTab
        let selectedText = selectedTextByTabID[id] ?? ""
        return DocumentStats(tab: tab, selectedText: selectedText)
    }

    private func cursorPosition(for id: UUID) -> DocumentCursorPosition {
        let tab = tabs.first(where: { $0.id == id }) ?? activeTab
        let nsText = tab.text as NSString
        let rawLocation = selectionRangeByTabID[id]?.location ?? 0
        let location = max(0, min(rawLocation, nsText.length))
        let prefix = nsText.substring(to: location)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = prefix.components(separatedBy: "\n")
        let currentLine = lines.last ?? ""
        return DocumentCursorPosition(
            line: max(1, lines.count),
            column: (currentLine as NSString).length + 1
        )
    }

    private func scheduleSessionSave() {
        sessionSaveTask?.cancel()
        let tabsSnapshot = tabs
        let selectedTabIDSnapshot = selectedTabID

        sessionSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            TextSessionStore.save(tabs: tabsSnapshot, selectedTabID: selectedTabIDSnapshot)
        }
    }

    private func addRecentFile(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        recentFiles = Array(recentFiles.prefix(20))
        RecentFileStore.save(recentFiles)
    }

    private func applyTextTransform(_ status: String, transform: (TextDocumentTab) -> String) {
        mutateActiveTab { tab in
            tab.text = transform(tab)
            tab.isEdited = true
            tab.preferredLineEnding = TextLineEnding.detect(in: tab.text, fallback: tab.preferredLineEnding)
        }
        statusText = status
    }

    private func fileErrorMessage(for error: Error, action: String) -> String {
        let detail = error.localizedDescription

        switch action {
        case "open":
            return """
            TextPort could not open this file.

            It may be locked, damaged, binary, or in a format TextPort cannot convert yet.

            Details: \(detail)
            """
        case "save", "save copy":
            return """
            TextPort could not save this file.

            Check that the folder still exists, you have permission to write there, and there is enough disk space.

            Details: \(detail)
            """
        case let exportAction where exportAction.hasPrefix("export"):
            return """
            TextPort could not create this export.

            The source tab is still unchanged. Try a different destination or export format.

            Details: \(detail)
            """
        case let shareAction where shareAction.hasPrefix("share"):
            return """
            TextPort could not prepare this share item.

            The original file was not changed.

            Details: \(detail)
            """
        case let publishAction where publishAction.contains("Gist"):
            return """
            TextPort could not publish this Gist.

            Make sure GitHub tools are enabled and the GitHub CLI is installed and signed in.

            Details: \(detail)
            """
        default:
            return "TextPort could not \(action) this file. \(detail)"
        }
    }

    private func startFileChangeMonitoring() {
        fileChangeTimer?.invalidate()
        fileChangeTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForExternalFileChanges()
            }
        }
    }

    private func checkForExternalFileChanges() {
        guard externalChangePrompt == nil else { return }

        for tab in tabs {
            guard let url = tab.fileURL, let knownDate = tab.lastKnownModificationDate else { continue }
            guard let currentDate = fileModificationDate(for: url) else { continue }
            guard currentDate.timeIntervalSince(knownDate) > 0.75 else { continue }
            guard tab.lastExternalChangePromptDate != currentDate else { continue }

            mutateTab(tab.id) { changedTab in
                changedTab.lastExternalChangePromptDate = currentDate
            }

            externalChangePrompt = ExternalFileChange(
                tabID: tab.id,
                fileName: tab.fileDisplayName,
                modificationDate: currentDate,
                hasUnsavedChanges: tab.isEdited
            )
            break
        }
    }

    private func fileModificationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private static func url(_ url: URL, isSameOrInside rootURL: URL) -> Bool {
        let rootPath = rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private static func replacementURL(for url: URL, oldRoot: URL, newRoot: URL) -> URL {
        let oldPath = oldRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path

        guard path != oldPath else {
            return newRoot
        }

        let relativeStart = path.index(path.startIndex, offsetBy: oldPath.count + 1)
        let relativePath = String(path[relativeStart...])
        return newRoot.appendingPathComponent(relativePath)
    }
}

struct TextDocumentTab: Identifiable, Equatable, Codable {
    let id: UUID
    var text: String
    var fileURL: URL?
    var displayName: String
    var isEdited: Bool
    var textEncoding: TextEncoding
    var preferredLineEnding: TextLineEnding
    var lastKnownModificationDate: Date?
    var lastExternalChangePromptDate: Date?
    var syntaxMode: SyntaxHighlightMode
    var customSyntaxID: UUID?

    init(
        id: UUID = UUID(),
        text: String = "",
        fileURL: URL? = nil,
        displayName: String = "Untitled",
        isEdited: Bool = false,
        textEncoding: TextEncoding = .utf8,
        preferredLineEnding: TextLineEnding = .lf,
        lastKnownModificationDate: Date? = nil,
        lastExternalChangePromptDate: Date? = nil,
        syntaxMode: SyntaxHighlightMode = .automatic,
        customSyntaxID: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.fileURL = fileURL
        self.displayName = displayName
        self.isEdited = isEdited
        self.textEncoding = textEncoding
        self.preferredLineEnding = preferredLineEnding
        self.lastKnownModificationDate = lastKnownModificationDate
        self.lastExternalChangePromptDate = lastExternalChangePromptDate
        self.syntaxMode = syntaxMode
        self.customSyntaxID = customSyntaxID
    }

    var fileDisplayName: String {
        let trimmedName = displayName.trimmedFileName
        return trimmedName.isEmpty ? "Untitled" : trimmedName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case fileURL
        case displayName
        case isEdited
        case textEncoding
        case preferredLineEnding
        case lastKnownModificationDate
        case lastExternalChangePromptDate
        case syntaxMode
        case customSyntaxID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        fileURL = try container.decodeIfPresent(URL.self, forKey: .fileURL)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "Untitled"
        isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        textEncoding = try container.decodeIfPresent(TextEncoding.self, forKey: .textEncoding) ?? .utf8
        preferredLineEnding = try container.decodeIfPresent(TextLineEnding.self, forKey: .preferredLineEnding) ?? .lf
        lastKnownModificationDate = try container.decodeIfPresent(Date.self, forKey: .lastKnownModificationDate)
        lastExternalChangePromptDate = try container.decodeIfPresent(Date.self, forKey: .lastExternalChangePromptDate)
        syntaxMode = try container.decodeIfPresent(SyntaxHighlightMode.self, forKey: .syntaxMode) ?? .automatic
        customSyntaxID = try container.decodeIfPresent(UUID.self, forKey: .customSyntaxID)
    }
}

struct DocumentStats {
    let fileName: String
    let lines: Int
    let words: Int
    let characters: Int
    let bytes: Int
    let fileSize: Int?
    let selectedLines: Int
    let selectedWords: Int
    let selectedCharacters: Int
    let selectedBytes: Int

    init(tab: TextDocumentTab, selectedText: String) {
        fileName = tab.fileDisplayName
        lines = TextMetrics.lineCount(in: tab.text)
        words = TextMetrics.wordCount(in: tab.text)
        characters = tab.text.count
        bytes = TextFileWriter.encodedData(for: tab).map(\.count) ?? tab.text.utf8.count
        fileSize = tab.fileURL.flatMap { url in
            try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        }
        selectedLines = selectedText.isEmpty ? 0 : TextMetrics.lineCount(in: selectedText)
        selectedWords = TextMetrics.wordCount(in: selectedText)
        selectedCharacters = selectedText.count
        selectedBytes = selectedText.data(using: tab.textEncoding.stringEncoding)?.count ?? selectedText.utf8.count
    }
}

struct DocumentFileInfo {
    let fileName: String
    let path: String?
    let folder: String?
    let fileSize: Int?
    let modifiedDate: Date?
    let encoding: String
    let lineEnding: String
    let syntax: String
    let stateLabel: String
    let saveBehavior: String

    init(tab: TextDocumentTab, syntaxLabel: String) {
        fileName = tab.fileDisplayName
        path = tab.fileURL?.standardizedFileURL.path
        folder = tab.fileURL?.deletingLastPathComponent().standardizedFileURL.path
        encoding = tab.textEncoding.label
        lineEnding = tab.preferredLineEnding.label
        syntax = syntaxLabel

        if let fileURL = tab.fileURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        {
            fileSize = attributes[.size] as? Int
            modifiedDate = attributes[.modificationDate] as? Date
        } else {
            fileSize = nil
            modifiedDate = nil
        }

        if tab.fileURL == nil {
            stateLabel = tab.isEdited ? "Unsaved editable copy" : "Unsaved draft"
            saveBehavior = "Save will ask where to create the source file."
        } else if tab.isEdited {
            stateLabel = "Saved file with unsaved changes"
            saveBehavior = "Save will write changes back to the file path."
        } else {
            stateLabel = "Saved file"
            saveBehavior = "Save writes back to the file path when changes are made."
        }
    }
}

struct DocumentCursorPosition: Equatable {
    let line: Int
    let column: Int
}

struct QuickOpenItem: Identifiable, Equatable {
    let title: String
    let subtitle: String
    let kind: QuickOpenKind

    var id: String {
        switch kind {
        case .openTab(let id):
            "tab-\(id.uuidString)"
        case .recentFile(let url):
            "recent-\(url.path)"
        case .projectFile(let url):
            "project-\(url.path)"
        }
    }
}

enum QuickOpenKind: Equatable {
    case openTab(UUID)
    case recentFile(URL)
    case projectFile(URL)
}

struct FileImportProgress: Identifiable, Equatable {
    let id = UUID()
    let fileName: String
    let title: String
    let detail: String

    init(url: URL) {
        fileName = url.lastPathComponent

        switch url.pathExtension.lowercased() {
        case "pdf":
            title = "Extracting PDF Text"
            detail = "TextPort is reading the pages and cleaning the extracted body text."
        case "docx":
            title = "Extracting Word Text"
            detail = "TextPort is unpacking the document and collecting the main body text."
        case "pptx":
            title = "Extracting Slide Text"
            detail = "TextPort is reading the slide deck and collecting visible slide text."
        case "xlsx", "xlsm":
            title = "Converting Workbook"
            detail = "TextPort is converting workbook sheets into editable CSV tabs."
        default:
            title = "Opening File"
            detail = "TextPort is preparing the file."
        }
    }
}

struct SessionRecoveryNotice: Equatable {
    let tabCount: Int

    var title: String {
        "Previous Session Restored"
    }

    var message: String {
        let tabText = tabCount == 1 ? "1 tab" : "\(tabCount) tabs"
        return "\(tabText) reopened. Unsaved drafts stay local until you save or close them."
    }
}

private enum ProcessedFileImport: Sendable {
    case text(LoadedTextFile)
    case spreadsheet([ImportedSpreadsheetSheet])

    static func load(url: URL) throws -> ProcessedFileImport {
        if OfficeImportService.isSpreadsheet(url) {
            return .spreadsheet(try OfficeImportService.loadSpreadsheet(url: url))
        }

        return .text(try TextFileLoader.load(url: url))
    }
}

enum SyntaxHighlightMode: String, CaseIterable, Codable {
    case automatic
    case plainText
    case json
    case markdown
    case html
    case css
    case cFamily
    case go
    case javascript
    case java
    case swift
    case python
    case ruby
    case rust
    case shell
    case sql
    case toml
    case yaml

    var label: String {
        switch self {
        case .automatic: "Automatic"
        case .plainText: "Plain Text"
        case .json: "JSON"
        case .markdown: "Markdown"
        case .html: "HTML"
        case .css: "CSS"
        case .cFamily: "C / C++"
        case .go: "Go"
        case .javascript: "JavaScript"
        case .java: "Java"
        case .swift: "Swift"
        case .python: "Python"
        case .ruby: "Ruby"
        case .rust: "Rust"
        case .shell: "Shell"
        case .sql: "SQL"
        case .toml: "TOML"
        case .yaml: "YAML"
        }
    }

    static func detect(fileName: String, text: String) -> SyntaxHighlightMode {
        switch fileName.fileExtension.lowercased() {
        case "json":
            return .json
        case "md", "markdown", "mdown":
            return .markdown
        case "html", "htm", "xml", "svg":
            return .html
        case "css":
            return .css
        case "c", "h", "cc", "cpp", "cxx", "hpp", "hh":
            return .cFamily
        case "go":
            return .go
        case "js", "mjs", "cjs", "ts", "tsx", "jsx":
            return .javascript
        case "java":
            return .java
        case "swift":
            return .swift
        case "py":
            return .python
        case "rb":
            return .ruby
        case "rs":
            return .rust
        case "sh", "bash", "zsh", "command":
            return .shell
        case "sql":
            return .sql
        case "toml":
            return .toml
        case "yaml", "yml":
            return .yaml
        default:
            break
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.first == "{" || trimmed.first == "[" {
            return .json
        }

        if trimmed.hasPrefix("#!") {
            return .shell
        }

        return .plainText
    }
}

struct ExternalFileChange: Identifiable {
    let tabID: UUID
    let fileName: String
    let modificationDate: Date
    let hasUnsavedChanges: Bool

    var id: String {
        "\(tabID.uuidString)-\(modificationDate.timeIntervalSince1970)"
    }
}

enum RecentFileStore {
    private static let storageKey = "TextPortRecentFiles"

    static func load() -> [URL] {
        let paths = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return paths.map { URL(fileURLWithPath: $0) }
    }

    static func save(_ urls: [URL]) {
        UserDefaults.standard.set(urls.map(\.path), forKey: storageKey)
    }
}

enum TextTransforms {
    static func trimTrailingWhitespace(_ text: String, lineEnding: TextLineEnding) -> String {
        transformLines(text, lineEnding: lineEnding) { line in
            line.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression)
        }
    }

    static func sortLines(_ text: String, lineEnding: TextLineEnding) -> String {
        let lines = normalizedLines(text)
        return rejoin(lines.sorted { $0.localizedStandardCompare($1) == .orderedAscending }, text: text, lineEnding: lineEnding)
    }

    static func removeDuplicateLines(_ text: String, lineEnding: TextLineEnding) -> String {
        var seen = Set<String>()
        let uniqueLines = normalizedLines(text).filter { line in
            seen.insert(line).inserted
        }
        return rejoin(uniqueLines, text: text, lineEnding: lineEnding)
    }

    private static func transformLines(
        _ text: String,
        lineEnding: TextLineEnding,
        transform: (String) -> String
    ) -> String {
        let transformedLines = normalizedLines(text).map(transform)
        return rejoin(transformedLines, text: text, lineEnding: lineEnding)
    }

    private static func normalizedLines(_ text: String) -> [String] {
        let normalized = TextLineEnding.lf.normalized(text)
        var lines = normalized.components(separatedBy: "\n")

        if normalized.hasSuffix("\n") {
            lines.removeLast()
        }

        return lines
    }

    private static func rejoin(_ lines: [String], text: String, lineEnding: TextLineEnding) -> String {
        let separator = lineEnding.sequence ?? "\n"
        var result = lines.joined(separator: separator)

        if text.hasSuffix("\n") || text.hasSuffix("\r") {
            result += separator
        }

        return result
    }
}

extension String {
    var normalizedFileExtension: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    var trimmedFileName: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var fileExtension: String {
        (self as NSString).pathExtension
    }

    var isValidFileName: Bool {
        !contains("/") && !contains(":")
    }
}

struct LoadedTextFile: Sendable {
    let text: String
    let textEncoding: TextEncoding
    let lineEnding: TextLineEnding
}

enum TextFileLoader {
    static func load(url: URL) throws -> LoadedTextFile {
        if url.pathExtension.lowercased() == "docx" {
            return try OfficeImportService.loadWordDocument(url: url)
        } else if url.pathExtension.lowercased() == "pptx" {
            return try OfficeImportService.loadPresentation(url: url)
        } else if url.pathExtension.lowercased() == "pdf" {
            return try loadPDF(url: url)
        }

        let data = try Data(contentsOf: url)

        guard !looksBinary(data) || looksLikeUTF16(data) else {
            throw TextFileLoaderError.binaryFile
        }

        for candidate in encodingCandidates {
            if let text = String(data: data, encoding: candidate.encoding) {
                return LoadedTextFile(
                    text: text,
                    textEncoding: candidate.textEncoding,
                    lineEnding: TextLineEnding.detect(in: text, fallback: .lf)
                )
            }
        }

        throw TextFileLoaderError.unsupportedEncoding
    }

    private static func loadPDF(url: URL) throws -> LoadedTextFile {
        guard let document = PDFDocument(url: url) else {
            throw TextFileLoaderError.unsupportedPDF
        }

        let pageText = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !pageText.isEmpty else {
            throw TextFileLoaderError.pdfTextUnavailable
        }

        let text = ImportedTextCleaner.clean(pageText.joined(separator: "\n\n"), source: .pdf)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TextFileLoaderError.pdfTextUnavailable
        }

        return LoadedTextFile(
            text: text,
            textEncoding: .utf8,
            lineEnding: .lf
        )
    }

    private static var encodingCandidates: [(encoding: String.Encoding, textEncoding: TextEncoding)] {
        [
            (.utf8, .utf8),
            (.utf16, .utf16),
            (.utf16LittleEndian, .utf16LittleEndian),
            (.utf16BigEndian, .utf16BigEndian),
            (.ascii, .ascii),
            (windowsLatin1Encoding, .windowsLatin1),
            (.isoLatin1, .isoLatin1)
        ]
    }

    private static let windowsLatin1Encoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(0x0500)
        )
    )

    private static func looksBinary(_ data: Data) -> Bool {
        data.prefix(8_192).contains(0)
    }

    private static func looksLikeUTF16(_ data: Data) -> Bool {
        let bytes = Array(data.prefix(512))

        if bytes.starts(with: [0xff, 0xfe]) || bytes.starts(with: [0xfe, 0xff]) {
            return true
        }

        guard bytes.count >= 8 else { return false }

        let evenNulls = stride(from: 0, to: bytes.count, by: 2).filter { bytes[$0] == 0 }.count
        let oddNulls = stride(from: 1, to: bytes.count, by: 2).filter { bytes[$0] == 0 }.count
        let halfCount = max(bytes.count / 2, 1)

        return Double(evenNulls) / Double(halfCount) > 0.35
            || Double(oddNulls) / Double(halfCount) > 0.35
    }
}

enum TextFileWriter {
    static func encodedFile(for tab: TextDocumentTab) throws -> EncodedTextFile {
        let text = tab.preferredLineEnding.normalized(tab.text)

        if let data = text.data(using: tab.textEncoding.stringEncoding) {
            return EncodedTextFile(
                data: data,
                encoding: tab.textEncoding,
                lineEnding: tab.preferredLineEnding
            )
        }

        guard let utf8Data = text.data(using: .utf8) else {
            throw TextFileWriterError.encodingFailed
        }

        return EncodedTextFile(data: utf8Data, encoding: .utf8, lineEnding: tab.preferredLineEnding)
    }

    static func encodedData(for tab: TextDocumentTab) -> Data? {
        try? encodedFile(for: tab).data
    }
}

struct EncodedTextFile {
    let data: Data
    let encoding: TextEncoding
    let lineEnding: TextLineEnding
}

enum TextFileWriterError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        "TextPort could not encode this text."
    }
}

enum TextEncoding: String, CaseIterable, Codable, Sendable {
    case utf8
    case utf16
    case utf16LittleEndian
    case utf16BigEndian
    case ascii
    case windowsLatin1
    case isoLatin1

    var label: String {
        switch self {
        case .utf8: "UTF-8"
        case .utf16: "UTF-16"
        case .utf16LittleEndian: "UTF-16 LE"
        case .utf16BigEndian: "UTF-16 BE"
        case .ascii: "ASCII"
        case .windowsLatin1: "Windows Latin 1"
        case .isoLatin1: "ISO Latin 1"
        }
    }

    var stringEncoding: String.Encoding {
        switch self {
        case .utf8:
            .utf8
        case .utf16:
            .utf16
        case .utf16LittleEndian:
            .utf16LittleEndian
        case .utf16BigEndian:
            .utf16BigEndian
        case .ascii:
            .ascii
        case .windowsLatin1:
            String.Encoding(
                rawValue: CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(0x0500)
                )
            )
        case .isoLatin1:
            .isoLatin1
        }
    }
}

enum TextLineEnding: String, CaseIterable, Codable, Sendable {
    case lf
    case crlf
    case cr
    case mixed
    case none

    static var menuCases: [TextLineEnding] {
        [.lf, .crlf, .cr]
    }

    var label: String {
        switch self {
        case .lf: "LF"
        case .crlf: "CRLF"
        case .cr: "CR"
        case .mixed: "Mixed endings"
        case .none: "No line endings"
        }
    }

    var sequence: String? {
        switch self {
        case .lf:
            "\n"
        case .crlf:
            "\r\n"
        case .cr:
            "\r"
        case .mixed, .none:
            nil
        }
    }

    static func detect(in text: String, fallback: TextLineEnding) -> TextLineEnding {
        var crlfCount = 0
        var lfCount = 0
        var crCount = 0
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\r" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    crlfCount += 1
                    index = text.index(after: nextIndex)
                } else {
                    crCount += 1
                    index = nextIndex
                }
            } else if character == "\n" {
                lfCount += 1
                index = text.index(after: index)
            } else {
                index = text.index(after: index)
            }
        }

        let presentLineEndings = [crlfCount, lfCount, crCount].filter { $0 > 0 }.count

        if presentLineEndings > 1 {
            return .mixed
        }

        if crlfCount > 0 {
            return .crlf
        }

        if lfCount > 0 {
            return .lf
        }

        if crCount > 0 {
            return .cr
        }

        return fallback == .mixed ? .none : fallback
    }

    func normalized(_ text: String) -> String {
        guard let sequence else { return text }

        var normalizedText = ""
        normalizedText.reserveCapacity(text.count)
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\r" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    normalizedText += sequence
                    index = text.index(after: nextIndex)
                } else {
                    normalizedText += sequence
                    index = nextIndex
                }
            } else if character == "\n" {
                normalizedText += sequence
                index = text.index(after: index)
            } else {
                normalizedText.append(character)
                index = text.index(after: index)
            }
        }

        return normalizedText
    }
}

struct TextSession: Codable {
    let tabs: [TextDocumentTab]
    let selectedTabID: UUID
}

enum TextSessionStore {
    static func load() -> TextSession? {
        guard let data = try? Data(contentsOf: sessionURL) else { return nil }
        return try? JSONDecoder().decode(TextSession.self, from: data)
    }

    static func save(tabs: [TextDocumentTab], selectedTabID: UUID) {
        let session = TextSession(tabs: tabs, selectedTabID: selectedTabID)

        do {
            try FileManager.default.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(session)
            try data.write(to: sessionURL, options: .atomic)
            try TextDraftStore.saveDrafts(for: tabs, in: appSupportURL.appendingPathComponent("Drafts", isDirectory: true))
        } catch {
            // Session restore is helpful but should never interrupt editing.
        }
    }

    private static var sessionURL: URL {
        appSupportURL.appendingPathComponent("session.json")
    }

    private static var appSupportURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("TextPort", isDirectory: true)
    }
}

enum TextDraftStore {
    static func saveDrafts(for tabs: [TextDocumentTab], in draftsURL: URL) throws {
        try FileManager.default.createDirectory(at: draftsURL, withIntermediateDirectories: true)

        let activeDraftIDs = Set(tabs.filter { $0.fileURL == nil || $0.isEdited }.map(\.id.uuidString))
        let existingDrafts = (try? FileManager.default.contentsOfDirectory(at: draftsURL, includingPropertiesForKeys: nil)) ?? []

        for draftURL in existingDrafts where draftURL.pathExtension == "txt" {
            if !activeDraftIDs.contains(draftURL.deletingPathExtension().lastPathComponent) {
                try? FileManager.default.removeItem(at: draftURL)
            }
        }

        for tab in tabs where tab.fileURL == nil || tab.isEdited {
            let draftURL = draftsURL.appendingPathComponent(tab.id.uuidString).appendingPathExtension("txt")
            try tab.text.write(to: draftURL, atomically: true, encoding: .utf8)
        }
    }
}

enum TextFileLoaderError: LocalizedError {
    case binaryFile
    case pdfTextUnavailable
    case unsupportedPDF
    case unsupportedEncoding

    var errorDescription: String? {
        switch self {
        case .binaryFile:
            "This looks like a binary file, not a plain text file."
        case .pdfTextUnavailable:
            "TextPort opened the PDF, but it does not contain extractable text."
        case .unsupportedPDF:
            "TextPort could not read this PDF."
        case .unsupportedEncoding:
            "The file uses an encoding TextPort does not recognize yet."
        }
    }
}

enum TextMetrics {
    static func lineCount(in text: String) -> Int {
        var lineCount = 1
        var previousCharacterWasCarriageReturn = false

        for character in text {
            if character == "\n" {
                if !previousCharacterWasCarriageReturn {
                    lineCount += 1
                }
                previousCharacterWasCarriageReturn = false
            } else if character == "\r" {
                lineCount += 1
                previousCharacterWasCarriageReturn = true
            } else {
                previousCharacterWasCarriageReturn = false
            }
        }

        return lineCount
    }

    static func wordCount(in text: String) -> Int {
        let words = text.split { character in
            character.isWhitespace || character.isPunctuation
        }
        return words.count
    }

    static func lineEndingDescription(in text: String) -> String {
        var crlfCount = 0
        var lfCount = 0
        var crCount = 0
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\r" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    crlfCount += 1
                    index = text.index(after: nextIndex)
                } else {
                    crCount += 1
                    index = nextIndex
                }
            } else if character == "\n" {
                lfCount += 1
                index = text.index(after: index)
            } else {
                index = text.index(after: index)
            }
        }

        let presentLineEndings = [crlfCount, lfCount, crCount].filter { $0 > 0 }.count

        if presentLineEndings > 1 {
            return "Mixed endings"
        }

        if crlfCount > 0 {
            return "CRLF"
        }

        if lfCount > 0 {
            return "LF"
        }

        if crCount > 0 {
            return "CR"
        }

        return "No line endings"
    }
}
