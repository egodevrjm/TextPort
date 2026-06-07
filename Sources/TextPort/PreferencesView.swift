import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        Form {
            Section("Editor") {
                Stepper(value: $preferences.fontSize, in: 10...28, step: 1) {
                    Text("Font Size: \(Int(preferences.fontSize))")
                }

                Toggle("Show Line Numbers", isOn: $preferences.showLineNumbers)
                Toggle("Word Wrap", isOn: $preferences.wordWrap)
                Toggle("Render HTML and Markdown", isOn: $preferences.renderPreview)
            }

            Section("Defaults") {
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

            Section("Startup") {
                Toggle("Restore Previous Session", isOn: $preferences.restoreSession)
                Toggle("Reuse Empty Tab When Opening Files", isOn: $preferences.reuseBlankTabWhenOpening)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}
