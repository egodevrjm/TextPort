import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        TabView {
            generalPane
                .tabItem {
                    Label("General", systemImage: "switch.2")
                }

            editorPane
                .tabItem {
                    Label("Editor", systemImage: "text.cursor")
                }

            filesPane
                .tabItem {
                    Label("Files", systemImage: "doc.text")
                }

            sharingPane
                .tabItem {
                    Label("Sharing", systemImage: "square.and.arrow.up")
                }

            advancedPane
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 520, height: 420)
    }

    private var generalPane: some View {
        PreferencesPane {
            Section("Simple Defaults") {
                Toggle("Restore Previous Session", isOn: $preferences.restoreSession)
                Toggle("Reuse Empty Tab When Opening Files", isOn: $preferences.reuseBlankTabWhenOpening)
                Toggle("Render Supported Previews", isOn: $preferences.renderPreview)

                Button("Reset to Simple Defaults") {
                    preferences.resetToSimpleDefaults()
                }
            }

            Section("Default Experience") {
                SettingsNote("TextPort starts as a plain text editor. Project, preview, sharing, and code-running tools appear only when enabled or useful for the current file.")
            }
        }
    }

    private var editorPane: some View {
        PreferencesPane {
            Section("Text") {
                Stepper(value: $preferences.fontSize, in: 10...28, step: 1) {
                    Text("Font Size: \(Int(preferences.fontSize))")
                }

                Toggle("Show Line Numbers", isOn: $preferences.showLineNumbers)
                Toggle("Word Wrap", isOn: $preferences.wordWrap)
            }
        }
    }

    private var filesPane: some View {
        PreferencesPane {
            Section("Save Defaults") {
                Picker("Encoding", selection: $preferences.defaultEncoding) {
                    ForEach(TextEncoding.allCases, id: \.self) { encoding in
                        Text(encoding.label).tag(encoding)
                    }
                }

                Picker("Line Endings", selection: $preferences.defaultLineEnding) {
                    ForEach(TextLineEnding.menuCases, id: \.self) { lineEnding in
                        Text(lineEnding.label).tag(lineEnding)
                    }
                }
            }

            Section("Imported Files") {
                SettingsNote("PDF, Word, PowerPoint, and workbook imports open as editable text or CSV copies. Original files are not modified.")
            }
        }
    }

    private var sharingPane: some View {
        PreferencesPane {
            Section("Sharing") {
                Toggle("Enable Sharing Tools", isOn: $preferences.enableSharingTools)
                SettingsNote("Sharing uses macOS share sheets and temporary local files.")
            }

            Section("GitHub") {
                Toggle("Enable GitHub Tools", isOn: $preferences.enableGitHubTools)
                    .disabled(!preferences.enableSharingTools)

                Toggle("Enable Publishing Actions", isOn: $preferences.enablePublishingActions)
                    .disabled(!preferences.enableSharingTools || !preferences.enableGitHubTools)

                SettingsNote("GitHub actions stay hidden until enabled. Publishing uses the GitHub CLI when it is installed and signed in.")
            }
        }
    }

    private var advancedPane: some View {
        PreferencesPane {
            Section("Syntax") {
                Text("\(preferences.customSyntaxDefinitions.count) custom syntax \(preferences.customSyntaxDefinitions.count == 1 ? "definition" : "definitions")")
                    .foregroundStyle(.secondary)

                SettingsNote("Manage custom syntaxes from the Text menu.")
            }

            Section("Project Tasks") {
                SettingsNote("Project tasks run local shell commands. Keep them for projects you trust.")
            }
        }
    }
}

private struct PreferencesPane<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

private struct SettingsNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
