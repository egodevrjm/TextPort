import SwiftUI

@main
struct TextPortApp: App {
    @StateObject private var document = TextDocumentStore()
    @StateObject private var preferences = AppPreferences.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(document)
                .environmentObject(preferences)
                .frame(minWidth: 760, minHeight: 520)
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
                Toggle("Show Line Numbers", isOn: $preferences.showLineNumbers)
                Toggle("Word Wrap", isOn: $preferences.wordWrap)

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
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(preferences)
        }
    }
}
