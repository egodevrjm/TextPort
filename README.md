# TextPort

TextPort is a small native macOS plain text editor that is growing into a lightweight IDE. Think Notepad, but Mac-native, project-aware, and less picky about text-file extensions.

The default experience is intentionally simple: open a file, type, save, export when needed. Project, rendering, sharing, GitHub, and runnable-code tools appear only when they are useful or enabled in Settings.

## Requirements

- macOS 14 or newer
- Swift 6 compatible toolchain for building from source

## Highlights

It can:

- create and edit plain text
- open folders as projects
- open `.zip` archives as projects by extracting them into TextPort's app-support folder
- browse project files in a native sidebar
- create, rename, and move project files or folders to Trash
- search across project text and code files
- manage and run simple project tasks with streamed output
- use a smart toolbar that adapts to the active file, including preview, JSON visualization, and runnable-code actions
- run supported code files including Swift, Python, JavaScript, shell, Ruby, and Go with streamed output
- run the current supported code file from the smart toolbar or command palette
- use a command palette for common app, text, project, and tool actions
- open an About/TextPort Guide covering editing, imports, projects, Save vs Export, the command palette, and running code
- create common files from lightweight templates
- keep a persistent Scratchpad for temporary notes and snippets
- format or minify supported structured documents
- compare two open tabs in a lightweight diff view
- inspect a document outline for Markdown, JSON, HTML, and common code symbols
- see Git status badges in project sidebars
- run one-off project commands from the output panel
- export open tabs as a zip bundle
- optionally enable sharing tools for the current tab, selected text, rendered output, open-tab bundles, and project source bundles
- optionally enable GitHub helpers for opening/copying repository links and file links from projects with GitHub remotes
- optionally publish the current tab as a secret GitHub Gist through the GitHub CLI
- open PDFs by extracting cleaned body text into a normal unsaved text tab
- open Word `.docx` files by extracting cleaned body text into a normal unsaved text tab
- open PowerPoint `.pptx` files by extracting slide text into a normal unsaved text tab
- open Excel `.xlsx` and `.xlsm` files by converting each sheet into an unsaved CSV tab
- work with multiple files in tabs
- rename a saved file by clicking the title in the macOS title bar
- set a suggested file name for unsaved tabs before saving
- use native macOS menu bar commands for file and tab actions
- reopen recent files and use Open Quickly to jump to open tabs or recent files
- find and replace text with the native macOS text find panel
- preserve a file's encoding and line endings when saving
- choose save encoding and line-ending style from the Text menu
- detect when an open file changes on disk and offer to reload it
- toggle line numbers and word wrap from the View menu or Preferences
- use practical text tools including trim whitespace, sort lines, remove duplicates, case conversion, and insert date/time
- set editor preferences for font size, line numbers, word wrap, default encoding, default line endings, session restore, and opening behavior
- restore tabs and unsaved drafts when the app launches
- open a second editor pane with Split View
- view document and selection stats
- visualize JSON as a sortable, clickable human-readable structure and export it as visual HTML
- distinguish Save/Save As for editable source files from Export for generated outputs
- save an editable source copy as `.txt`, `.md`, `.html`, `.css`, `.js`, `.json`, `.xml`, `.csv`, `.yaml`, `.toml`, `.ini`, `.env`, `.sh`, `.swift`, `.py`, `.sql`, `.tex`, `.rst`, `.log`, or any custom extension
- export generated outputs including PDF, rendered Markdown HTML, visual JSON HTML, and open-tab zip bundles
- autosave unsaved and edited tabs to draft files
- print or export the current tab to PDF
- render HTML, Markdown, JSON, CSV, TSV, and SVG tabs with a source/preview toggle
- use lightweight syntax highlighting with automatic detection and manual mode selection
- use Open Quickly to jump to open tabs, recent files, and project files
- open text-like files even when the extension is unusual
- open files by dragging them onto the editor
- detect common encodings including UTF-8, UTF-16, ASCII, Windows Latin 1, and ISO Latin 1
- warn before replacing unsaved work
- save and save as UTF-8 text

## Optional Features

TextPort includes several power tools that are designed to stay out of the way:

- Project/IDE features appear when a folder or zip project is opened.
- Sharing and GitHub helpers are disabled by default and can be enabled in Settings.
- Render previews are contextual to supported formats such as Markdown, HTML, JSON, CSV, TSV, and SVG.
- Run buttons appear for supported executable code files and project tasks.

## Security And Privacy

- TextPort works as a local macOS app and does not require an account.
- Sharing and GitHub helpers are optional.
- Project tasks and runnable code files execute local shell commands, so only run commands from projects you trust.
- Imported PDFs, Office files, spreadsheets, zip projects, rendered previews, and JSON visualizations should be treated as untrusted input until inspected.

## Build

```sh
swift build
```

## Run

```sh
./script/build_and_run.sh
```

## Create a Mac App Bundle

```sh
./Scripts/package-app.sh
```

That creates `TextPort.app` in this folder.

## Release Builds

See [RELEASE.md](RELEASE.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

TextPort is open source under the [MIT License](LICENSE).
