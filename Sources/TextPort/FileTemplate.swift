import Foundation

struct FileTemplate: Identifiable {
    let id: String
    let name: String
    let fileName: String
    let syntaxMode: SyntaxHighlightMode
    let text: String

    static let all: [FileTemplate] = [
        FileTemplate(id: "markdown", name: "Markdown Note", fileName: "Note.md", syntaxMode: .markdown, text: "# Title\n\n"),
        FileTemplate(id: "readme", name: "README", fileName: "README.md", syntaxMode: .markdown, text: "# Project\n\n## Overview\n\n"),
        FileTemplate(id: "html", name: "HTML Page", fileName: "index.html", syntaxMode: .html, text: """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>Document</title>
        </head>
        <body>
          <main>
            <h1>Hello</h1>
          </main>
        </body>
        </html>
        """),
        FileTemplate(id: "json", name: "JSON Config", fileName: "config.json", syntaxMode: .json, text: "{\n  \"name\": \"TextPort\"\n}\n"),
        FileTemplate(id: "shell", name: "Shell Script", fileName: "script.sh", syntaxMode: .shell, text: "#!/bin/zsh\n\n"),
        FileTemplate(id: "swift", name: "Swift File", fileName: "main.swift", syntaxMode: .swift, text: "import Foundation\n\nprint(\"Hello\")\n"),
        FileTemplate(id: "python", name: "Python Script", fileName: "script.py", syntaxMode: .python, text: "print(\"Hello\")\n"),
        FileTemplate(id: "license", name: "License", fileName: "LICENSE.txt", syntaxMode: .plainText, text: "Copyright (c) \(Calendar.current.component(.year, from: Date()))\n\n")
    ]
}
