import SwiftUI

@main
struct TextPortApp: App {
    @StateObject private var document = TextDocumentStore()
    @StateObject private var project = ProjectStore()
    @StateObject private var preferences = AppPreferences.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(document)
                .environmentObject(project)
                .environmentObject(preferences)
                .frame(minWidth: 900, minHeight: 560)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    document.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open...") {
                    document.openDocument()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Project...") {
                    openProjectPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .option])

                Button("Open Quickly...") {
                    document.showQuickOpen()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Menu("Open Recent") {
                    if document.recentFiles.isEmpty {
                        Button("No Recent Files") {}
                            .disabled(true)
                    } else {
                        ForEach(document.recentFiles, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                document.openFile(at: url)
                            }
                        }

                        Divider()

                        Button("Clear Menu") {
                            document.clearRecentFiles()
                        }
                    }
                }

                Button("Rename...") {
                    document.beginRenamingActiveTab()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("Close Tab") {
                    document.closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    document.saveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As...") {
                    document.saveDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Export...") {
                    document.showingExportSheet = true
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Export PDF...") {
                    document.exportPDF()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .printItem) {
                Button("Print...") {
                    document.printDocument()
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            CommandGroup(after: .textEditing) {
                Divider()

                Button("Find...") {
                    FindCommands.perform(.showFind)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find and Replace...") {
                    FindCommands.perform(.showReplace)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])

                Button("Find Next") {
                    FindCommands.perform(.next)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    FindCommands.perform(.previous)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button("Use Selection for Find") {
                    FindCommands.perform(.useSelectionForFind)
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("Replace") {
                    FindCommands.perform(.replace)
                }

                Button("Replace and Find") {
                    FindCommands.perform(.replaceAndFind)
                }

                Button("Replace All") {
                    FindCommands.perform(.replaceAll)
                }
            }

            CommandMenu("Tabs") {
                Button("Previous Tab") {
                    document.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Next Tab") {
                    document.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Divider()

                Button("Close Tab") {
                    document.closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandMenu("Project") {
                Button("Open Project...") {
                    openProjectPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .option])

                Menu("Open Recent Project") {
                    if project.recentProjects.isEmpty {
                        Button("No Recent Projects") {}
                            .disabled(true)
                    } else {
                        ForEach(project.recentProjects) { recentProject in
                            Button(recentProject.displayName) {
                                openRecentProject(recentProject)
                            }
                        }
                    }
                }

                Button("Close Project") {
                    closeProject()
                }
                .disabled(!project.hasProject)

                Divider()

                Button("New File") {
                    if let url = project.createFile() {
                        document.openFile(at: url)
                    }
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(!project.hasProject)

                Button("New Folder") {
                    project.createFolder()
                }
                .disabled(!project.hasProject)

                Button("Rename") {
                    if let change = project.renameSelectedItem() {
                        document.replaceFileReference(from: change.oldURL, to: change.newURL)
                    }
                }
                .disabled(project.selectedFileURL == nil)

                Button("Move to Trash") {
                    if let trashedURL = project.moveSelectedItemToTrash() {
                        document.detachFileReferences(inside: trashedURL)
                    }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(project.selectedFileURL == nil)

                Divider()

                Button("Find in Project") {
                    project.showFindInProject()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(!project.hasProject)

                Divider()

                Button("Manage Tasks...") {
                    project.openTaskManager()
                }
                .disabled(!project.hasProject)

                Menu("Run Task") {
                    if project.tasks.isEmpty {
                        Button("No Tasks") {
                            project.openTaskManager()
                        }
                    } else {
                        ForEach(project.tasks) { task in
                            Button(task.name) {
                                project.runTask(task)
                            }
                        }
                    }
                }
                .disabled(!project.hasProject)

                Button("Run Selected Task") {
                    project.runSelectedTask()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!project.hasProject || project.taskRunState.isRunning)

                Button("Stop Task") {
                    project.stopTask()
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!project.taskRunState.isRunning)
            }

            CommandMenu("Text") {
                Menu("Syntax Highlighting") {
                    ForEach(SyntaxHighlightMode.allCases, id: \.self) { mode in
                        Button(mode.label) {
                            document.setActiveSyntaxMode(mode)
                        }
                    }
                }

                Divider()

                Button("Trim Trailing Whitespace") {
                    document.trimTrailingWhitespace()
                }

                Button("Sort Lines") {
                    document.sortLines()
                }

                Button("Remove Duplicate Lines") {
                    document.removeDuplicateLines()
                }

                Divider()

                Button("Uppercase") {
                    document.uppercaseText()
                }

                Button("Lowercase") {
                    document.lowercaseText()
                }

                Button("Insert Date and Time") {
                    document.insertCurrentDateTime()
                }

                Divider()

                Button("Use LF Line Endings") {
                    document.setActiveLineEnding(.lf)
                }

                Button("Use CRLF Line Endings") {
                    document.setActiveLineEnding(.crlf)
                }

                Button("Use CR Line Endings") {
                    document.setActiveLineEnding(.cr)
                }

                Divider()

                Button("Save as UTF-8") {
                    document.setActiveEncoding(.utf8)
                }

                Button("Save as UTF-16") {
                    document.setActiveEncoding(.utf16)
                }

                Button("Save as UTF-16 LE") {
                    document.setActiveEncoding(.utf16LittleEndian)
                }

                Button("Save as UTF-16 BE") {
                    document.setActiveEncoding(.utf16BigEndian)
                }

                Button("Save as ASCII") {
                    document.setActiveEncoding(.ascii)
                }

                Button("Save as Windows Latin 1") {
                    document.setActiveEncoding(.windowsLatin1)
                }

                Button("Save as ISO Latin 1") {
                    document.setActiveEncoding(.isoLatin1)
                }
            }

            CommandMenu("View") {
                Button(project.isSidebarVisible ? "Hide Project Sidebar" : "Show Project Sidebar") {
                    project.toggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])

                Divider()

                Toggle("Show Line Numbers", isOn: $preferences.showLineNumbers)
                Toggle("Word Wrap", isOn: $preferences.wordWrap)
                Toggle("Render Supported Previews", isOn: $preferences.renderPreview)
                    .keyboardShortcut("p", modifiers: [.command, .option])

                Divider()

                Button("Toggle Split View") {
                    document.toggleSplitView()
                }
                .keyboardShortcut("\\", modifiers: .command)
            }

            CommandMenu("Tools") {
                Button("Document Stats") {
                    document.showDocumentStats()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Button("Visualize JSON...") {
                    document.showJSONVisualizer()
                }
                .keyboardShortcut("j", modifiers: [.command, .option])
                .disabled(!document.activeDocumentCanVisualizeJSON)
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(preferences)
        }
    }

    private func openProjectPanel() {
        project.persistOpenTabs(document.tabs)
        project.openProjectPanel()
        document.openFiles(at: project.consumeRestoredOpenTabURLs())
    }

    private func openRecentProject(_ recentProject: Project) {
        project.persistOpenTabs(document.tabs)
        project.openProject(at: recentProject.rootURL)
        document.openFiles(at: project.consumeRestoredOpenTabURLs())
    }

    private func closeProject() {
        project.closeProject(openTabs: document.tabs)
    }
}
