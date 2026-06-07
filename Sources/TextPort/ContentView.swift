import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @EnvironmentObject private var project: ProjectStore
    @EnvironmentObject private var preferences: AppPreferences
    @State private var isDroppingFile = false
    @State private var restoredProjectTabs = false

    var body: some View {
        rootLayout
        .toolbar {
            ToolbarItemGroup {
                Button {
                    document.openDocument()
                } label: {
                    Label("Open File", systemImage: "doc.badge.plus")
                }
                .help("Open File")

                Button {
                    openProjectPanel()
                } label: {
                    Label("Open Project", systemImage: "folder.badge.plus")
                }
                .help("Open Project")

                Button {
                    document.showQuickOpen()
                } label: {
                    Label("Open Quickly", systemImage: "magnifyingglass")
                }
                .help("Open Quickly")

                if let previewKind = activePreviewKind {
                    Button {
                        preferences.renderPreview.toggle()
                    } label: {
                        Label(preferences.renderPreview ? "Edit Source" : "Render Preview", systemImage: preferences.renderPreview ? "pencil" : "eye")
                    }
                    .help(preferences.renderPreview ? "Show Source" : "Render \(previewKind.label) Preview")
                }

                if document.activeDocumentCanVisualizeJSON {
                    Button {
                        document.showJSONVisualizer()
                    } label: {
                        Label("Visualize JSON", systemImage: "chart.bar.doc.horizontal")
                    }
                    .help("Visualize JSON")
                }

                if project.hasProject {
                    Button {
                        project.showFindInProject()
                    } label: {
                        Label("Find in Project", systemImage: "text.magnifyingglass")
                    }
                    .help("Find in Project")
                }

                if project.taskRunState.isRunning {
                    Button {
                        project.stopTask()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .help("Stop Running Task")
                } else if activeRunCommand != nil {
                    Button {
                        runActiveFile()
                    } label: {
                        Label("Run File", systemImage: "play.fill")
                    }
                    .help("Run \(document.fileDisplayName)")
                } else if project.hasProject {

                    Button {
                        project.runSelectedTask()
                    } label: {
                        Label("Run Task", systemImage: "play.fill")
                    }
                    .help("Run Selected Task")
                }
            }
        }
        .background {
            WindowTitlebarAccessor()
                .environmentObject(document)
                .frame(width: 0, height: 0)
        }
        .navigationTitle(project.windowTitle(fileTitle: document.windowTitle))
        .onOpenURL { url in
            if ProjectStore.isDirectory(url) || ProjectArchiveImporter.isZipArchive(url) {
                project.openProjectSelection(at: url)
                document.openFiles(at: project.consumeRestoredOpenTabURLs())
            } else {
                document.openFile(at: url)
            }
        }
        .sheet(isPresented: $document.showingExportSheet) {
            ExportView()
                .environmentObject(document)
        }
        .sheet(isPresented: $document.showingSaveCopySheet) {
            SaveCopyView()
                .environmentObject(document)
        }
        .sheet(isPresented: $document.showingQuickOpenSheet) {
            QuickOpenView()
                .environmentObject(document)
                .environmentObject(project)
        }
        .sheet(isPresented: $document.showingCommandPalette) {
            CommandPaletteView()
                .environmentObject(document)
                .environmentObject(project)
                .environmentObject(preferences)
        }
        .sheet(isPresented: $document.showingDocumentStats) {
            DocumentStatsView(stats: document.activeDocumentStats)
        }
        .sheet(isPresented: $document.showingJSONVisualizer) {
            JSONVisualStructureView(documentName: document.fileDisplayName, json: document.activeText)
        }
        .sheet(isPresented: $document.showingTabCompare) {
            TabCompareView()
                .environmentObject(document)
        }
        .sheet(isPresented: $document.showingDocumentOutline) {
            DocumentOutlineView()
                .environmentObject(document)
        }
        .sheet(isPresented: $document.showingTemplateChooser) {
            FileTemplateChooserView()
                .environmentObject(document)
        }
        .sheet(isPresented: $document.showingHelpGuide) {
            HelpGuideView()
                .environmentObject(document)
        }
        .sheet(isPresented: $project.showingTaskManager) {
            TaskManagerView()
                .environmentObject(project)
        }
        .alert(item: $document.externalChangePrompt) { change in
            Alert(
                title: Text("\(change.fileName) changed on disk"),
                message: Text(change.hasUnsavedChanges ? "You have unsaved changes in TextPort. Reloading will replace them with the file on disk." : "Another app changed this file. Reload it?"),
                primaryButton: .default(Text("Reload")) {
                    document.reloadExternalChange(change)
                },
                secondaryButton: .cancel(Text("Keep Current")) {
                    document.keepCurrentVersion(change)
                }
            )
        }
        .alert("Could Not Complete Action", isPresented: $document.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(document.errorMessage)
        }
        .alert("Could Not Complete Project Action", isPresented: $project.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(project.errorMessage)
        }
        .onAppear {
            guard !restoredProjectTabs else { return }
            restoredProjectTabs = true
            document.openFiles(at: project.consumeRestoredOpenTabURLs())
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            project.persistOpenTabs(document.tabs)
            project.persistCurrentState()
            document.persistSessionImmediately()
        }
    }

    private var rootLayout: some View {
        NavigationSplitView(columnVisibility: Binding(
            get: { project.isSidebarVisible ? .all : .detailOnly },
            set: { project.isSidebarVisible = $0 != .detailOnly }
        )) {
            ProjectSidebarView()
                .environmentObject(document)
                .environmentObject(project)
        } detail: {
            editorWorkspace
        }
    }

    private var editorWorkspace: some View {
        VStack(spacing: 0) {
            tabStrip

            editor

            statusBar

            if project.isBottomPanelVisible {
                Divider()
                ProjectBottomPanelView()
                    .environmentObject(document)
                    .environmentObject(project)
                    .frame(height: 220)
            }
        }
    }

    private var editor: some View {
        ZStack {
            if document.splitViewEnabled, let secondaryTab = document.secondaryTab {
                HStack(spacing: 1) {
                    editorPane(for: document.activeTab)
                    editorPane(for: secondaryTab)
                }
                .background(Color(nsColor: .separatorColor))
            } else {
                editorPane(for: document.activeTab)
            }

            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.accentColor, lineWidth: isDroppingFile ? 3 : 0)
                .allowsHitTesting(false)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDroppingFile) { providers in
            document.openDroppedFile(providers)
        }
    }

    private func editorPane(for tab: TextDocumentTab) -> some View {
        VStack(spacing: 0) {
            if document.splitViewEnabled {
                HStack {
                    Text(tab.fileDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    if tab.id == document.secondaryTabID {
                        Picker("Split Tab", selection: Binding(
                            get: { tab.id },
                            set: { document.setSecondaryTab($0) }
                        )) {
                            ForEach(document.tabs) { option in
                                Text(option.fileDisplayName).tag(option.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(nsColor: .windowBackgroundColor))
            }

            let syntaxMode = document.effectiveSyntaxMode(for: tab.id)
            if preferences.renderPreview, let previewKind = RenderedPreviewKind.detect(fileName: tab.fileDisplayName, syntaxMode: syntaxMode) {
                RenderedPreviewView(tab: tab, kind: previewKind)
            } else {
                PlainTextEditorView(
                    tabID: tab.id,
                    text: Binding(
                        get: { document.text(for: tab.id) },
                        set: { document.updateText(for: tab.id, $0) }
                    ),
                    fontSize: preferences.fontSize,
                    showLineNumbers: preferences.showLineNumbers,
                    wordWrap: preferences.wordWrap,
                    syntaxMode: syntaxMode,
                    selectionChanged: { selectedText in
                        document.updateSelectedText(for: tab.id, selectedText: selectedText)
                    }
                )
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    private var tabStrip: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(document.tabs) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: tab.id == document.selectedTabID,
                            select: {
                                document.commitActiveFileNameChange()
                                document.selectTab(tab.id)
                            },
                            close: {
                                document.closeTab(tab.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }

            Spacer(minLength: 10)
        }
        .background(.bar)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text(document.statusText)
                .lineLimit(1)

            Divider()
                .frame(height: 12)

            Text(document.detailText)
                .lineLimit(1)

            Spacer()

            Text(document.lineCountText)
            Text(document.characterCountText)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(.bar)
    }

    private func openProjectPanel() {
        project.persistOpenTabs(document.tabs)
        project.openProjectPanel()
        document.openFiles(at: project.consumeRestoredOpenTabURLs())
    }

    private var activePreviewKind: RenderedPreviewKind? {
        RenderedPreviewKind.detect(
            fileName: document.activeTab.fileDisplayName,
            syntaxMode: document.effectiveSyntaxMode(for: document.activeTab.id)
        )
    }

    private var activeRunCommand: RunFileCommand? {
        document.activeFileRunCommand
    }

    private func runActiveFile() {
        document.runActiveFile(using: project)
    }
}

private struct TabButton: View {
    let tab: TextDocumentTab
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button(action: select) {
                HStack(spacing: 7) {
                    if tab.isEdited {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 7, height: 7)
                    }

                    Text(tab.fileDisplayName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 170, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close Tab")
        }
        .font(.caption)
        .padding(.leading, tab.isEdited ? 9 : 12)
        .padding(.trailing, 5)
        .frame(height: 26)
        .background(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
