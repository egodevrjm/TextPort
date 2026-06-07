# TextPort

TextPort is a small native macOS plain text editor that is growing into a lightweight IDE. Think Notepad, but Mac-native, project-aware, and less picky about text-file extensions.

It can:

- create and edit plain text
- open folders as projects
- browse project files in a native sidebar
- create, rename, and move project files or folders to Trash
- search across project text and code files
- manage and run simple project tasks with streamed output
- open PDFs by extracting their text into a normal unsaved text tab
- open Word `.docx` files by extracting their text into a normal unsaved text tab
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
- autosave unsaved and edited tabs to draft files
- print or export the current tab to PDF
- use lightweight syntax highlighting with automatic detection and manual mode selection
- use Open Quickly to jump to open tabs, recent files, and project files
- open text-like files even when the extension is unusual
- open files by dragging them onto the editor
- detect common encodings including UTF-8, UTF-16, ASCII, Windows Latin 1, and ISO Latin 1
- warn before replacing unsaved work
- save and save as UTF-8 text
- export the current text as `.txt`, `.md`, `.html`, `.css`, `.js`, `.json`, `.xml`, `.csv`, `.yaml`, `.toml`, `.ini`, `.env`, `.sh`, `.swift`, `.py`, `.sql`, `.tex`, `.rst`, `.log`, or any custom extension

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
