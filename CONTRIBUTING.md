# Contributing to TextPort

Thanks for helping make TextPort better.

TextPort aims to stay simple by default: opening, editing, saving, and exporting text should always feel lightweight. IDE, sharing, rendering, and GitHub features should remain contextual or opt-in where possible.

## Development Setup

Requirements:

- macOS 14 or newer
- Swift 6 compatible toolchain

Build:

```sh
swift build
```

Run as an app bundle:

```sh
./script/build_and_run.sh
```

Package the app:

```sh
./Scripts/package-app.sh
```

## Before Opening a Pull Request

- Run `swift build`.
- Run `./script/build_and_run.sh --verify` when changing app launch, packaging, menus, file import, or window behavior.
- Keep changes focused and avoid mixing unrelated refactors with feature work.
- Prefer native macOS controls and menu commands where they make the app feel clearer.
- Keep optional or power-user features behind settings, menu commands, or file-type-aware controls.

## Design Principles

- Simple editor first, lightweight IDE second.
- Local file processing by default.
- No permanent delete for project files; move to Trash.
- Save editable source files; Export generated or rendered outputs.
- Make smart tools appear only when they are useful for the active file.
