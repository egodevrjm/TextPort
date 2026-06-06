# TextPort

TextPort is a very small native macOS plain text editor. Think Notepad, but Mac-native and less picky about text-file extensions.

It can:

- create and edit plain text
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
swift run TextPort
```

## Create a Mac App Bundle

```sh
./Scripts/package-app.sh
```

That creates `TextPort.app` in this folder.
