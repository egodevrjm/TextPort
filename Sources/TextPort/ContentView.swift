import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @EnvironmentObject private var preferences: AppPreferences
    @State private var isDroppingFile = false

    var body: some View {
        VStack(spacing: 0) {
            tabStrip

            editor

            statusBar
        }
        .background {
            WindowTitlebarAccessor()
                .environmentObject(document)
                .frame(width: 0, height: 0)
        }
        .navigationTitle(document.windowTitle)
        .onOpenURL { url in
            document.openFile(at: url)
        }
        .sheet(isPresented: $document.showingExportSheet) {
            ExportView()
                .environmentObject(document)
        }
        .sheet(isPresented: $document.showingQuickOpenSheet) {
            QuickOpenView()
                .environmentObject(document)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            document.persistSessionImmediately()
        }
    }

    private var editor: some View {
        ZStack {
            PlainTextEditorView(
                text: Binding(
                get: { document.activeText },
                set: { document.updateActiveText($0) }
                ),
                fontSize: preferences.fontSize,
                showLineNumbers: preferences.showLineNumbers,
                wordWrap: preferences.wordWrap
            )
            .background(Color(nsColor: .textBackgroundColor))

            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.accentColor, lineWidth: isDroppingFile ? 3 : 0)
                .allowsHitTesting(false)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDroppingFile) { providers in
            document.openDroppedFile(providers)
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
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }

            Spacer(minLength: 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var statusBar: some View {
        HStack {
            Text(document.statusText)
            Text(document.detailText)
            Spacer()
            Text(document.lineCountText)
            Text(document.characterCountText)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
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
        .padding(.trailing, 6)
        .frame(height: 30)
        .background(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isSelected ? Color(nsColor: .separatorColor) : Color.clear)
        }
    }
}
